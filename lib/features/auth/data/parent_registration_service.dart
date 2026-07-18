import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class PendingApplication {
  final String id;
  final String email;
  final String? fullName;
  final String? password;
  final Map<String, String> formData;
  final DateTime submittedAt;
  final bool approved;

  PendingApplication({
    required this.id,
    required this.email,
    required this.submittedAt,
    this.fullName,
    this.password,
    this.formData = const {},
    this.approved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'password': password,
    'formData': formData,
    'submittedAt': submittedAt.toIso8601String(),
  };

  factory PendingApplication.fromJson(Map<String, dynamic> j) =>
      PendingApplication(
        id: j['id']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        fullName: j['fullName']?.toString(),
        password: j['password']?.toString(),
        formData: j['formData'] is Map
            ? Map<String, String>.fromEntries(
                (j['formData'] as Map).entries.map(
                  (entry) =>
                      MapEntry(entry.key.toString(), entry.value.toString()),
                ),
              )
            : const {},
        submittedAt:
            DateTime.tryParse(j['submittedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Result of polling the server for an application's current status.
class ApplicationStatus {
  /// One of 'pending', 'approved', 'rejected', 'not_found'.
  final String status;
  final String? rejectReason;
  const ApplicationStatus(this.status, {this.rejectReason});
}

class RegistrationResult {
  final Map<String, dynamic> data;
  final String password;
  RegistrationResult({required this.data, required this.password});
}

class ParentAttachment {
  const ParentAttachment({
    required this.field,
    required this.bytes,
    required this.filename,
  });

  final String field;
  final Uint8List bytes;
  final String filename;
}

class ParentRegistrationService {
  ParentRegistrationService({ApiClient? client})
    : _api = client ?? ApiClient(timeout: const Duration(seconds: 60));
  final ApiClient _api;

  static const Map<String, String> _fieldMap = {
    'Firstname_Lao': 'first_name_lao',
    'Firstname_Eng': 'first_name_eng',
    'Midlename_Lao': 'midle_name_lao',
    'Midlename_Eng': 'midle_name_eng',
    'Lastname_Lao': 'last_name_lao',
    'Lastname_Eng': 'last_name_eng',
    'Nickname': 'nickname',
    'Password': 'password',
    'DateofBirth': 'dob',
    'Gender': 'gender',
    'Educatio_Level': 'education_level',
    'Job': 'occupation',
    'Workplace': 'company_name',
    'Email': 'email',
    'Phone_No1': 'phone',
    'Phone_No2': 'mobile_phone',
    'IDCard_no': 'idCard_no',
    'Passport_no': 'passport_number',
    'FamillyBook_no': 'family_book_number',
    'Nationality': 'nationality',
    'Ethnicty': 'ethnicity',
    'Religion': 'religion',
    'Home_no': 'home_number',
    'Home_unit': 'home_unit',
    'Village': 'village',
    'District': 'district',
    'Province': 'province',
  };

  static const _requiredStringFields = [
    'first_name_lao',
    'first_name_eng',
    'midle_name_lao',
    'midle_name_eng',
    'last_name_lao',
    'last_name_eng',
    'gender',
  ];

  Future<RegistrationResult> register(
    Map<String, String> data, {
    List<ParentAttachment> attachments = const [],
  }) async {
    final body = <String, dynamic>{};
    for (final e in data.entries) {
      if (e.key == 'ConfirmPassword') continue;
      final v = e.value.trim();
      if (v.isEmpty) continue;
      final key = _fieldMap[e.key] ?? e.key;
      body[key] = v;
    }
    for (final f in _requiredStringFields) {
      body[f] ??= '';
    }
    final password = (data['Password'] ?? '').trim();
    final email = body['email']?.toString().trim() ?? '';
    body['username'] = email;
    body['password'] = password;
    body['is_active'] = false;

    final existing = await _findByEmail(email);
    if (existing != null) {
      throw ApiException(
        'This email is already registered. Please sign in instead.',
        statusCode: 409,
        body: existing,
      );
    }

    try {
      final res = attachments.isEmpty
          ? await _api.post('/parents', body: body)
          : await _api.multipartPost(
              '/parents',
              fields: body.map((key, value) => MapEntry(key, value.toString())),
              files: attachments
                  .map(
                    (file) => MultipartFilePart(
                      field: file.field,
                      bytes: file.bytes,
                      filename: file.filename,
                    ),
                  )
                  .toList(),
            );
      return RegistrationResult(data: _asMap(res), password: password);
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! >= 500) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final created = await _findByEmail(email);
        if (created != null) {
          return RegistrationResult(data: created, password: password);
        }
      }
      rethrow;
    }
  }

  Future<RegistrationResult> resubmit(
    String id,
    Map<String, String> data, {
    List<ParentAttachment> attachments = const [],
  }) async {
    final fields = <String, String>{
      for (final entry in data.entries)
        if (entry.key != 'ConfirmPassword' && entry.value.trim().isNotEmpty)
          (_fieldMap[entry.key] ?? entry.key): entry.value.trim(),
      'username': (data['Email'] ?? '').trim(),
      'is_active': 'false',
      'approval_status': 'pending',
      'reject_reason': '',
    };
    final files = attachments
        .map(
          (file) => MultipartFilePart(
            field: file.field,
            bytes: file.bytes,
            filename: file.filename,
          ),
        )
        .toList();
    final response = attachments.isEmpty
        ? await _api.put('/parents/$id', body: fields)
        : await _api.multipartPut('/parents/$id', fields: fields, files: files);
    return RegistrationResult(data: _asMap(response), password: '');
  }

  Future<Map<String, dynamic>?> _findByEmail(String? email) async {
    if (email == null || email.isEmpty) return null;
    try {
      final res = await _api.get('/parents');
      final list = res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] as List : null);
      if (list == null) return null;
      for (final item in list.reversed) {
        if (item is Map &&
            (item['email']?.toString().toLowerCase() == email.toLowerCase())) {
          return Map<String, dynamic>.from(item);
        }
      }
    } catch (_) {}
    return null;
  }

  static const _kStorageKey = 'pending_parent_application';
  static const _kReusableDetailsStorageKey = 'parent_reusable_details_v1';

  static const _reusableDetailFields = <String>{
    'Firstname_Lao',
    'Firstname_Eng',
    'Midlename_Lao',
    'Midlename_Eng',
    'Lastname_Lao',
    'Lastname_Eng',
    'Nickname',
    'DateofBirth',
    'Gender',
    'Educatio_Level',
    'Job',
    'Workplace',
    'Email',
    'Phone_No1',
    'Phone_No2',
    'Nationality',
    'Ethnicty',
    'Religion',
    'Home_no',
    'Home_unit',
    'Village',
    'District',
    'Province',
  };

  Future<void> saveReusableDetails(Map<String, String> formData) async {
    final details = <String, String>{
      for (final entry in formData.entries)
        if (_reusableDetailFields.contains(entry.key) &&
            entry.value.trim().isNotEmpty)
          entry.key: entry.value.trim(),
    };
    if (details.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReusableDetailsStorageKey, jsonEncode(details));
  }

  Future<Map<String, String>> loadReusableDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kReusableDetailsStorageKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return Map<String, String>.fromEntries(
        decoded.entries
            .where(
              (entry) => _reusableDetailFields.contains(entry.key.toString()),
            )
            .map(
              (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
            ),
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> savePending({
    required String id,
    required String email,
    String? fullName,
    String? password,
    Map<String, String> formData = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final app = PendingApplication(
      id: id,
      email: email,
      fullName: fullName,
      password: password,
      formData: Map<String, String>.from(formData),
      submittedAt: DateTime.now(),
    );
    await prefs.setString(_kStorageKey, jsonEncode(app.toJson()));
  }

  Future<PendingApplication?> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PendingApplication.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
  }

  /// Approved when backend `isActive == true` (admin clicked Approve).
  /// Rejected when `approval_status == 'rejected'`; carries the admin's reason.
  Future<ApplicationStatus> checkStatus(String id) async {
    try {
      final res = await _api.get('/parents');
      final list = res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] as List : null);
      if (list == null) return const ApplicationStatus('not_found');
      for (final item in list) {
        if (item is Map && item['id']?.toString() == id) {
          final active = item['isActive'] == true || item['is_active'] == true;
          final approval = (item['approval_status'] ?? item['approvalStatus'])
              ?.toString()
              .toLowerCase();
          if (active || approval == 'approved') {
            return const ApplicationStatus('approved');
          }
          if (approval == 'rejected') {
            final reason =
                (item['reject_reason'] ??
                        item['rejectReason'] ??
                        item['rejection_reason'] ??
                        item['rejectionReason'])
                    ?.toString();
            return ApplicationStatus(
              'rejected',
              rejectReason: (reason == null || reason.trim().isEmpty)
                  ? null
                  : reason.trim(),
            );
          }
          return const ApplicationStatus('pending');
        }
      }
      return const ApplicationStatus('not_found');
    } catch (_) {
      return const ApplicationStatus('pending');
    }
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'data': res};
  }
}

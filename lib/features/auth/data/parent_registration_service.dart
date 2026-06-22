import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class PendingApplication {
  final String id;
  final String email;
  final String? fullName;
  final String? password;
  final DateTime submittedAt;
  final bool approved;

  PendingApplication({
    required this.id,
    required this.email,
    required this.submittedAt,
    this.fullName,
    this.password,
    this.approved = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'password': password,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory PendingApplication.fromJson(Map<String, dynamic> j) => PendingApplication(
        id: j['id']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        fullName: j['fullName']?.toString(),
        password: j['password']?.toString(),
        submittedAt: DateTime.tryParse(j['submittedAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class RegistrationResult {
  final Map<String, dynamic> data;
  final String password;
  RegistrationResult({required this.data, required this.password});
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

  Future<RegistrationResult> register(Map<String, String> data) async {
    final body = <String, dynamic>{};
    for (final e in data.entries) {
      final v = e.value.trim();
      if (v.isEmpty) continue;
      final key = _fieldMap[e.key] ?? e.key;
      body[key] = v;
    }
    for (final f in _requiredStringFields) {
      body[f] ??= '';
    }
    final password = _generatePassword();
    body['username'] = _deriveUsername(data['Email'] ?? '');
    body['password'] = password;
    body['is_active'] = false;

    final email = body['email']?.toString();
    final existing = await _findByEmail(email);
    if (existing != null) {
      throw ApiException(
        'This email is already registered. Please sign in instead.',
        statusCode: 409,
        body: existing,
      );
    }

    try {
      final res = await _api.post('/parents', body: body);
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

  Future<Map<String, dynamic>?> _findByEmail(String? email) async {
    if (email == null || email.isEmpty) return null;
    try {
      final res = await _api.get('/parents');
      final list = res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] as List : null);
      if (list == null) return null;
      for (final item in list.reversed) {
        if (item is Map && (item['email']?.toString().toLowerCase() == email.toLowerCase())) {
          return Map<String, dynamic>.from(item);
        }
      }
    } catch (_) {}
    return null;
  }

  static const _kStorageKey = 'pending_parent_application';

  Future<void> savePending({
    required String id,
    required String email,
    String? fullName,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final app = PendingApplication(
      id: id,
      email: email,
      fullName: fullName,
      password: password,
      submittedAt: DateTime.now(),
    );
    await prefs.setString(_kStorageKey, jsonEncode(app.toJson()));
  }

  Future<PendingApplication?> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PendingApplication.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
  }

  /// Returns: 'pending' | 'approved' | 'not_found'
  /// Approved when backend `isActive == true` (admin clicked Approve).
  Future<String> checkStatus(String id) async {
    try {
      final res = await _api.get('/parents');
      final list = res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] as List : null);
      if (list == null) return 'not_found';
      for (final item in list) {
        if (item is Map && item['id']?.toString() == id) {
          final active = item['isActive'] == true || item['is_active'] == true;
          return active ? 'approved' : 'pending';
        }
      }
      return 'not_found';
    } catch (_) {
      return 'pending';
    }
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'data': res};
  }

  String _deriveUsername(String email) {
    final local = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final suffix = Random().nextInt(9000) + 1000;
    final base = local.isEmpty ? 'parent' : local;
    return '${base}_$suffix';
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

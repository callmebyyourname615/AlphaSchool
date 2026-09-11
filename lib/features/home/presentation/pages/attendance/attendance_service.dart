import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'attendance_model.dart';

class AttendanceService {
  AttendanceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  static const _cachePrefix = 'attendance_history_v1';

  /// Fetches [student]'s attendance for today.
  ///
  /// `GET /attendances` defaults to the current server date when no
  /// `start_date`/`end_date` range is supplied (and auto-marks absentees for
  /// that date), returning every student's record for the day with the
  /// `student` relation populated -- so this matches client-side on the
  /// top-level `student_id` first. That column is the student's internal UUID;
  /// [StudentCardItem.studentId] is only the human-readable student code, so it
  /// is used as a fallback only when the card has no internal id.
  ///
  /// Returns `null` when the student has no attendance record for today or
  /// has no id/code to match on.
  Future<TodayAttendance?> fetchTodayAttendance(StudentCardItem student) async {
    final internalId = student.id?.trim() ?? '';
    final code = student.studentId.trim();
    if (internalId.isEmpty && code.isEmpty) return null;

    final today = _date(DateTime.now());
    final classId = student.classId?.trim() ?? '';
    final response = await _apiClient.get(
      '/attendances',
      queryParameters: {
        'start_date': today,
        'end_date': today,
        if (classId.isNotEmpty) 'class_id': classId,
      },
    );

    for (final record in _extractRecords(response)) {
      if (_matchesStudent(record, internalId: internalId, code: code)) {
        return TodayAttendance.fromJson(record);
      }
    }

    if (classId.isEmpty) return null;

    final fallbackResponse = await _apiClient.get(
      '/attendances',
      queryParameters: {
        'start_date': today,
        'end_date': today,
      },
    );

    for (final record in _extractRecords(fallbackResponse)) {
      if (_matchesStudent(record, internalId: internalId, code: code)) {
        return TodayAttendance.fromJson(record);
      }
    }

    return null;
  }

  Future<List<AttendanceRecord>> fetchHistory(
    StudentCardItem student, {
    DateTime? month,
  }) async {
    final internalId = student.id?.trim() ?? '';
    final code = student.studentId.trim();
    if (internalId.isEmpty && code.isEmpty) return [];

    final now = DateTime.now();
    final start = month == null
        ? DateTime(now.year - 1, now.month, 1)
        : DateTime(month.year, month.month, 1);
    final end = month == null
        ? DateTime(now.year, now.month + 1, 0)
        : DateTime(month.year, month.month + 1, 0);

    final response = await _apiClient.get(
      '/attendances',
      queryParameters: {
        'start_date': _date(start),
        'end_date': _date(end),
        if ((student.classId ?? '').isNotEmpty) 'class_id': student.classId,
      },
    );

    final records =
        _extractRecords(response)
            .where((record) {
              if (record['student_id']?.toString() == internalId) return true;
              final nested = record['student'];
              return nested is Map &&
                  nested['student_id']?.toString().trim() == code;
            })
            .map(AttendanceRecord.fromJson)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    await cacheHistory(student, records, month: month);
    return records;
  }

  Future<List<AttendanceRecord>?> readCachedHistory(
    StudentCardItem student, {
    DateTime? month,
  }) async {
    final key = _cacheKey(student, month: month);
    if (key == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final records =
          decoded
              .whereType<Map>()
              .map(
                (record) => AttendanceRecord.fromJson(
                  Map<String, dynamic>.from(record),
                ),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> cacheHistory(
    StudentCardItem student,
    List<AttendanceRecord> records, {
    DateTime? month,
  }) async {
    final key = _cacheKey(student, month: month);
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String? _cacheKey(StudentCardItem student, {DateTime? month}) {
    final internalId = student.id?.trim() ?? '';
    final code = student.studentId.trim();
    final studentKey = internalId.isNotEmpty ? internalId : code;
    if (studentKey.isEmpty) return null;

    final classId = student.classId?.trim() ?? '';
    final period = month == null
        ? 'rolling'
        : '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return '$_cachePrefix:$studentKey:$classId:$period';
  }

  /// Same defensive shape-handling as other feature services: the backend
  /// may answer with a bare array, `{data: [...]}`, `{results: [...]}`, or
  /// `{attendances: [...]}`.
  List<Map<String, dynamic>> _extractRecords(dynamic response) {
    List<dynamic> rawList = const [];

    if (response is List<dynamic>) {
      rawList = response;
    } else if (response is Map<String, dynamic>) {
      final byResource = response['attendances'];
      final data = response['data'];
      final results = response['results'];
      if (byResource is List<dynamic>) {
        rawList = byResource;
      } else if (data is List<dynamic>) {
        rawList = data;
      } else if (results is List<dynamic>) {
        rawList = results;
      }
    }

    return rawList
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  bool _matchesStudent(
    Map<String, dynamic> record, {
    required String internalId,
    required String code,
  }) {
    final recordStudentId = record['student_id']?.toString().trim() ?? '';
    if (internalId.isNotEmpty && recordStudentId == internalId) return true;
    if (code.isNotEmpty && recordStudentId == code) return true;

    final studentJson = record['student'];
    if (studentJson is! Map) return false;

    final nestedId = studentJson['id']?.toString().trim() ?? '';
    final nestedCode = studentJson['student_id']?.toString().trim() ?? '';

    return (internalId.isNotEmpty && nestedId == internalId) ||
        (code.isNotEmpty && nestedCode == code);
  }
}

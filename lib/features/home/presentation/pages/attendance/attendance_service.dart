import '../../../../../core/network/api_client.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'attendance_model.dart';

class AttendanceService {
  AttendanceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Fetches [student]'s attendance for today.
  ///
  /// `GET /attendances` defaults to the current server date when no
  /// `start_date`/`end_date` range is supplied (and auto-marks absentees for
  /// that date), returning every student's record for the day with the
  /// `student` relation populated -- so this matches client-side on the
  /// nested `student.student_id`. That's the same human-readable code carried
  /// by [StudentCardItem.studentId]; the attendance record's own top-level
  /// `student_id` column is a foreign key holding the student's *internal
  /// UUID*, not that code, so it can't be compared directly.
  ///
  /// Returns `null` when the student has no attendance record for today or
  /// has no `studentId` to match on.
  Future<TodayAttendance?> fetchTodayAttendance(StudentCardItem student) async {
    final code = student.studentId.trim();
    if (code.isEmpty) return null;

    final response = await _apiClient.get('/attendances');

    for (final record in _extractRecords(response)) {
      final studentJson = record['student'];
      if (studentJson is! Map<String, dynamic>) continue;
      if (studentJson['student_id']?.toString().trim() != code) continue;

      return TodayAttendance.fromJson(record);
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
              return nested is Map<String, dynamic> &&
                  nested['student_id']?.toString().trim() == code;
            })
            .map(AttendanceRecord.fromJson)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

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

    return rawList.whereType<Map<String, dynamic>>().toList();
  }
}

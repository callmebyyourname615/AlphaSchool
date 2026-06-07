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

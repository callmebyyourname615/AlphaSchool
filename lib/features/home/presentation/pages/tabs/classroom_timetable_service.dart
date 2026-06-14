import '../../../../../core/network/api_client.dart';
import 'classroom_timetable_model.dart';

class ClassroomTimetableService {
  ClassroomTimetableService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ClassroomTimetableItem>> fetchByClass(String classId) async {
    final cleanId = classId.trim();
    if (cleanId.isEmpty) return [];

    final response = await _apiClient.get('/timetables/class/$cleanId');
    final rows = _extractRows(response);
    final items =
        rows
            .where(
              (row) => row['isDeleted'] != true && row['isActive'] != false,
            )
            .map(ClassroomTimetableItem.fromJson)
            .toList()
          ..sort((a, b) {
            final day = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (day != 0) return day;
            return (a.startHour * 60 + a.startMinute).compareTo(
              b.startHour * 60 + b.startMinute,
            );
          });
    return items;
  }

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    if (response is List) {
      return response.whereType<Map<String, dynamic>>().toList();
    }
    if (response is Map<String, dynamic>) {
      for (final key in ['data', 'results', 'timetables']) {
        final value = response[key];
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return [];
  }
}

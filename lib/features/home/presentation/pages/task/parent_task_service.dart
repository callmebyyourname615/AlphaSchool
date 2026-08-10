import 'dart:developer' as developer;

import '../../../../../core/network/api_client.dart';
import 'parent_task_list_page.dart';

class TaskService {
  TaskService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Fetches tasks relevant to one student: tasks assigned to them
  /// individually, or assigned to their class. [classId] is required for the
  /// class-assignment match — without it only individual assignments match.
  Future<List<ParentTaskItem>> fetchForStudent({
    required String? studentId,
    required String? classId,
  }) async {
    final sid = (studentId ?? '').trim();
    final cid = (classId ?? '').trim();

    if (sid.isEmpty) {
      developer.log('no studentId — returning empty', name: 'tasks');
      return [];
    }

    final results = await Future.wait([
      _apiClient.get('/tasks'),
      _safeGet('/admins'),
    ]);

    final rows = _extractRows(results[0]);
    final adminRows = _extractRows(results[1]);

    final teacherById = <String, String>{};
    for (final admin in adminRows) {
      final id = admin['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      final first = (admin['first_name'] ?? '').toString().trim();
      final last = (admin['last_name'] ?? '').toString().trim();
      final name = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (name.isNotEmpty) teacherById[id] = name;
    }

    final matched = rows.where((row) => _matchesStudent(row, sid, cid)).toList();

    developer.log(
      'fetchForStudent sid=$sid cid=$cid -> matched ${matched.length}/${rows.length} tasks',
      name: 'tasks',
    );
    if (matched.length < rows.length) {
      for (final row in rows) {
        if (matched.contains(row)) continue;
        developer.log(
          'unmatched task id=${row['id']} name=${row['name']} '
          'mode=${row['assignment_mode']} '
          'assignment_student_ids=${row['assignment_student_ids']} '
          '(${row['assignment_student_ids'].runtimeType}) '
          'row.student=${row['student']} '
          'class_id=${row['class_id']} assignment_class_ids=${row['assignment_class_ids']}',
          name: 'tasks',
        );
      }
    }

    final items = matched.map((row) {
      final addedById = row['added_by_id']?.toString();
      final teacherName = addedById != null ? teacherById[addedById] : null;
      return ParentTaskItem.fromApi(row, teacherName: teacherName);
    }).toList();

    items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return items;
  }

  // Deliberately mode-agnostic: check every assignment field a task could
  // carry rather than gating on `assignment_mode == 'individual'` first.
  // A task assigned to several students only needs studentId to appear in
  // assignment_student_ids to match — it shouldn't matter what string the
  // backend happens to have stamped into assignment_mode for that task.
  bool _matchesStudent(Map<String, dynamic> row, String studentId, String classId) {
    final student = row['student'];
    final rowStudentId = student is Map ? student['id']?.toString() : null;
    final studentIds = _stringList(row['assignment_student_ids']);
    if (rowStudentId == studentId || studentIds.contains(studentId)) return true;

    if (classId.isEmpty) return false;
    final rowClassId = row['class_id']?.toString();
    final classIds = _stringList(row['assignment_class_ids']);
    return rowClassId == classId || classIds.contains(classId);
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _apiClient.get(path);
    } catch (error) {
      developer.log('GET $path failed: $error', name: 'tasks');
      return const <dynamic>[];
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    List<dynamic> raw = const [];
    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'results', 'tasks']) {
        final value = response[key];
        if (value is List) {
          raw = value;
          break;
        }
      }
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

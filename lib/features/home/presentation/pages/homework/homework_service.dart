import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_config.dart';
import 'homework_models.dart';

class HomeworkService {
  HomeworkService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> submitHomework({
    required HomeworkItem homework,
    required String studentId,
    String? classId,
    String? branchId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (homework.deadline.isBefore(DateTime.now())) {
      throw StateError('The due date has passed.');
    }

    await _apiClient.multipartPost(
      '/homework-results',
      fields: {
        'homeworkId': homework.id,
        'studentId': studentId,
        if ((classId ?? '').isNotEmpty) 'classId': classId!,
        if ((branchId ?? '').isNotEmpty) 'branchId': branchId!,
        'score': '0',
      },
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  /// Static uploads (e.g. `uploads/homeworks/x.jpg`) live at the API host
  /// root, not under `/api/v2`. Returns null for empty/null input.
  static String? resolveImageUrl(String? path) {
    if (path == null) return null;
    final clean = path.trim();
    if (clean.isEmpty) return null;
    final base = Uri.parse(ApiConfig.baseUrl);
    final relative = clean.startsWith('/') ? clean.substring(1) : clean;
    return base.replace(path: '/$relative').toString();
  }

  /// Fetches homework assigned to the student's class. [branchId] is logged
  /// for diagnostics but not used as a hard filter — the class is the
  /// scoping signal (the same classId belongs to one physical class).
  Future<List<HomeworkItem>> fetchForStudent({
    required String? studentId,
    required String? branchId,
    required String? classId,
  }) async {
    final c = (classId ?? '').trim();
    developer.log(
      'fetch start: branchId=$branchId classId=$classId',
      name: 'homework',
    );
    if (c.isEmpty) {
      developer.log('no classId — returning empty', name: 'homework');
      return [];
    }

    final results = await Future.wait([
      _apiClient.get('/teacher-homework'),
      _safeGet('/admins'),
      if ((studentId ?? '').trim().isNotEmpty)
        _safeGet('/homework-results/student/${studentId!.trim()}')
      else
        Future<dynamic>.value(const <dynamic>[]),
    ]);

    final rows = _extractRows(results[0]);
    final adminRows = _extractRows(results[1]);
    final resultRows = _extractRows(results[2]);
    final resultByHomeworkId = <String, Map<String, dynamic>>{};
    for (final row in resultRows.where((row) => row['isDeleted'] != true)) {
      final homeworkId = row['homeworkId']?.toString();
      if (homeworkId != null && homeworkId.isNotEmpty) {
        resultByHomeworkId[homeworkId] = row;
      }
    }
    developer.log(
      'rows=${rows.length} admins=${adminRows.length}',
      name: 'homework',
    );

    final teacherById = <String, String>{};
    for (final a in adminRows) {
      final id = a['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      final first = (a['first_name'] ?? a['firstName'] ?? '').toString().trim();
      final last = (a['last_name'] ?? a['lastName'] ?? '').toString().trim();
      final name = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (name.isNotEmpty) teacherById[id] = name;
    }

    final matched = rows
        .where((row) => row['classId']?.toString().trim() == c)
        .map(HomeworkItem.fromJson)
        .map((hw) => hw.copyWithTeacher(teacherById[hw.teacherId]))
        .map((hw) {
          final result = resultByHomeworkId[hw.id];
          if (result == null) return hw;
          final rawScore = result['score'];
          final score = rawScore is num
              ? rawScore.toDouble()
              : double.tryParse(rawScore?.toString() ?? '');
          return hw.copyWithResult(
            score: score,
            graded: result['isGraded'] == true,
            teacherRemark: result['remark']?.toString(),
          );
        })
        .toList();
    developer.log(
      'matched ${matched.length} rows for classId=$c',
      name: 'homework',
    );

    return matched;
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _apiClient.get(path);
    } catch (e) {
      developer.log('GET $path failed: $e', name: 'homework');
      return const <dynamic>[];
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    List<dynamic> raw = const [];
    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'results', 'homeworks']) {
        final v = response[key];
        if (v is List) {
          raw = v;
          break;
        }
      }
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

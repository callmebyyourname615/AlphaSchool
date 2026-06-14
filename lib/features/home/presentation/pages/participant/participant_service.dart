import 'dart:developer' as developer;

import '../../../../../core/network/api_client.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'participant_model.dart';

class ParticipantService {
  ParticipantService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ParticipantSummary> fetchSummary(StudentCardItem student) async {
    developer.log(
      'fetchSummary start: code=${student.studentId} cachedId=${student.id}',
      name: 'participant',
    );

    final studentUuid = await _resolveStudentUuid(student);
    developer.log('resolved uuid=$studentUuid', name: 'participant');

    final List<dynamic> results;
    try {
      results = await Future.wait([
        _fetchActivities(),
        _apiClient.get('/participation-scores'),
      ]);
    } catch (e, st) {
      developer.log(
        'fetch failed',
        name: 'participant',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    final weights = results[0] as List<ActivityWeight>;
    final rawRows = _extractList(results[1], 'participationScores');
    developer.log(
      'fetched weights=${weights.length} rows=${rawRows.length}',
      name: 'participant',
    );

    final weightById = {for (final w in weights) w.id: w};
    final byDate = <DateTime, List<DayRow>>{};

    for (final row in rawRows) {
      final date = _parseDate(
        row['date'] ?? row['scoredAt'] ?? row['created_at'],
      );

      final entries = row['scores'];
      if (entries is! List) continue;

      for (final entry in entries.whereType<Map<String, dynamic>>()) {
        if (!_matchesStudent(entry, studentUuid, student.studentId)) continue;

        final activityId = (entry['participationId'] ?? '').toString();
        final weight = weightById[activityId];

        final name =
            (entry['participationName'] ?? weight?.name ?? 'Untitled')
                .toString();
        final score = _toDouble(entry['score']);
        final max = weight?.weight ?? 0;

        byDate.putIfAbsent(date, () => []).add(
          DayRow(activityName: name, score: score, max: max),
        );
      }
    }

    final days = byDate.entries
        .map((e) => DayGroup(date: e.key, rows: e.value))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    developer.log(
      'built ${days.length} day groups with ${days.fold(0, (s, d) => s + d.rows.length)} rows',
      name: 'participant',
    );

    return ParticipantSummary(weights: weights, days: days);
  }

  Future<List<ActivityWeight>> _fetchActivities() async {
    final response = await _apiClient.get('/participation-list');
    return _extractList(response, 'participationList')
        .map(ActivityWeight.fromJson)
        .toList();
  }

  /// `StudentCardItem.studentId` holds the human-readable code. The internal
  /// UUID (which `participation-scores.scores[].studentId` references) is on
  /// `StudentCardItem.id` when the card came from `StudentService`; otherwise
  /// we look it up via `GET /students` and match the code.
  Future<String?> _resolveStudentUuid(StudentCardItem student) async {
    final cached = student.id?.trim();
    if (cached != null && cached.isNotEmpty) return cached;

    final code = student.studentId.trim();
    if (code.isEmpty) return null;

    try {
      final response = await _apiClient.get('/students');
      final rows = _extractList(response, 'students');
      for (final row in rows) {
        if (row['student_id']?.toString().trim() == code) {
          final id = row['id']?.toString().trim();
          if (id != null && id.isNotEmpty) return id;
        }
      }
    } catch (_) {
      // Fall through — caller will still try matching by code.
    }
    return null;
  }

  bool _matchesStudent(
    Map<String, dynamic> entry,
    String? uuid,
    String code,
  ) {
    final entryStudentId = entry['studentId']?.toString().trim();
    if (entryStudentId == null || entryStudentId.isEmpty) return false;

    if (uuid != null && entryStudentId == uuid) return true;
    // Defensive: backend might evolve to embed the human code.
    return code.isNotEmpty && entryStudentId == code;
  }

  DateTime _parseDate(dynamic raw) {
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _extractList(dynamic response, String resourceKey) {
    List<dynamic> raw = const [];
    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      for (final key in [resourceKey, 'data', 'results', 'items']) {
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

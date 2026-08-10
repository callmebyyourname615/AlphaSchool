import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../../../../core/network/api_client.dart';
import 'parent_task_list_page.dart';

class TaskSubmissionSlot {
  const TaskSubmissionSlot({
    required this.scheduleIndex,
    required this.dueAt,
    required this.status,
    this.submittedAt,
    this.parentConfirmedAt,
    this.reviewedAt,
    this.progressPct,
    this.score,
    this.maxScore,
    this.fileIds = const [],
  });

  final int scheduleIndex;
  final DateTime dueAt;
  final String status;
  final DateTime? submittedAt;
  final DateTime? parentConfirmedAt;
  final DateTime? reviewedAt;
  final int? progressPct;
  final int? score;
  final int? maxScore;
  final List<String> fileIds;

  bool get isSubmitted =>
      const {'submitted', 'late', 'reviewed'}.contains(status);

  factory TaskSubmissionSlot.fromApi(Map<String, dynamic> json) {
    final rawFiles = json['file_ids'];
    return TaskSubmissionSlot(
      scheduleIndex:
          (json['schedule_index'] as num?)?.toInt() ??
          int.tryParse(json['schedule_index']?.toString() ?? '') ??
          0,
      dueAt:
          DateTime.tryParse(json['due_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: (json['status'] ?? 'pending').toString(),
      submittedAt: DateTime.tryParse(
        json['submitted_at']?.toString() ?? '',
      )?.toLocal(),
      parentConfirmedAt: DateTime.tryParse(
        json['parent_confirmed_at']?.toString() ?? '',
      )?.toLocal(),
      reviewedAt: DateTime.tryParse(
        json['reviewed_at']?.toString() ?? '',
      )?.toLocal(),
      progressPct: _toInt(json['progress_pct']),
      score: _toInt(json['score']),
      maxScore: _toInt(json['max_score']),
      fileIds: rawFiles is List
          ? rawFiles.map((file) => file.toString()).toList()
          : const [],
    );
  }

  static int? _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

class TaskSubmissionService {
  TaskSubmissionService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The backend upserts on (task_id, student_id), so this creates the
  /// submission row on first upload and reuses it on every later one.
  ///
  /// Deliberately omits `progress_pct` — only the teacher sets that (via the
  /// review slider in the web portal). Uploading a file just marks the
  /// submission as in progress. The API records a reviewable attempt only
  /// after a file upload succeeds.
  Future<String> ensureSubmission({
    required String taskId,
    required String studentId,
  }) async {
    final response = await _apiClient.post(
      '/task-submissions',
      body: {
        'task_id': taskId,
        'student_id': studentId,
        'status': 'in_progress',
      },
    );
    final id = (response is Map ? response['id'] : null)?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('Submission was not created.');
    }
    return id;
  }

  Future<String> uploadFile({
    required String submissionId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final response = await _apiClient.multipartPost(
      '/files/upload',
      fields: {'module': 'task_submission', 'ownerId': submissionId},
      fileBytes: fileBytes,
      fileName: fileName,
    );
    final fileId = (response is Map ? response['id'] : null)?.toString();
    if (fileId == null || fileId.isEmpty) {
      throw StateError('Uploaded file could not be identified.');
    }
    return fileId;
  }

  /// Finds this student's submission for the task, if one already exists.
  Future<Map<String, dynamic>?> fetchSubmission({
    required String taskId,
    required String studentId,
  }) async {
    final response = await _safeGet('/task-submissions', {'task_id': taskId});
    final rows = _extractRows(response);
    for (final row in rows) {
      if (row['student_id']?.toString() == studentId) return row;
    }
    return null;
  }

  Future<List<TaskFileRef>> fetchSubmissionFiles(String submissionId) async {
    final response = await _safeGet(
      '/files/by/task_submission/$submissionId',
      null,
    );
    final rows = _extractRows(response);
    return rows
        .where((f) => f['is_deleted'] != true)
        .map(TaskFileRef.fromApi)
        .toList();
  }

  /// Returns every scheduled checkpoint for this child. Reading the endpoint
  /// also promotes overdue pending slots to `missed`, so parents and teachers
  /// always see the same current status.
  Future<List<TaskSubmissionSlot>> fetchSlots({
    required String taskId,
    required String studentId,
  }) async {
    final response = await _safeGet('/task-submissions/slots/tracking', {
      'task_id': taskId,
      'student_id': studentId,
    });
    return _extractRows(response).map(TaskSubmissionSlot.fromApi).toList();
  }

  /// Creates any missing schedule rows for a child. This is idempotent, so it
  /// is safe to call each time a task is opened on a new device.
  Future<List<TaskSubmissionSlot>> syncSlots({
    required String taskId,
    required String studentId,
  }) async {
    final response = await _apiClient.post(
      '/task-submissions/slots/sync',
      body: {
        'task_id': taskId,
        'student_ids': [studentId],
      },
    );
    // The sync endpoint returns every slot for the task so the portal can
    // build its full matrix. A parent screen must only ever show the selected
    // child's rows, otherwise three children with round #1 look like three
    // duplicate checkpoints.
    return _extractRows(response)
        .where((row) => row['student_id']?.toString() == studentId)
        .map(TaskSubmissionSlot.fromApi)
        .toList();
  }

  /// Records this upload against one particular scheduled checkpoint instead
  /// of only against the task as a whole.
  Future<TaskSubmissionSlot> submitSlot({
    required String taskId,
    required String studentId,
    required int scheduleIndex,
    required List<String> fileIds,
    String? submittedById,
  }) async {
    final response = await _apiClient.post(
      '/task-submissions/slots/submit',
      body: {
        'task_id': taskId,
        'student_id': studentId,
        'schedule_index': scheduleIndex,
        'file_ids': fileIds,
        if (submittedById != null && submittedById.isNotEmpty)
          'submitted_by_id': submittedById,
        'submitted_by_type': 'parent',
        if (submittedById != null && submittedById.isNotEmpty)
          'parent_confirmed_by_id': submittedById,
      },
    );
    if (response is! Map<String, dynamic>) {
      throw StateError('Submission checkpoint could not be saved.');
    }
    return TaskSubmissionSlot.fromApi(response);
  }

  Future<dynamic> _safeGet(String path, Map<String, dynamic>? query) async {
    try {
      return await _apiClient.get(path, queryParameters: query);
    } catch (error) {
      developer.log('GET $path failed: $error', name: 'task-submissions');
      return const <dynamic>[];
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    List<dynamic> raw = const [];
    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'results']) {
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

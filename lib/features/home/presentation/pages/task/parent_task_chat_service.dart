import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../../../../core/network/api_client.dart';
import 'parent_task_list_page.dart';

enum ChatSenderType { parent, admin }

/// Same quick-react set as the web portal's `REACTION_EMOJIS` (taskchat.vue).
const List<String> kReactionEmojis = ['👍', '❤️', '😆', '😮', '😢', '😡'];

class ChatReaction {
  final String emoji;
  final int count;
  final List<String> auditorIds;

  const ChatReaction({
    required this.emoji,
    required this.count,
    this.auditorIds = const [],
  });

  factory ChatReaction.fromApi(Map<String, dynamic> json) {
    final rawCount = json['count'];
    final rawIds = json['auditor_ids'];
    return ChatReaction(
      emoji: (json['emoji'] ?? '').toString(),
      count: rawCount is num
          ? rawCount.toInt()
          : int.tryParse(rawCount?.toString() ?? '') ?? 0,
      auditorIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const [],
    );
  }

  bool reactedBy(String? parentId) =>
      parentId != null && auditorIds.contains(parentId);
}

class ChatReply {
  final String id;
  final String senderName;
  final String text;

  const ChatReply({
    required this.id,
    required this.senderName,
    required this.text,
  });
}

class ChatMessage {
  final String id;
  final ChatSenderType sender;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final List<TaskFileRef> attachments;
  final List<ChatReaction> reactions;
  final ChatReply? replyTo;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.attachments = const [],
    this.reactions = const [],
    this.replyTo,
  });

  /// Maps a row from `GET /comments` (see CommentsService.findAll in
  /// API_Alphaschool_Merge), which already enriches each row with an
  /// `auditor` object, an `images` array of file paths, and grouped
  /// `reactions`.
  factory ChatMessage.fromApi(
    Map<String, dynamic> json, {
    String fallbackTeacherName = 'Teacher',
  }) {
    final isAdmin = (json['auditor_type']?.toString().toUpperCase()) == 'ADMIN';
    final auditor = json['auditor'];

    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      sender: isAdmin ? ChatSenderType.admin : ChatSenderType.parent,
      senderName: isAdmin
          ? _adminName(auditor, fallbackTeacherName)
          : _parentName(auditor),
      text: (json['comment'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      attachments: _parseAttachments(json['images']),
      reactions: _parseReactions(json['reactions']),
      replyTo: _parseReply(json['reply_to'], fallbackTeacherName),
    );
  }

  static ChatReply? _parseReply(dynamic raw, String fallbackTeacherName) {
    if (raw is! Map) return null;
    final auditor = raw['auditor'];
    final isAdmin = raw['auditor_type']?.toString().toUpperCase() == 'ADMIN';
    return ChatReply(
      id: (raw['id'] ?? '').toString(),
      senderName: isAdmin
          ? _adminName(auditor, fallbackTeacherName)
          : _parentName(auditor),
      text: (raw['comment'] ?? '').toString(),
    );
  }

  static String _adminName(dynamic auditor, String fallback) {
    if (auditor is! Map) return fallback;
    final first = (auditor['first_name'] ?? '').toString().trim();
    final last = (auditor['last_name'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final username = (auditor['username'] ?? '').toString().trim();
    return username.isNotEmpty ? username : fallback;
  }

  static String _parentName(dynamic auditor) {
    if (auditor is! Map) return 'You';
    final first = (auditor['firstName_eng'] ?? auditor['firstName_lao'] ?? '')
        .toString()
        .trim();
    final last = (auditor['lastName_eng'] ?? auditor['lastName_lao'] ?? '')
        .toString()
        .trim();
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : 'You';
  }

  static List<TaskFileRef> _parseAttachments(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .where((path) => path != null && path.toString().trim().isNotEmpty)
        .map((path) => TaskFileRef.fromApi({'file_path': path}))
        .toList();
  }

  static List<ChatReaction> _parseReactions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChatReaction.fromApi)
        .toList();
  }
}

class TaskChatService {
  TaskChatService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ChatMessage>> fetchMessages({
    required String taskId,
    required String studentId,
    String fallbackTeacherName = 'Teacher',
  }) async {
    final response = await _apiClient.get(
      '/comments',
      queryParameters: {
        'module_type': 'TASK',
        'module_id': taskId,
        'student_id': studentId,
      },
    );
    final messages = _extractRows(response)
        .map(
          (row) => ChatMessage.fromApi(
            row,
            fallbackTeacherName: fallbackTeacherName,
          ),
        )
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  Future<void> sendMessage({
    required String taskId,
    required String parentId,
    required String studentId,
    required String text,
    String? replyToId,
  }) async {
    await _apiClient.post(
      '/comments',
      body: {
        'comment': text,
        'auditor_id': parentId,
        'auditor_type': 'PARENT',
        'module_id': taskId,
        'module_type': 'TASK',
        'student_id': studentId,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
  }

  Future<String> createMessage({
    required String taskId,
    required String parentId,
    required String studentId,
    String? replyToId,
  }) async {
    final response = await _apiClient.post(
      '/comments',
      body: {
        'comment': ' ',
        'auditor_id': parentId,
        'auditor_type': 'PARENT',
        'module_id': taskId,
        'module_type': 'TASK',
        'student_id': studentId,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
    final id = response is Map ? response['id']?.toString() : null;
    if (id == null || id.isEmpty) throw StateError('Message was not created.');
    return id;
  }

  Future<void> uploadAttachment({
    required String commentId,
    required Uint8List bytes,
    required String fileName,
  }) => _apiClient.multipartPost(
    '/files/upload',
    fields: {'module': 'comment', 'ownerId': commentId},
    fileBytes: bytes,
    fileName: fileName,
  );

  Future<void> toggleReaction({
    required String commentId,
    required String parentId,
    required String emoji,
  }) => _apiClient.post(
    '/comments/$commentId/reactions',
    body: {'auditor_id': parentId, 'auditor_type': 'PARENT', 'emoji': emoji},
  );

  Future<void> deleteMessage(String commentId) =>
      _apiClient.delete('/comments/$commentId');

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
    } else {
      developer.log('Unexpected /comments response shape', name: 'task-chat');
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

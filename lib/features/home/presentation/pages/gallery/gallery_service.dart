import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_config.dart';
import 'gallery_models.dart';

class GalleryService {
  GalleryService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<GalleryPostModel>> fetchPosts({
    String? parentId,
    String? studentId,
  }) async {
    final parent = parentId?.trim() ?? '';
    final student = studentId?.trim() ?? '';
    final response = await _api.get(
      '/galleries',
      queryParameters: {
        // A stale session can have no parent id. It must not receive the
        // management response, because that response includes private posts.
        'parent_scope': 'parent',
        if (parent.isEmpty) 'visibility': 'public',
        if (parent.isNotEmpty) 'parent_id': parent,
        if (parent.isNotEmpty) 'actor_id': parent,
        if (parent.isNotEmpty) 'actor_type': 'parent',
        if (student.isNotEmpty) 'student_id': student,
      },
    );
    final rows = _rows(response);
    return rows.map(GalleryPostModel.fromApi).toList();
  }

  Future<GalleryPostModel> fetchPost(
    String id, {
    String? parentId,
    String? actorId,
    String? studentId,
  }) async {
    final response = await _api.get(
      '/galleries/$id',
      queryParameters: {
        'parent_scope': 'parent',
        if ((parentId ?? '').isNotEmpty) 'parent_id': parentId,
        if ((actorId ?? '').isNotEmpty) 'actor_id': actorId,
        if ((actorId ?? '').isNotEmpty) 'actor_type': 'parent',
        if ((studentId ?? '').isNotEmpty) 'student_id': studentId,
      },
    );
    return GalleryPostModel.fromApi(Map<String, dynamic>.from(response as Map));
  }

  Future<({bool liked, int likesCount})> toggleLike({
    required String galleryId,
    required String actorId,
    String? studentId,
  }) async {
    final response = await _api.post(
      '/galleries/$galleryId/likes/toggle',
      body: {
        'actor_id': actorId,
        'actor_type': 'parent',
        if ((studentId ?? '').isNotEmpty) 'student_id': studentId,
      },
    );
    final json = Map<String, dynamic>.from(response as Map);
    return (
      liked: json['liked'] == true,
      likesCount: int.tryParse(json['likes_count']?.toString() ?? '') ?? 0,
    );
  }

  Future<List<GalleryCommentModel>> fetchComments(
    String galleryId, {
    String? parentId,
    String? studentId,
  }) async {
    final response = await _api.get(
      '/galleries/$galleryId/comments',
      queryParameters: {
        'parent_scope': 'parent',
        if ((parentId ?? '').isNotEmpty) 'parent_id': parentId,
        if ((studentId ?? '').isNotEmpty) 'student_id': studentId,
      },
    );
    return _rows(response).map(GalleryCommentModel.fromApi).toList();
  }

  Future<GalleryCommentModel> addComment({
    required String galleryId,
    required String authorId,
    required String body,
    String? replyToId,
    String? studentId,
  }) async {
    final response = await _api.post(
      '/galleries/$galleryId/comments',
      body: {
        'author_id': authorId,
        'author_type': 'parent',
        'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
        if ((studentId ?? '').isNotEmpty) 'student_id': studentId,
      },
    );
    return GalleryCommentModel.fromApi(
      Map<String, dynamic>.from(response as Map),
    );
  }

  static String? resolveImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.trim().isEmpty) return null;
    if (Uri.tryParse(relativePath)?.hasScheme == true) return relativePath;
    final base = Uri.parse(ApiConfig.baseUrl);
    final clean = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final uploadPath = clean.startsWith('uploads/') ? clean : 'uploads/$clean';
    return base.replace(path: '/$uploadPath').toString();
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    final values = response is List
        ? response
        : response is Map && response['data'] is List
        ? response['data'] as List
        : const <dynamic>[];
    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class GalleryPhotoModel {
  const GalleryPhotoModel({required this.id, required this.path});

  final String id;
  final String path;

  factory GalleryPhotoModel.fromApi(Map<String, dynamic> json) =>
      GalleryPhotoModel(
        id: json['id']?.toString() ?? json['file_id']?.toString() ?? '',
        path: json['file_path']?.toString() ?? json['path']?.toString() ?? '',
      );
}

class GalleryPostModel {
  const GalleryPostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.visibility,
    required this.authorName,
    required this.createdAt,
    required this.photos,
    required this.taggedStudentIds,
    required this.likesCount,
    required this.commentsCount,
    required this.viewerLiked,
    this.location,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String visibility;
  final String authorName;
  final DateTime? createdAt;
  final List<GalleryPhotoModel> photos;
  final List<String> taggedStudentIds;
  final int likesCount;
  final int commentsCount;
  final bool viewerLiked;
  final String? location;

  bool get isPrivate => visibility.toLowerCase() == 'private';
  bool get isEvent {
    final value = category.toLowerCase();
    return value.contains('event') || value.contains('กิจกรรม');
  }

  factory GalleryPostModel.fromApi(Map<String, dynamic> json) {
    List<dynamic> toList(dynamic value) => value is List ? value : const [];
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
    final authorType = json['author_type']?.toString().trim();
    final safeAuthorType = (authorType == null || authorType.isEmpty)
        ? 'School'
        : authorType;
    return GalleryPostModel(
      id: json['id']?.toString() ?? '',
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim()
          : 'School moment',
      description: json['description']?.toString().trim() ?? '',
      category: json['category']?.toString().trim() ?? 'School activity',
      visibility: json['visibility']?.toString().trim() ?? 'public',
      authorName:
          '${safeAuthorType[0].toUpperCase()}${safeAuthorType.substring(1)}',
      createdAt: parseDate(json['published_at'] ?? json['created_at']),
      photos: toList(json['photos'])
          .whereType<Map>()
          .map(
            (item) =>
                GalleryPhotoModel.fromApi(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.path.isNotEmpty)
          .toList(),
      taggedStudentIds: toList(json['tagged_student_ids'])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      likesCount: int.tryParse(json['likes_count']?.toString() ?? '') ?? 0,
      commentsCount:
          int.tryParse(json['comments_count']?.toString() ?? '') ?? 0,
      viewerLiked: json['viewer_liked'] == true,
      location: json['location']?.toString().trim().isEmpty ?? true
          ? null
          : json['location'].toString().trim(),
    );
  }

  GalleryPostModel copyWith({
    int? likesCount,
    bool? viewerLiked,
    int? commentsCount,
  }) {
    return GalleryPostModel(
      id: id,
      title: title,
      description: description,
      category: category,
      visibility: visibility,
      authorName: authorName,
      createdAt: createdAt,
      photos: photos,
      taggedStudentIds: taggedStudentIds,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewerLiked: viewerLiked ?? this.viewerLiked,
      location: location,
    );
  }
}

class GalleryCommentModel {
  const GalleryCommentModel({
    required this.id,
    required this.body,
    required this.authorName,
    required this.createdAt,
    this.replyToId,
  });

  final String id;
  final String body;
  final String authorName;
  final DateTime? createdAt;
  final String? replyToId;

  factory GalleryCommentModel.fromApi(Map<String, dynamic> json) {
    final name = json['author_name']?.toString().trim();
    final email = json['author_email']?.toString().trim();
    final type = json['author_type']?.toString().trim();
    final safeType = (type == null || type.isEmpty) ? 'Parent' : type;
    return GalleryCommentModel(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      authorName: (name != null && name.isNotEmpty)
          ? name
          : (email == null || email.isEmpty)
          ? '${safeType[0].toUpperCase()}${safeType.substring(1)}'
          : email,
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
      replyToId: json['reply_to_id']?.toString(),
    );
  }
}

String galleryShortDate(DateTime? value) {
  if (value == null) return 'Just now';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String galleryRelativeTime(DateTime? value) {
  if (value == null) return 'Just now';
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return galleryShortDate(value);
}

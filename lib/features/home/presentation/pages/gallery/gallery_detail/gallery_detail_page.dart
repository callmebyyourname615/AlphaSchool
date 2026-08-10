import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../gallery_models.dart';
import '../gallery_service.dart';

class GalleryDetailPage extends StatefulWidget {
  const GalleryDetailPage({
    super.key,
    required this.postId,
    required this.initialPost,
    required this.parentId,
    this.studentId,
  });

  final String postId;
  final GalleryPostModel initialPost;
  final String parentId;
  final String? studentId;

  @override
  State<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends State<GalleryDetailPage> {
  final _service = GalleryService();
  final _commentController = TextEditingController();
  final _commentsKey = GlobalKey();
  GalleryPostModel? _post;
  List<GalleryCommentModel> _comments = const [];
  String? _replyToId;
  bool _loading = true;
  bool _sending = false;
  int _activePhoto = 0;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<dynamic>([
        _service.fetchPost(
          widget.postId,
          parentId: widget.parentId,
          actorId: widget.parentId,
          studentId: widget.studentId,
        ),
        _service.fetchComments(
          widget.postId,
          parentId: widget.parentId,
          studentId: widget.studentId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _post = values[0] as GalleryPostModel;
        _comments = values[1] as List<GalleryCommentModel>;
        _activePhoto = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null || widget.parentId.isEmpty) return;
    final optimistic = post.copyWith(
      viewerLiked: !post.viewerLiked,
      likesCount: post.likesCount + (post.viewerLiked ? -1 : 1),
    );
    setState(() => _post = optimistic);
    try {
      final result = await _service.toggleLike(
        galleryId: post.id,
        actorId: widget.parentId,
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(
          () => _post = post.copyWith(
            likesCount: result.likesCount,
            viewerLiked: result.liked,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _post = post);
    }
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _sending || widget.parentId.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await _service.addComment(
        galleryId: widget.postId,
        authorId: widget.parentId,
        body: body,
        replyToId: _replyToId,
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _post = _post?.copyWith(commentsCount: (_post?.commentsCount ?? 0) + 1);
        _replyToId = null;
        _commentController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send your comment. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _scrollToComments() async {
    final commentsContext = _commentsKey.currentContext;
    if (commentsContext == null) return;
    await Scrollable.ensureVisible(
      commentsContext,
      alignment: .08,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openPhotoPreview(int initialIndex) async {
    final post = _post;
    if (post == null || post.photos.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (context) => _GalleryPhotoPreview(
        post: post,
        initialIndex: initialIndex,
        onDownload: _downloadImage,
      ),
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Could not download this image.');
      }
      final fileName = _downloadFileName(imageUrl);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)) {
        final result = await ImageGallerySaverPlus.saveImage(
          response.bodyBytes,
          quality: 100,
          name: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        );
        final saved = result is Map
            ? result['isSuccess'] == true || result['is_success'] == true
            : result != null;
        if (!saved) throw Exception('The image could not be saved.');
      } else {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            XTypeGroup(label: 'Images', extensions: [_fileExtension(fileName)]),
          ],
        );
        if (location == null) return;
        await XFile.fromData(
          response.bodyBytes,
          name: fileName,
          mimeType: response.headers['content-type'] ?? 'image/jpeg',
        ).saveTo(location.path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image downloaded successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to download this image.')),
      );
    }
  }

  static String _downloadFileName(String url) {
    final name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    return name.contains('.')
        ? name
        : 'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  static String _fileExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return extension.isEmpty ? 'jpg' : extension;
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF102A5C),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gallery',
          style: TextStyle(
            color: Color(0xFF102A5C),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: post == null && _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        _PostHeader(post: post!),
                        const SizedBox(height: 14),
                        _PhotoViewer(
                          post: post,
                          activeIndex: _activePhoto,
                          onChanged: (index) =>
                              setState(() => _activePhoto = index),
                          onPreview: () => _openPhotoPreview(_activePhoto),
                        ),
                        const SizedBox(height: 14),
                        _ActionRow(
                          post: post,
                          onLike: _toggleLike,
                          onComments: _scrollToComments,
                        ),
                        const SizedBox(height: 16),
                        _DetailsCard(post: post),
                        const SizedBox(height: 22),
                        KeyedSubtree(
                          key: _commentsKey,
                          child: _CommentsSection(
                            comments: _comments,
                            parentNameFor: _commentParentName,
                            onReply: (comment) =>
                                setState(() => _replyToId = comment.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _CommentComposer(
                  controller: _commentController,
                  isSending: _sending,
                  replying: _replyToId != null,
                  onCancelReply: () => setState(() => _replyToId = null),
                  onEmoji: _insertEmoji,
                  onSend: _sendComment,
                ),
              ],
            ),
    );
  }

  String _commentParentName(GalleryCommentModel comment) {
    if (comment.replyToId == null) return '';
    for (final candidate in _comments) {
      if (candidate.id == comment.replyToId) return candidate.authorName;
    }
    return '';
  }

  void _insertEmoji() {
    const emoji = ['👍', '❤️', '😊', '🎉', '👏', '😍'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: emoji
              .map(
                (item) => InkWell(
                  onTap: () {
                    _commentController.text = '${_commentController.text}$item';
                    Navigator.pop(context);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(item, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});
  final GalleryPostModel post;
  @override
  Widget build(BuildContext context) {
    final color = post.isPrivate
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              post.isEvent
                  ? Icons.celebration_outlined
                  : Icons.photo_library_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172A52),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      post.isPrivate
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.isPrivate
                          ? 'Private · ${galleryRelativeTime(post.createdAt)}'
                          : 'Public · ${galleryRelativeTime(post.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6E7C96),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({
    required this.post,
    required this.activeIndex,
    required this.onChanged,
    required this.onPreview,
  });
  final GalleryPostModel post;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onPreview;
  @override
  Widget build(BuildContext context) {
    if (post.photos.isEmpty) return const _PhotoFallback();
    final image = GalleryService.resolveImageUrl(post.photos[activeIndex].path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: image == null ? null : onPreview,
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.25,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image == null)
                    const _PhotoFallback()
                  else
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _PhotoFallback(),
                    ),
                  if (image != null)
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: _ExpandPhotoHint(),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (post.photos.length > 1) ...[
          const SizedBox(height: 9),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: post.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final thumb = GalleryService.resolveImageUrl(
                  post.photos[index].path,
                );
                final selected = index == activeIndex;
                return InkWell(
                  onTap: () => onChanged(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE0E6F0),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: thumb == null
                        ? const _PhotoFallback()
                        : Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _PhotoFallback(),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _GalleryPhotoPreview extends StatefulWidget {
  const _GalleryPhotoPreview({
    required this.post,
    required this.initialIndex,
    required this.onDownload,
  });

  final GalleryPostModel post;
  final int initialIndex;
  final ValueChanged<String> onDownload;

  @override
  State<_GalleryPhotoPreview> createState() => _GalleryPhotoPreviewState();
}

class _GalleryPhotoPreviewState extends State<_GalleryPhotoPreview> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _activeIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.post.photos;
    final activeUrl = GalleryService.resolveImageUrl(photos[_activeIndex].path);
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF080B12),
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (index) => setState(() => _activeIndex = index),
              itemBuilder: (context, index) {
                final image = GalleryService.resolveImageUrl(
                  photos[index].path,
                );
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: image == null
                        ? const _DarkPhotoFallback()
                        : Image.network(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const _DarkPhotoFallback(),
                          ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _PreviewControl(
                    icon: Icons.close_rounded,
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _PreviewControl(
                    icon: Icons.download_rounded,
                    tooltip: 'Download image',
                    onPressed: activeUrl == null
                        ? null
                        : () => widget.onDownload(activeUrl),
                  ),
                ],
              ),
            ),
            if (photos.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_activeIndex + 1} / ${photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewControl extends StatelessWidget {
  const _PreviewControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xFF111827).withValues(alpha: .82),
      foregroundColor: Colors.white,
    ),
    icon: Icon(icon),
  );
}

class _DarkPhotoFallback extends StatelessWidget {
  const _DarkPhotoFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF111827),
    child: Center(
      child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CAAC0)),
    ),
  );
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEAF0FA),
    child: Center(
      child: Icon(Icons.image_outlined, color: Color(0xFF94A5C2), size: 36),
    ),
  );
}

class _ExpandPhotoHint extends StatelessWidget {
  const _ExpandPhotoHint();

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: const Color(0xFF102A5C).withValues(alpha: .72),
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 19),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.post,
    required this.onLike,
    required this.onComments,
  });
  final GalleryPostModel post;
  final VoidCallback onLike;
  final VoidCallback onComments;
  @override
  Widget build(BuildContext context) {
    final likeColor = post.viewerLiked
        ? const Color(0xFFE64C67)
        : const Color(0xFF65738C);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onLike,
              icon: Icon(
                post.viewerLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: likeColor,
                size: 20,
              ),
              label: Text(
                '${post.likesCount} Likes',
                style: TextStyle(color: likeColor, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Container(height: 24, width: 1, color: const Color(0xFFE5EAF2)),
          Expanded(
            child: TextButton.icon(
              onPressed: onComments,
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF65738C),
                size: 19,
              ),
              label: Text(
                '${post.commentsCount} Comments',
                style: const TextStyle(
                  color: Color(0xFF65738C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.post});
  final GalleryPostModel post;
  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String label, String value})>[
      (icon: Icons.category_outlined, label: 'Category', value: post.category),
      (
        icon: Icons.group_outlined,
        label: 'Audience',
        value: post.isPrivate ? 'Your family' : 'School community',
      ),
      if (post.location != null)
        (
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: post.location!,
        ),
      (
        icon: Icons.calendar_today_outlined,
        label: 'Shared',
        value: galleryShortDate(post.createdAt),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.description.isNotEmpty) ...[
            Text(
              post.description,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Color(0xFF52617B),
              ),
            ),
            const SizedBox(height: 15),
          ],
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172A52),
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(row.icon, size: 17, color: const Color(0xFF64738D)),
                  const SizedBox(width: 9),
                  Text(
                    '${row.label}: ',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7B88A0),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF263855),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.parentNameFor,
    required this.onReply,
  });

  final List<GalleryCommentModel> comments;
  final String Function(GalleryCommentModel comment) parentNameFor;
  final ValueChanged<GalleryCommentModel> onReply;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments (0)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172A52),
            ),
          ),
          SizedBox(height: 12),
          _CommentsEmpty(),
        ],
      );
    }

    final scrollHeight = math.min(
      344.0,
      math.max(116.0, comments.length * 104.0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${comments.length})',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172A52),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: scrollHeight,
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5FA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E7F0)),
          ),
          child: Scrollbar(
            thumbVisibility: comments.length > 3,
            child: ListView.separated(
              padding: const EdgeInsets.only(right: 8),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final comment = comments[index];
                return _CommentTile(
                  comment: comment,
                  parentName: parentNameFor(comment),
                  onReply: () => onReply(comment),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentsEmpty extends StatelessWidget {
  const _CommentsEmpty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE4E9F2)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Center(
      child: Text(
        'No comments yet. Start the conversation!',
        style: TextStyle(color: Color(0xFF71809A)),
      ),
    ),
  );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.parentName,
    required this.onReply,
  });
  final GalleryCommentModel comment;
  final String parentName;
  final VoidCallback onReply;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: comment.replyToId == null ? 0 : 28,
      bottom: 14,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF1FF),
            shape: BoxShape.circle,
          ),
          child: Text(
            comment.authorName.isNotEmpty ? comment.authorName[0] : 'P',
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6EAF1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF243552),
                      ),
                    ),
                    if (parentName.isNotEmpty)
                      Text(
                        'Replying to $parentName',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      comment.body,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF52617B),
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    galleryRelativeTime(comment.createdAt),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF8A98B0),
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    onTap: onReply,
                    child: const Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF52617B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.isSending,
    required this.replying,
    required this.onCancelReply,
    required this.onEmoji,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool isSending;
  final bool replying;
  final VoidCallback onCancelReply;
  final VoidCallback onEmoji;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4E9F2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replying)
            Row(
              children: [
                const Icon(
                  Icons.reply_rounded,
                  size: 15,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Replying to comment',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 17),
                  onPressed: onCancelReply,
                ),
              ],
            ),
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEAF1FF),
                child: Text(
                  'P',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(color: Color(0xFF9AA6B9)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEmoji,
                icon: const Icon(
                  Icons.emoji_emotions_outlined,
                  color: Color(0xFF687792),
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: FilledButton(
                  onPressed: isSending ? null : onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

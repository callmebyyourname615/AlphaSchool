import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/services/session_service.dart';
import 'gallery_detail/gallery_detail_page.dart';
import 'gallery_models.dart';
import 'gallery_service.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, this.backgroundAsset, this.selectedStudentId});

  final String? backgroundAsset;
  final String? selectedStudentId;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _tabs = ['All Post', 'Public Post', 'Individual Post'];
  final _searchController = TextEditingController();
  final _galleryService = GalleryService();
  String _activeTab = _tabs.first;
  String _query = '';
  String _parentId = '';
  bool _loading = true;
  String? _error;
  List<GalleryPostModel> _posts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SessionService().load();
      _parentId = session?.id ?? '';
      final posts = await _galleryService.fetchPosts(
        parentId: _parentId,
        studentId: widget.selectedStudentId,
      );
      if (!mounted) return;
      setState(() => _posts = posts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'We could not load the gallery right now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GalleryPostModel> get _visiblePosts {
    final query = _query.trim().toLowerCase();
    return _scopedPosts.where((post) {
      final inTab = switch (_activeTab) {
        'Public Post' => !post.isPrivate,
        'Individual Post' => post.isPrivate,
        _ => true,
      };
      final inSearch =
          query.isEmpty ||
          '${post.title} ${post.description} ${post.category}'
              .toLowerCase()
              .contains(query);
      return inTab && inSearch;
    }).toList();
  }

  /// The API enforces this rule too. Keeping this final UI guard means a
  /// private post can never be painted for a sibling if a stale/cached API
  /// response is received by the app.
  List<GalleryPostModel> get _scopedPosts {
    final studentId = widget.selectedStudentId?.trim() ?? '';
    return _posts.where((post) {
      if (!post.isPrivate) return true;
      return studentId.isNotEmpty && post.taggedStudentIds.contains(studentId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF7F8FC);
    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF2563EB),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _GalleryHero()),
              SliverToBoxAdapter(
                child: _TabBar(
                  tabs: _tabs,
                  active: _activeTab,
                  onSelected: (tab) => setState(() => _activeTab = tab),
                ),
              ),
              SliverToBoxAdapter(
                child: _SearchBox(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              if (_activeTab == 'Individual Post')
                const SliverToBoxAdapter(child: _PrivateNotice()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _GalleryError(message: _error!, onRetry: _load),
                )
              else if (_visiblePosts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGallery(tab: _activeTab),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: _visiblePosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final post = _visiblePosts[index];
                      return _GalleryPostCard(
                            post: post,
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => GalleryDetailPage(
                                      postId: post.id,
                                      initialPost: post,
                                      parentId: _parentId,
                                      studentId: widget.selectedStudentId,
                                    ),
                                  ),
                                )
                                .then((_) => _load()),
                          )
                          .animate()
                          .fadeIn(delay: (index * 45).ms, duration: 230.ms)
                          .slideY(
                            begin: .035,
                            end: 0,
                            duration: 260.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryHero extends StatelessWidget {
  const _GalleryHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF102A5C),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gallery',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102A5C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.active,
    required this.onSelected,
  });
  final List<String> tabs;
  final String active;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: tabs.map((tab) {
            final selected = tab == active;
            return InkWell(
              onTap: () => onSelected(tab),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 13, 8, 11),
                margin: const EdgeInsets.only(right: 22),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF71809B),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E6F0)),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF92A0B8)),
            hintText: 'Search posts, events, or albums...',
            hintStyle: TextStyle(color: Color(0xFF92A0B8), fontSize: 14),
            contentPadding: EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }
}

class _PrivateNotice extends StatelessWidget {
  const _PrivateNotice();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3D5FE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF7C3AED)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Private photos are shared by teachers only with your family.',
              style: TextStyle(
                color: Color(0xFF5B6680),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPostCard extends StatelessWidget {
  const _GalleryPostCard({required this.post, required this.onTap});
  final GalleryPostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = post.isPrivate
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4E9F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      post.isEvent
                          ? Icons.celebration_outlined
                          : Icons.photo_library_outlined,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF172A52),
                                ),
                              ),
                            ),
                            _VisibilityChip(post: post),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${post.authorName} · ${galleryRelativeTime(post.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF7B88A2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF8D9AB1),
                  ),
                ],
              ),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 11),
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.38,
                    color: Color(0xFF596882),
                  ),
                ),
              ],
              if (post.photos.isNotEmpty) ...[
                const SizedBox(height: 13),
                _PhotoStrip(post: post),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE8ECF3)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.group_outlined, color: accent, size: 17),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      post.isPrivate
                          ? 'Shared privately with your family'
                          : '${post.taggedStudentIds.length} students tagged',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF65738C),
                      ),
                    ),
                  ),
                  _Metric(
                    icon: Icons.thumb_up_outlined,
                    text: '${post.likesCount}',
                  ),
                  const SizedBox(width: 15),
                  _Metric(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: '${post.commentsCount}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.post});
  final GalleryPostModel post;
  @override
  Widget build(BuildContext context) {
    final color = post.isPrivate
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            post.isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            post.isPrivate ? 'Private' : 'Public',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.post});
  final GalleryPostModel post;
  @override
  Widget build(BuildContext context) {
    final display = post.photos.take(4).toList();
    return SizedBox(
      height: 78,
      child: Row(
        children: List.generate(display.length, (index) {
          final url = GalleryService.resolveImageUrl(display[index].path);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == display.length - 1 ? 0 : 5,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PhotoPlaceholder(),
                      )
                    else
                      const _PhotoPlaceholder(),
                    if (index == 3 && post.photos.length > 4)
                      Container(
                        color: const Color(0xAA102A5C),
                        alignment: Alignment.center,
                        child: Text(
                          '+${post.photos.length - 4}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEAF0FA),
    child: Center(child: Icon(Icons.image_outlined, color: Color(0xFF8FA0BE))),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF7886A0)),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF65738C)),
      ),
    ],
  );
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery({required this.tab});
  final String tab;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: Color(0xFF9AA8C0),
            size: 46,
          ),
          const SizedBox(height: 14),
          Text(
            'No ${tab.toLowerCase()} yet',
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF172A52),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'New school moments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF71809A)),
          ),
        ],
      ),
    ),
  );
}

class _GalleryError extends StatelessWidget {
  const _GalleryError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFF9AA8C0),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5C6B84)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

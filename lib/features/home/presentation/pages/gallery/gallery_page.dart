import 'package:alpha_school/features/home/presentation/pages/gallery/gallery_detail/gallery_detail_page.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/widgets/app_page_template.dart';

import '../gallery/gallery_detail/gallery_detail_page.dart';
import 'gallery_models.dart';

class GalleryPage extends StatefulWidget {
  final String backgroundAsset;

  const GalleryPage({
    super.key,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late final List<GalleryItemModel> _items;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _items = [
      GalleryItemModel(
        id: 'g1',
        tag: GalleryTag.taskDone,
        title: 'Deployment Completed',
        description:
            'Latest web build has been deployed successfully. Firebase Hosting is now serving the newest version.',
        uploadedBy: 'Developer',
        uploadedAt: now.subtract(const Duration(days: 1, hours: 3)),
        imageUrl:
            'https://images.unsplash.com/photo-1518779578993-ec3579fee39f?auto=format&fit=crop&w=1400&q=80',
      ),
      GalleryItemModel(
        id: 'g2',
        tag: GalleryTag.event,
        title: 'School Event',
        description:
            'Highlights from today’s campus event — parents, students, and teachers joined together.',
        uploadedBy: 'Admin',
        uploadedAt: now.subtract(const Duration(days: 2, hours: 5)),
        imageUrl:
            'https://images.unsplash.com/photo-1523580846011-d3a5bc25702b?auto=format&fit=crop&w=1400&q=80',
      ),
      GalleryItemModel(
        id: 'g3',
        tag: GalleryTag.taskDone,
        title: 'Content Produced',
        description:
            'Short intro video has been recorded. Next step: edit & add subtitles for multi-language support.',
        uploadedBy: 'Content Team',
        uploadedAt: now.subtract(const Duration(days: 3, hours: 2)),
        imageUrl:
            'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?auto=format&fit=crop&w=1400&q=80',
      ),
      GalleryItemModel(
        id: 'g4',
        tag: GalleryTag.event,
        title: 'Meeting Day',
        description:
            'Parent-teacher meeting session notes and snapshots. Topics: progress, attendance, and next actions.',
        uploadedBy: 'Teacher',
        uploadedAt: now.subtract(const Duration(days: 4, hours: 1)),
        imageUrl:
            'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1400&q=80',
      ),
      GalleryItemModel(
        id: 'g5',
        tag: GalleryTag.taskDone,
        title: 'Design Delivered',
        description:
            'Registration week banner set has been completed and handed over to the team for publishing.',
        uploadedBy: 'Design Team',
        uploadedAt: now.subtract(const Duration(days: 5, hours: 6)),
        imageUrl:
            'https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&w=1400&q=80',
      ),
      GalleryItemModel(
        id: 'g6',
        tag: GalleryTag.event,
        title: 'Campus Moment',
        description:
            'Quick capture from campus activities — a warm and friendly atmosphere around the school.',
        uploadedBy: 'Front Office',
        uploadedAt: now.subtract(const Duration(days: 6, hours: 4)),
        imageUrl:
            'https://images.unsplash.com/photo-1520975682031-a6ad7b0b0f11?auto=format&fit=crop&w=1400&q=80',
      ),
    ];
  }

  void _openDetail(GalleryItemModel item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GalleryDetailPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return AppPageTemplate(
      title: 'Gallery',
      backgroundAsset: widget.backgroundAsset,
      animate: true,
      premiumDark: true,
      showBack: true,
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GalleryGrid(items: _items, onTap: _openDetail)
              .animate()
              .fadeIn(duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }
}

// ================= UI: GRID =================

class _GalleryGrid extends StatelessWidget {
  final List<GalleryItemModel> items;
  final ValueChanged<GalleryItemModel> onTap;

  const _GalleryGrid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // responsive columns
    final crossAxisCount = w >= 1100
        ? 4
        : w >= 820
        ? 3
        : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) {
        final it = items[i];
        return _GalleryTile(item: it, onTap: () => onTap(it))
            .animate()
            .fadeIn(delay: (60 + i * 50).ms, duration: 220.ms)
            .slideY(
              begin: .06,
              end: 0,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryItemModel item;
  final VoidCallback onTap;

  const _GalleryTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: shadow,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: isDark
                          ? Colors.white.withOpacity(.06)
                          : const Color(0xFFF3F4F6),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? Colors.white.withOpacity(.85)
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark
                        ? Colors.white.withOpacity(.06)
                        : const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(LucideIcons.imageOff, size: 30),
                    ),
                  ),
                ),

                // overlay gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(.05),
                          Colors.black.withOpacity(.42),
                        ],
                      ),
                    ),
                  ),
                ),

                // chip (top-left)
                Positioned(
                  left: 12,
                  top: 12,
                  child: _MiniChip(
                    icon: galleryTagIcon(item.tag),
                    label: galleryTagText(item.tag),
                  ),
                ),

                // title (bottom)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleSmall?.copyWith(
                      color: Colors.white.withOpacity(.95),
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                          color: Colors.black.withOpacity(.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Small UI Pieces =================

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.45),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .15,
            ),
          ),
        ],
      ),
    );
  }
}

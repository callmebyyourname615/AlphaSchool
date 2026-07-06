import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../../core/widgets/app_page_template.dart';

import '../gallery_models.dart';

class GalleryDetailPage extends StatelessWidget {
  final GalleryItemModel item;
  final String backgroundAsset;

  const GalleryDetailPage({
    super.key,
    required this.item,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    return AppPageTemplate(
      title: 'Gallery Detail',
      backgroundAsset: backgroundAsset,
      animate: true,
      premiumDark: true,
      showBack: true,
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailCard(item: item, isDark: isDark)
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

class _DetailCard extends StatelessWidget {
  final GalleryItemModel item;
  final bool isDark;

  const _DetailCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    final titleColor = isDark ? Colors.white : Colors.black.withOpacity(.90);
    final descColor = isDark ? Colors.white.withOpacity(.78) : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // big image
          AspectRatio(
            aspectRatio: 16 / 9,
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

                // overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(.05),
                          Colors.black.withOpacity(.52),
                        ],
                      ),
                    ),
                  ),
                ),

                // chip (top-left)
                Positioned(
                  left: 12,
                  top: 12,
                  child:
                      _MiniChip(
                            icon: galleryTagIcon(item.tag),
                            label: galleryTagText(item.tag),
                          )
                          .animate()
                          .fadeIn(duration: 220.ms)
                          .slideX(
                            begin: -.10,
                            end: 0,
                            duration: 420.ms,
                            curve: Curves.easeOutCubic,
                          ),
                ),
              ],
            ),
          ),

          // content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ Title
                Text(
                  item.title,
                  style: t.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 8),

                // ✅ Description
                Text(
                  item.description,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: descColor,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // ✅ Meta rows
                _MetaRow(
                  icon: LucideIcons.user,
                  label: 'Upload by',
                  value: item.uploadedBy,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: LucideIcons.calendarDays,
                  label: 'Event',
                  value: galleryTagText(item.tag),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: LucideIcons.clock3,
                  label: 'Upload at',
                  value: fmtDateTime(item.uploadedAt),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? Colors.white.withOpacity(.88)
        : Colors.black.withOpacity(.80);

    final muted = isDark
        ? Colors.white.withOpacity(.65)
        : Colors.black.withOpacity(.55);

    final bg = isDark ? Colors.white.withOpacity(.08) : const Color(0xFFF3F4F6);
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Text(
            '$label :',
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= chip =================

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

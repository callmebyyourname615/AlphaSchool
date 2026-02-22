// news_details_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// ✅ Model that NewsPage can pass to this page
class NewsArticle {
  final String category;
  final String title;

  final String authorName;
  final String authorAvatarUrl;

  final String timeAgo;
  final int views;

  final String headerImageUrl;

  /// short intro / lead
  final String lead;

  /// optional highlight quote
  final String? quote;

  /// body paragraphs
  final List<String> paragraphs;

  // NOTE:
  // Keep this constructor NON-const to avoid Hot Reload limitations that can
  // throw: "Const class cannot remove fields" when you tweak model fields.
  NewsArticle({
    required this.category,
    required this.title,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.timeAgo,
    required this.views,
    required this.headerImageUrl,
    required this.lead,
    this.quote,
    required this.paragraphs,
  });
}

/// ✅ Details page (NO AppPageTemplate)
class NewsDetailsPage extends StatelessWidget {
  const NewsDetailsPage({super.key, required this.article});

  final NewsArticle article;

  static const _bgDark = Color(0xFF0B1220);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageBg = isDark ? _bgDark : const Color(0xFFF6F7FB);

    // ✅ consistent tokens (fix “white card + white text” imbalance)
    final titleC = isDark ? _DarkTokens.on : const Color(0xFF0F172A);
    final subC = isDark ? _DarkTokens.onMuted : const Color(0xFF475569);
    final bodyC = isDark
        ? Colors.white.withOpacity(.86)
        : const Color(0xFF0F172A).withOpacity(.88);

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          // soft background glow
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.2, -0.9),
                    radius: 1.0,
                    colors: [
                      _dotColor(
                        article.category,
                      ).withOpacity(isDark ? .22 : .16),
                      pageBg,
                    ],
                  ),
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HeaderImage(url: article.headerImageUrl)
                    .animate()
                    .fadeIn(duration: 260.ms)
                    .scale(
                      begin: const Offset(.98, .98),
                      end: const Offset(1, 1),
                    ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // category pill + actions
                      Row(
                            children: [
                              _Pill(
                                label: article.category,
                                dotColor: _dotColor(article.category),
                              ),
                              const Spacer(),
                              _IconPillButton(
                                icon: FontAwesomeIcons.bookmark,
                                onTap: () {},
                              ),
                              const SizedBox(width: 10),
                              _IconPillButton(
                                icon: FontAwesomeIcons.shareNodes,
                                onTap: () {},
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(delay: 90.ms, duration: 220.ms)
                          .slideY(
                            begin: .18,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 12),

                      // title
                      Text(
                            article.title,
                            style: TextStyle(
                              color: titleC,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.12,
                              letterSpacing: -0.2,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 240.ms)
                          .slideY(
                            begin: .14,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 14),

                      // author row + stats (✅ fixed dark surface)
                      _GlassCard(
                            radius: 18,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            tint: _dotColor(article.category),
                            child: Row(
                              children: [
                                _Avatar(url: article.authorAvatarUrl, size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        article.authorName,
                                        style: TextStyle(
                                          color: titleC,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            FontAwesomeIcons.clock,
                                            size: 12,
                                            color: subC,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            article.timeAgo,
                                            style: TextStyle(
                                              color: subC,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            FontAwesomeIcons.eye,
                                            size: 12,
                                            color: subC,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "${article.views} views",
                                            style: TextStyle(
                                              color: subC,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _dotColor(
                                      article.category,
                                    ).withOpacity(isDark ? .18 : .12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(.12)
                                          : Colors.black.withOpacity(.06),
                                    ),
                                  ),
                                  child: Icon(
                                    FontAwesomeIcons.newspaper,
                                    size: 14,
                                    color: _dotColor(article.category),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 190.ms, duration: 240.ms)
                          .slideY(
                            begin: .12,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 16),

                      // lead
                      Text(
                            article.lead,
                            style: TextStyle(
                              color: subC,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 230.ms, duration: 240.ms)
                          .slideY(
                            begin: .10,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),

                      if ((article.quote ?? "").trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _QuoteCard(
                              text: article.quote!.trim(),
                              color: _dotColor(article.category),
                            )
                            .animate()
                            .fadeIn(delay: 280.ms, duration: 260.ms)
                            .slideY(
                              begin: .12,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            ),
                      ],

                      const SizedBox(height: 16),

                      // body paragraphs
                      ...List.generate(article.paragraphs.length, (i) {
                        final p = article.paragraphs[i].trim();
                        if (p.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              Text(
                                    p,
                                    style: TextStyle(
                                      color: bodyC,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.65,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: (320 + i * 90).ms,
                                    duration: 260.ms,
                                  )
                                  .slideY(
                                    begin: .10,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                        );
                      }),

                      const SizedBox(height: 10),

                      // bottom action
                      SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _dotColor(
                                  article.category,
                                ).withOpacity(isDark ? .95 : .92),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Back to News",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 540.ms, duration: 260.ms)
                          .slideY(
                            begin: .12,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // glass top bar (back) ✅ change title to news header/title
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 10,
            child:
                _GlassTopBar(
                      title: article.title,
                      onBack: () => Navigator.of(context).maybePop(),
                    )
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideY(begin: -.25, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// Dark tokens + Glass surface (✅ fix dark “white card” imbalance)
// ======================================================

class _DarkTokens {
  static const panelA = Color(0xFF0B2B5B);
  static const panelB = Color(0xFF071A33);
  static const panelC = Color(0xFF060B16);

  static Color border = Colors.white.withOpacity(.12);
  static Color shadow = Colors.black.withOpacity(.45);

  static Color on = Colors.white.withOpacity(.92);
  static Color onMuted = Colors.white.withOpacity(.72);
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.tint,
    this.blur = 16,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color blend(Color base, double amt) {
      final t = tint;
      if (t == null) return base;
      return Color.lerp(base, t, amt) ?? base;
    }

    if (isDark) {
      final g1 = blend(_DarkTokens.panelA, .10).withOpacity(.70);
      final g2 = blend(_DarkTokens.panelB, .08).withOpacity(.86);
      final g3 = blend(_DarkTokens.panelC, .05).withOpacity(.92);

      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: _DarkTokens.border),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g1, g2, g3],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                  color: _DarkTokens.shadow,
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    }

    final baseTop = Colors.white.withOpacity(.92);
    final baseBottom = Colors.white.withOpacity(.78);
    final t = tint;
    final tintTop = t == null
        ? baseTop
        : (Color.lerp(baseTop, t, .06) ?? baseTop);
    final tintBottom = t == null
        ? baseBottom
        : (Color.lerp(baseBottom, t, .04) ?? baseBottom);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.black.withOpacity(.08)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tintTop, tintBottom],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 12),
                color: Colors.black.withOpacity(.10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ======================================================
// UI Parts
// ======================================================

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    const h = 280.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: isDark ? Colors.white.withOpacity(.10) : Colors.black12,
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: isDark
                      ? Colors.white.withOpacity(.85)
                      : const Color(0xFF0F172A),
                ),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: isDark
                      ? Colors.white.withOpacity(.08)
                      : Colors.black12,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark
                              ? Colors.white.withOpacity(.85)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // overlay gradient for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.22),
                    Colors.black.withOpacity(.10),
                    Colors.black.withOpacity(.58),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTopBar extends StatelessWidget {
  const _GlassTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fg = Colors.white;
    final bg = Colors.white.withOpacity(isDark ? .10 : .16);
    final border = Colors.white.withOpacity(isDark ? .14 : .20);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(14),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 44, height: 44), // keep title centered
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.05);
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.08);
    final fg = isDark ? Colors.white.withOpacity(.90) : const Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Center(child: Icon(icon, size: 16, color: fg)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.dotColor});

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.05);
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.08);
    final textC = isDark
        ? Colors.white.withOpacity(.92)
        : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textC,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      tint: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "“$text”",
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(.88)
                    : const Color(0xFF0F172A).withOpacity(.86),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: isDark ? Colors.white.withOpacity(.10) : Colors.black12,
          child: Icon(
            Icons.person_rounded,
            color: isDark
                ? Colors.white.withOpacity(.85)
                : const Color(0xFF0F172A),
          ),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: isDark ? Colors.white.withOpacity(.08) : Colors.black12,
          );
        },
      ),
    );
  }
}

// ======================================================
// Helpers
// ======================================================

Color _dotColor(String c) {
  switch (c.toLowerCase()) {
    case "exams":
      return const Color.fromARGB(255, 168, 0, 0); // ✅ fixed (was dark red)
    case "scholarships":
      return const Color(0xFF8B5CF6);
    case "events":
      return const Color(0xFFF59E0B);
    case "sports":
      return const Color(0xFFFACC15);
    case "health":
      return const Color(0xFF10B981);
    case "campus":
      return const Color(0xFF0EA5E9);
    case "education":
      return const Color(0xFF3B82F6);
    default:
      return const Color(0xFF60A5FA);
  }
}

// news_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ✅ Use your template
import '../../../../../core/widgets/app_page_template.dart';

// ✅ AppTheme (same pattern as Saving/Homework fixes)
import '../../../../../core/theme/app_theme.dart';

// ✅ IMPORTANT: adjust this import path to where you saved NewsDetailPage
import './sub-news/news_detail.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  static const _bgAsset = "assets/images/homepagewall/mainbg.jpeg";

  @override
  State<NewsPage> createState() => _NewsPageState();
}

enum _FilterMode { day, month, year }

class _NewsPageState extends State<NewsPage> {
  final _searchCtl = TextEditingController();

  _FilterMode _mode = _FilterMode.day;
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _selectedYear = DateTime.now().year;

  String _selectedCategory = "All";

  // ===== DEMO: Education / School news =====
  late final List<_NewsItem> _featured = <_NewsItem>[
    _NewsItem(
      category: "Exams",
      title: "Midterm timetable\nis officially released",
      summary: "Check dates, rooms, and what to prepare for each subject.",
      imageUrl:
          "https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=1200",
      accent: const Color(0xFFEC4899),
      date: DateTime.now().subtract(const Duration(hours: 4)),
      views: 1380,
    ),
    _NewsItem(
      category: "Scholarships",
      title: "Scholarship 2026:\nApplications are open",
      summary: "Eligibility, required documents, and submission deadline.",
      imageUrl:
          "https://images.unsplash.com/photo-1454165205744-3b78555e5572?w=1200",
      accent: const Color(0xFF8B5CF6),
      date: DateTime.now().subtract(const Duration(hours: 9)),
      views: 972,
    ),
  ];

  late final List<_NewsItem> _list = <_NewsItem>[
    _NewsItem(
      category: "Campus",
      title: "Parent meeting schedule for Grade 5–6",
      summary: "Time, location, and topics to be discussed with teachers.",
      imageUrl:
          "https://images.unsplash.com/photo-1529070538774-1843cb3265df?w=1200",
      accent: const Color(0xFF0EA5E9),
      date: DateTime.now().subtract(const Duration(minutes: 40)),
      views: 373,
    ),
    _NewsItem(
      category: "Education",
      title: "New homework guidelines: less stress, more learning",
      summary: "Shorter tasks, clearer rubrics, and better feedback loop.",
      imageUrl:
          "https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=1200",
      accent: const Color(0xFF3B82F6),
      date: DateTime.now().subtract(const Duration(hours: 3)),
      views: 1060,
    ),
    _NewsItem(
      category: "Exams",
      title: "How to prepare for Math midterm effectively",
      summary: "A simple checklist and practice plan you can follow daily.",
      imageUrl:
          "https://images.unsplash.com/photo-1509228468518-180dd4864904?w=1200",
      accent: const Color(0xFFEC4899),
      date: DateTime.now().subtract(const Duration(hours: 6)),
      views: 812,
    ),
    _NewsItem(
      category: "Events",
      title: "Science fair: project submission deadline extended",
      summary: "New deadline + tips for a clean presentation board.",
      imageUrl:
          "https://images.unsplash.com/photo-1567427018141-0584cfcbf1b8?w=1200",
      accent: const Color(0xFFF59E0B),
      date: DateTime.now().subtract(const Duration(hours: 10)),
      views: 640,
    ),
    _NewsItem(
      category: "Sports",
      title: "Inter-class futsal tournament starts next week",
      summary: "Team list, match day, and rules (fair play first).",
      imageUrl:
          "https://images.unsplash.com/photo-1518091043644-c1d4457512c6?w=1200",
      accent: const Color(0xFFFACC15),
      date: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      views: 505,
    ),
    _NewsItem(
      category: "Health",
      title: "School health notice: seasonal flu prevention",
      summary:
          "Hand-wash routine, masks (if needed), and rest recommendations.",
      imageUrl:
          "https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=1200",
      accent: const Color(0xFF10B981),
      date: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
      views: 901,
    ),
  ];

  final _categories = <_CatChip>[
    _CatChip("All", const Color(0xFF111827)),
    _CatChip("Education", const Color(0xFF3B82F6)),
    _CatChip("Campus", const Color(0xFF0EA5E9)),
    _CatChip("Exams", const Color(0xFFEC4899)),
    _CatChip("Scholarships", const Color(0xFF8B5CF6)),
    _CatChip("Events", const Color(0xFFF59E0B)),
    _CatChip("Sports", const Color(0xFFFACC15)),
    _CatChip("Health", const Color(0xFF10B981)),
  ];

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // ✅ Navigate to detail and pass data
  void _openDetail(_NewsItem item) {
    final article = item.toArticle();
    Navigator.of(
      context,
    ).push(_fadeSlideRoute(NewsDetailsPage(article: article)));
  }

  // ✅ nice transition (fade + slide)
  PageRouteBuilder _fadeSlideRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: 320.ms,
      reverseTransitionDuration: 260.ms,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _pickFilterValue() async {
    if (!mounted) return;

    switch (_mode) {
      case _FilterMode.day:
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDay,
          firstDate: DateTime(2018, 1, 1),
          lastDate: DateTime(2100, 12, 31),
        );
        if (d != null) setState(() => _selectedDay = d);
        break;

      case _FilterMode.month:
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedMonth,
          firstDate: DateTime(2018, 1, 1),
          lastDate: DateTime(2100, 12, 31),
          helpText: "Select any date in the month",
        );
        if (d != null)
          setState(() => _selectedMonth = DateTime(d.year, d.month, 1));
        break;

      case _FilterMode.year:
        final nowY = DateTime.now().year;
        final years = List.generate(12, (i) => nowY - 10 + i);
        final y = await showDialog<int>(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              contentTextStyle: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
              ),
              title: const Text("Select year"),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: ListView.separated(
                  itemCount: years.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(.10)
                        : Colors.black12,
                  ),
                  itemBuilder: (_, i) {
                    final yy = years[i];
                    final selected = yy == _selectedYear;
                    return ListTile(
                      title: Text(
                        "$yy",
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_rounded,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop(yy),
                    );
                  },
                ),
              ),
            );
          },
        );
        if (y != null) setState(() => _selectedYear = y);
        break;
    }
  }

  String _filterLabel() {
    String two(int v) => v.toString().padLeft(2, "0");
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    switch (_mode) {
      case _FilterMode.day:
        return "${two(_selectedDay.day)} ${months[_selectedDay.month - 1]} ${_selectedDay.year}";
      case _FilterMode.month:
        return "${months[_selectedMonth.month - 1]} ${_selectedMonth.year}";
      case _FilterMode.year:
        return "$_selectedYear";
    }
  }

  bool _matchDate(DateTime d) {
    if (_mode == _FilterMode.day) {
      return d.year == _selectedDay.year &&
          d.month == _selectedDay.month &&
          d.day == _selectedDay.day;
    }
    if (_mode == _FilterMode.month) {
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }
    return d.year == _selectedYear;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: ensure Theme brightness matches AppTheme.mode (prevents "dark text + white card" mismatch)
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final locale = Localizations.localeOf(context);
        final base = (mode == ThemeMode.dark)
            ? AppTheme.darkTheme(locale)
            : AppTheme.lightTheme(locale);

        return AnimatedTheme(
          data: base,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final query = _searchCtl.text.trim().toLowerCase();
              final filteredList = _list.where((e) {
                final matchCat =
                    _selectedCategory == "All" ||
                    e.category == _selectedCategory;
                final matchQuery =
                    query.isEmpty ||
                    e.title.toLowerCase().contains(query) ||
                    e.summary.toLowerCase().contains(query);
                final matchDate = _matchDate(e.date);
                return matchCat && matchQuery && matchDate;
              }).toList();

              return AppPageTemplate(
                title: "News",
                backgroundAsset: NewsPage._bgAsset,
                scrollable: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(
                          controller: _searchCtl,
                          onChanged: (_) => setState(() {}),
                        )
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideY(begin: .08, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 12),

                    _FilterBar(
                          mode: _mode,
                          label: _filterLabel(),
                          onChangeMode: (m) => setState(() => _mode = m),
                          onPick: _pickFilterValue,
                        )
                        .animate()
                        .fadeIn(delay: 60.ms, duration: 220.ms)
                        .slideY(begin: .10, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 18),

                    _SectionHeader(
                          title: "Featured",
                          actionText: "View all",
                          onAction: () {},
                        )
                        .animate()
                        .fadeIn(delay: 110.ms, duration: 220.ms)
                        .slideY(begin: .08, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _featured.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final item = _featured[i];
                          return _FeaturedCard(
                                item: item,
                                onTap: () => _openDetail(item),
                              )
                              .animate()
                              .fadeIn(
                                delay: (140 + i * 90).ms,
                                duration: 240.ms,
                              )
                              .slideX(
                                begin: .12,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    _WideEducationCard(
                          category: "Education",
                          title:
                              "Study smarter:\nSimple habits for\nbetter grades",
                        )
                        .animate()
                        .fadeIn(delay: 210.ms, duration: 240.ms)
                        .slideY(begin: .10, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 20),

                    _SectionHeader(
                          title: "Latest News",
                          actionText: "See more",
                          onAction: () {},
                        )
                        .animate()
                        .fadeIn(delay: 260.ms, duration: 220.ms)
                        .slideY(begin: .08, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final c = _categories[i];
                          final selected = c.label == _selectedCategory;
                          return _CategoryChip(
                                label: c.label,
                                color: c.color,
                                selected: selected,
                                onTap: () =>
                                    setState(() => _selectedCategory = c.label),
                              )
                              .animate()
                              .fadeIn(
                                delay: (290 + i * 30).ms,
                                duration: 180.ms,
                              )
                              .slideY(begin: .12, end: 0);
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    ListView.separated(
                      itemCount: filteredList.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => Divider(
                        height: 20,
                        thickness: 1,
                        color: isDark
                            ? Colors.white.withOpacity(.10)
                            : Colors.black12,
                      ),
                      itemBuilder: (context, i) {
                        final item = filteredList[i];
                        return _NewsListRow(
                              item: item,
                              onTap: () => _openDetail(item),
                            )
                            .animate()
                            .fadeIn(delay: (330 + i * 55).ms, duration: 220.ms)
                            .slideY(
                              begin: .08,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ======================================================
// Dark tokens + Glass surface (✅ same fix style as Homework)
// ======================================================

class _DarkTokens {
  static const panelA = Color(0xFF0B2B5B);
  static const panelB = Color(0xFF071A33);
  static const panelC = Color(0xFF060B16);

  static Color border = Colors.white.withOpacity(.12);
  static Color shadow = Colors.black.withOpacity(.45);

  static Color on = Colors.white.withOpacity(.92);
  static Color onMuted = Colors.white.withOpacity(.72);
  static Color onSoft = Colors.white.withOpacity(.60);
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

    final baseTop = Colors.white.withOpacity(.90);
    final baseBottom = Colors.white.withOpacity(.76);
    final t = tint;

    final tintTop = t == null
        ? baseTop
        : (Color.lerp(baseTop, t, .07) ?? baseTop);
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
                blurRadius: 26,
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
// Widgets
// ======================================================

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hint = isDark
        ? Colors.white.withOpacity(.48)
        : const Color(0xFF9CA3AF);
    final textC = isDark ? Colors.white : const Color(0xFF111827);
    final iconC = isDark
        ? Colors.white.withOpacity(.78)
        : const Color(0xFF6B7280);

    return _GlassCard(
      radius: 16,
      padding: const EdgeInsets.only(left: 14),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(color: textC, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Search here",
                  hintStyle: TextStyle(
                    color: hint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () => FocusScope.of(context).unfocus(),
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 54,
                height: 50,
                child: Center(
                  child: Icon(FontAwesomeIcons.search, size: 18, color: iconC),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.mode,
    required this.label,
    required this.onChangeMode,
    required this.onPick,
  });

  final _FilterMode mode;
  final String label;
  final ValueChanged<_FilterMode> onChangeMode;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _ModeChip(
            label: "Day",
            selected: mode == _FilterMode.day,
            onTap: () => onChangeMode(_FilterMode.day),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: "Month",
            selected: mode == _FilterMode.month,
            onTap: () => onChangeMode(_FilterMode.month),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: "Year",
            selected: mode == _FilterMode.year,
            onTap: () => onChangeMode(_FilterMode.year),
          ),
          const Spacer(),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(.08)
                    : Colors.white.withOpacity(.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(.12)
                      : Colors.black.withOpacity(.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: isDark
                        ? Colors.white.withOpacity(.86)
                        : const Color(0xFF111827),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(.92)
                          : const Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      height: 1.0,
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = selected
        ? (isDark ? Colors.white.withOpacity(.16) : const Color(0xFF111827))
        : (isDark ? Colors.white.withOpacity(.06) : Colors.white);

    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.10);

    final textC = selected
        ? Colors.white
        : (isDark ? Colors.white.withOpacity(.82) : const Color(0xFF111827));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textC,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionText,
    this.onAction,
  });

  final String title;
  final String actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              actionText,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(.62)
                    : const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.onTap});

  final _NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const cardW = 260.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: cardW,
            decoration: BoxDecoration(
              // ✅ FIX: dark card should not read as "white"
              color: isDark
                  ? const Color(0xFF0B1220).withOpacity(.35)
                  : Colors.white,
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(.12) : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(isDark ? .25 : .10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _NetImage(
                    url: item.imageUrl,
                    fallbackColor: item.accent.withOpacity(.55),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(.08),
                          Colors.black.withOpacity(.32),
                          Colors.black.withOpacity(.66),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Pill(
                    label: item.category,
                    dotColor: _dotColor(item.category),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.clock,
                            size: 12,
                            color: Colors.white.withOpacity(.78),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _prettyTime(item.date),
                            style: TextStyle(
                              color: Colors.white.withOpacity(.78),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            FontAwesomeIcons.eye,
                            size: 12,
                            color: Colors.white.withOpacity(.78),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${item.views} views",
                            style: TextStyle(
                              color: Colors.white.withOpacity(.78),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _dotColor(String c) {
    switch (c.toLowerCase()) {
      case "exams":
        return const Color(0xFFEC4899);
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
        return Colors.white;
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.dotColor});

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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

class _WideEducationCard extends StatelessWidget {
  const _WideEducationCard({required this.category, required this.title});

  final String category;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassCard(
      radius: 22,
      padding: EdgeInsets.zero,
      tint: const Color(0xFF8B5CF6),
      child: SizedBox(
        height: 132,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                child: Container(
                  width: 160,
                  color: (isDark ? Colors.white : const Color(0xFFD8B4FE))
                      .withOpacity(isDark ? .06 : .55),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -16,
                        top: 14,
                        child: Icon(
                          Icons.extension_rounded,
                          size: 120,
                          color:
                              (isDark ? Colors.white : const Color(0xFF8B5CF6))
                                  .withOpacity(isDark ? .10 : .22),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 22,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? Colors.white
                                        : const Color(0xFF8B5CF6))
                                    .withOpacity(isDark ? .06 : .14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 18,
                        child: Row(
                          children: [
                            _TinyPill(isDark: isDark),
                            const SizedBox(width: 8),
                            _TinyPill(isDark: isDark),
                            const SizedBox(width: 8),
                            _TinyPill(isDark: isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TagRow(label: category, dot: const Color(0xFF8B5CF6)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 6,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : const Color(0xFF8B5CF6)).withOpacity(
          isDark ? .08 : .22,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.label, required this.dot});

  final String label;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textC = isDark
        ? Colors.white.withOpacity(.90)
        : const Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: textC,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = selected
        ? (isDark ? Colors.white.withOpacity(.16) : const Color(0xFF111827))
        : color.withOpacity(isDark ? .14 : .16);

    final border = selected
        ? (isDark
              ? Colors.white.withOpacity(.22)
              : Colors.black.withOpacity(.10))
        : color.withOpacity(isDark ? .26 : .28);

    final textC = selected
        ? Colors.white
        : (isDark ? Colors.white.withOpacity(.92) : const Color(0xFF111827));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(label), size: 14, color: textC.withOpacity(.95)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textC,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String v) {
    switch (v.toLowerCase()) {
      case "all":
        return FontAwesomeIcons.layerGroup;
      case "education":
        return FontAwesomeIcons.graduationCap;
      case "campus":
        return FontAwesomeIcons.school;
      case "exams":
        return FontAwesomeIcons.penToSquare;
      case "scholarships":
        return FontAwesomeIcons.award;
      case "events":
        return FontAwesomeIcons.calendarDays;
      case "sports":
        return FontAwesomeIcons.futbol;
      case "health":
        return FontAwesomeIcons.heartPulse;
      default:
        return FontAwesomeIcons.solidNewspaper;
    }
  }
}

class _NewsListRow extends StatelessWidget {
  const _NewsListRow({required this.item, required this.onTap});

  final _NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleC = isDark ? Colors.white : const Color(0xFF111827);
    final metaC = isDark
        ? Colors.white.withOpacity(.65)
        : const Color(0xFF9CA3AF);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: _NetImage(
                  url: item.imageUrl,
                  fallbackColor: item.accent.withOpacity(.55),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleC,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${_prettyTime(item.date)}  •  ${item.views} views",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: metaC,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, required this.fallbackColor});

  final String url;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fallbackColor.withOpacity(.85),
                fallbackColor.withOpacity(.35),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              FontAwesomeIcons.solidImage,
              color: Colors.white.withOpacity(.85),
              size: 20,
            ),
          ),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: fallbackColor.withOpacity(isDark ? .12 : .18),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(.80),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======================================================
// Models
// ======================================================

class _NewsItem {
  final String category;
  final String title;
  final String summary;
  final String imageUrl;
  final Color accent;
  final DateTime date;
  final int views;

  _NewsItem({
    required this.category,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.accent,
    required this.date,
    required this.views,
  });

  NewsArticle toArticle() {
    return NewsArticle(
      category: category,
      title: title,
      authorName: "School Admin",
      authorAvatarUrl:
          "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300",
      timeAgo: _prettyTime(date),
      views: views,
      headerImageUrl: imageUrl,
      lead: summary,
      quote: "Stay organized, keep practicing, and you’ll do great.",
      paragraphs: [
        "This announcement is shared to help students and parents plan ahead. Please check your class group for more details and updates.",
        "If you have questions, contact your homeroom teacher or the school office during working hours.",
      ],
    );
  }
}

class _CatChip {
  final String label;
  final Color color;
  _CatChip(this.label, this.color);
}

// ======================================================
// Helpers
// ======================================================

String _prettyTime(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
  if (diff.inHours < 24) return "${diff.inHours} hours ago";
  return "${diff.inDays} days ago";
}

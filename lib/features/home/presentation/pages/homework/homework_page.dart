// homework_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ✅ App theme (same pattern as Saving/Appointment)
import '../../../../../core/theme/app_theme.dart';

// ✅ ปรับ path ให้ตรงโปรเจกต์คุณ
import '../../../../../core/widgets/app_page_template.dart';

// =====================
// Models (bind real data later)
// =====================

enum HomeworkStatus { submitted, pending }

class HomeworkItem {
  final String subject;
  final String grade; // e.g. M.2 / ມ.2
  final HomeworkStatus status;

  final String? teacher;
  final String? description;

  final double? score; // if submitted
  final DateTime? sentAt; // when submitted
  final DateTime deadline;

  HomeworkItem({
    required this.subject,
    required this.grade,
    required this.status,
    this.teacher,
    this.description,
    this.score,
    this.sentAt,
    required this.deadline,
  });
}

enum HomeworkSort { nearestDue, latestDue, subjectAZ }

// =====================
// Page
// =====================

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({
    super.key,
    this.title = "Homework",
    this.backgroundAsset = "assets/images/homepagewall/mainbg.jpeg",
    this.items,
  });

  final String title;
  final String backgroundAsset;
  final List<HomeworkItem>? items;

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  final _searchCtrl = TextEditingController();

  int _filter = 0; // 0=all, 1=pending, 2=done, 3=overdue
  HomeworkSort _sort = HomeworkSort.nearestDue;

  late List<HomeworkItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items ?? _mock();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Ensure dark mode text + surfaces are consistent (fix white-card/white-text mismatch)
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
              final now = DateTime.now();

              final doneCount = _items
                  .where((e) => e.status == HomeworkStatus.submitted)
                  .length;
              final pendingCount = _items.length - doneCount;
              final overdueCount = _items
                  .where(
                    (e) =>
                        e.status != HomeworkStatus.submitted &&
                        e.deadline.isBefore(now),
                  )
                  .length;

              final ratio = _items.isEmpty ? 0.0 : (doneCount / _items.length);

              // ---- filter + search ----
              final q = _searchCtrl.text.trim().toLowerCase();

              List<HomeworkItem> list = _items.where((e) {
                if (q.isEmpty) return true;
                return e.subject.toLowerCase().contains(q) ||
                    e.grade.toLowerCase().contains(q) ||
                    (e.teacher ?? "").toLowerCase().contains(q);
              }).toList();

              list = switch (_filter) {
                0 => list,
                1 =>
                  list
                      .where(
                        (e) =>
                            e.status == HomeworkStatus.pending &&
                            !e.deadline.isBefore(now),
                      )
                      .toList(),
                2 =>
                  list
                      .where((e) => e.status == HomeworkStatus.submitted)
                      .toList(),
                _ =>
                  list
                      .where(
                        (e) =>
                            e.status == HomeworkStatus.pending &&
                            e.deadline.isBefore(now),
                      )
                      .toList(),
              };

              // ---- sort ----
              list.sort((a, b) {
                switch (_sort) {
                  case HomeworkSort.nearestDue:
                    return a.deadline.compareTo(b.deadline);
                  case HomeworkSort.latestDue:
                    return b.deadline.compareTo(a.deadline);
                  case HomeworkSort.subjectAZ:
                    return a.subject.toLowerCase().compareTo(
                      b.subject.toLowerCase(),
                    );
                }
              });

              return AppPageTemplate(
                title: widget.title,
                backgroundAsset: widget.backgroundAsset,
                showBack: true,
                scrollable: true,
                animate: true,
                premiumDark: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(
                          total: _items.length,
                          done: doneCount,
                          pending: pendingCount,
                          overdue: overdueCount,
                          ratio: ratio,
                        )
                        .animate()
                        .fadeIn(duration: 260.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 14),

                    _SearchAndSortRow(
                          controller: _searchCtrl,
                          sort: _sort,
                          onSortChanged: (v) => setState(() => _sort = v),
                        )
                        .animate()
                        .fadeIn(duration: 260.ms, delay: 60.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(
                                    "Homework List",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 220.ms, delay: 90.ms)
                                  .slideX(begin: 0.03, end: 0),
                        ),
                        Text(
                              "${list.length} items",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 220.ms, delay: 120.ms)
                            .slideX(begin: 0.03, end: 0),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _FilterRow(
                          value: _filter,
                          onChanged: (v) => setState(() => _filter = v),
                        )
                        .animate()
                        .fadeIn(duration: 220.ms, delay: 150.ms)
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 12),

                    if (list.isEmpty)
                      _EmptyState(query: q)
                          .animate()
                          .fadeIn(duration: 220.ms, delay: 180.ms)
                          .slideY(begin: 0.06, end: 0)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final hw = list[i];
                          return _HomeworkCard(
                                item: hw,
                                now: now,
                                onTap: () => _openDetail(context, hw, now),
                                onPrimary: () => _openDetail(context, hw, now),
                              )
                              .animate()
                              .fadeIn(
                                duration: 220.ms,
                                delay: (200 + i * 70).ms,
                              )
                              .slideY(
                                begin: 0.07,
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

  void _openDetail(BuildContext context, HomeworkItem item, DateTime now) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => _HomeworkDetailSheet(item: item, now: now),
    );
  }

  List<HomeworkItem> _mock() {
    final now = DateTime.now();
    return [
      HomeworkItem(
        subject: "Mathematics",
        grade: "M.2",
        teacher: "Chanthasone Xaymani",
        description: "Solve worksheet page 12 (1–20).",
        status: HomeworkStatus.submitted,
        score: 9.5,
        sentAt: now.subtract(const Duration(hours: 18)),
        deadline: now.add(const Duration(days: 1, hours: 3)),
      ),
      HomeworkItem(
        subject: "English",
        grade: "M.2",
        teacher: "Somsri K.",
        description: "Write 10 sentences using Past Tense.",
        status: HomeworkStatus.pending,
        deadline: now.add(const Duration(days: 2, hours: 2)),
      ),
      HomeworkItem(
        subject: "Science",
        grade: "M.2",
        teacher: "Khamla S.",
        description: "Short report: Water cycle (1 page).",
        status: HomeworkStatus.submitted,
        score: 8.0,
        sentAt: now.subtract(const Duration(days: 1, hours: 4)),
        deadline: now.add(const Duration(days: 3)),
      ),
      HomeworkItem(
        subject: "Thai",
        grade: "M.2",
        teacher: "Arisa P.",
        description: "Read chapter 3 and answer questions.",
        status: HomeworkStatus.pending,
        deadline: now.subtract(const Duration(hours: 6)), // overdue
      ),
    ];
  }
}

// =====================
// Dark tokens (match SavingPage vibe)
// =====================

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

// =====================
// Modern UI building blocks
// =====================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// ✅ tint แบบจาง ๆ
  final Color? tint;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = tint;

    // ✅ FIX: Dark mode should not look like a white card.
    // Use deep panels (SavingPage-like) + subtle tint blend.
    if (isDark) {
      Color blend(Color base, double amt) {
        if (t == null) return base;
        // keep it subtle so it stays balanced
        return Color.lerp(base, t, amt) ?? base;
      }

      final g1 = blend(_DarkTokens.panelA, .10).withOpacity(.70);
      final g2 = blend(_DarkTokens.panelB, .08).withOpacity(.86);
      final g3 = blend(_DarkTokens.panelC, .05).withOpacity(.92);

      final highlightTop = Colors.white.withOpacity(.06);
      final highlightBottom = Colors.white.withOpacity(0);

      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [highlightTop, highlightBottom],
                        ),
                      ),
                    ),
                  ),
                ),
                // extra soft tint overlay for accent (optional)
                if (t != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [t.withOpacity(.08), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Light mode (unchanged)
    final border = Colors.black.withOpacity(.08);

    final baseTop = Colors.white.withOpacity(.90);
    final baseBottom = Colors.white.withOpacity(.76);

    final tintTop = t == null
        ? baseTop
        : Color.lerp(baseTop, t, .07)!.withOpacity(1);
    final tintBottom = t == null
        ? baseBottom
        : Color.lerp(baseBottom, t, .04)!.withOpacity(1);

    final highlightTop = Colors.white.withOpacity(.18);
    final highlightBottom = Colors.white.withOpacity(0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
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
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [highlightTop, highlightBottom],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color fg;
  final Color bg;
  final Color stroke;

  const _ModernChip({
    required this.text,
    this.icon,
    required this.fg,
    required this.bg,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double ratio;
  const _ProgressBar({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: bg,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth * ratio.clamp(0.0, 1.0);
            return Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: 360.ms,
                width: w,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF22C55E),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================
// Top Summary
// =====================

class _SummaryCard extends StatelessWidget {
  final int total;
  final int done;
  final int pending;
  final int overdue;
  final double ratio;

  const _SummaryCard({
    required this.total,
    required this.done,
    required this.pending,
    required this.overdue,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final label = isDark ? _DarkTokens.onMuted : Colors.black54;
    final value = isDark ? Colors.white : Colors.black87;

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    .08,
                  ),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Overview",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: label,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Homework Progress",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: value,
                      ),
                    ),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _ModernChip(
                  text: "$done/$total",
                  icon: Icons.verified_rounded,
                  fg: isDark ? Colors.white : const Color(0xFF16A34A),
                  bg: const Color(0xFF16A34A).withOpacity(isDark ? .18 : .09),
                  stroke: const Color(
                    0xFF16A34A,
                  ).withOpacity(isDark ? .32 : .26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressBar(ratio: ratio),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill(
                icon: Icons.grid_view_rounded,
                label: "All",
                value: "$total",
              ),
              _StatPill(
                icon: Icons.schedule_rounded,
                label: "Pending",
                value: "$pending",
                tint: const Color(0xFFF59E0B),
              ),
              _StatPill(
                icon: Icons.verified_rounded,
                label: "Done",
                value: "$done",
                tint: const Color(0xFF22C55E),
              ),
              _StatPill(
                icon: Icons.warning_amber_rounded,
                label: "Overdue",
                value: "$overdue",
                tint: const Color(0xFFDC2626),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? tint;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.04);
    final stroke = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);

    final labelC = isDark ? _DarkTokens.onMuted : Colors.black54;
    final valueC = isDark ? Colors.white : Colors.black87;

    final acc = tint ?? (isDark ? Colors.white70 : Colors.black54);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: acc),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(fontWeight: FontWeight.w800, color: labelC),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: valueC),
          ),
        ],
      ),
    );
  }
}

// =====================
// Search + Sort (✅ responsive กัน overflow)
// =====================

class _SearchAndSortRow extends StatelessWidget {
  const _SearchAndSortRow({
    required this.controller,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final HomeworkSort sort;
  final ValueChanged<HomeworkSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 430;

        final search = _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          radius: 18,
          child: _SearchField(controller: controller),
        );

        final sortBtn = _SortButton(sort: sort, onChanged: onSortChanged);

        if (!isNarrow) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              sortBtn,
            ],
          );
        }

        return Column(
          children: [
            search,
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: sortBtn),
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          Icons.search_rounded,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: "Search subject / grade / teacher",
              hintStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: controller.clear,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final HomeworkSort sort;
  final ValueChanged<HomeworkSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ FIX: popup menu text was sometimes black on dark background
    final menuTextStyle = TextStyle(
      fontWeight: FontWeight.w900,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      radius: 18,
      child: PopupMenuButton<HomeworkSort>(
        onSelected: onChanged,
        color: isDark ? const Color(0xFF0B1220) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: HomeworkSort.nearestDue,
            child: Text("Nearest due", style: menuTextStyle),
          ),
          PopupMenuItem(
            value: HomeworkSort.latestDue,
            child: Text("Latest due", style: menuTextStyle),
          ),
          PopupMenuItem(
            value: HomeworkSort.subjectAZ,
            child: Text("Subject A–Z", style: menuTextStyle),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              _label(sort),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(HomeworkSort s) {
    switch (s) {
      case HomeworkSort.nearestDue:
        return "Due";
      case HomeworkSort.latestDue:
        return "Late";
      case HomeworkSort.subjectAZ:
        return "A–Z";
    }
  }
}

// =====================
// Filter row
// =====================

class _FilterRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _FilterRow({required this.value, required this.onChanged});

  Color _accent(int v) {
    switch (v) {
      case 0:
        return const Color(0xFF2563EB); // All = blue
      case 1:
        return const Color(0xFFF59E0B); // Pending = amber
      case 2:
        return const Color(0xFF16A34A); // Done = green
      default:
        return const Color(0xFFDC2626); // Overdue = red
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 560;

        Widget segBox(String label, int v, IconData icon, {double? width}) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final active = value == v;

          final acc = _accent(v);

          final fg = active ? acc : acc.withOpacity(isDark ? .80 : .65);

          final bg = active
              ? acc.withOpacity(isDark ? .18 : .11)
              : (isDark
                    ? Colors.white.withOpacity(.07)
                    : Colors.white.withOpacity(.78));

          final stroke = active
              ? acc.withOpacity(isDark ? .48 : .30)
              : (isDark
                    ? Colors.white.withOpacity(.12)
                    : Colors.black.withOpacity(.06));

          final child = Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: 220.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: stroke),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (width == null) return Expanded(child: child);
          return SizedBox(width: width, child: child);
        }

        if (!isNarrow) {
          return Row(
            children: [
              segBox("All", 0, Icons.grid_view_rounded),
              const SizedBox(width: 10),
              segBox("Pending", 1, Icons.schedule_rounded),
              const SizedBox(width: 10),
              segBox("Done", 2, Icons.verified_rounded),
              const SizedBox(width: 10),
              segBox("Overdue", 3, Icons.warning_amber_rounded),
            ],
          );
        }

        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            segBox("All", 0, Icons.grid_view_rounded, width: w),
            segBox("Pending", 1, Icons.schedule_rounded, width: w),
            segBox("Done", 2, Icons.verified_rounded, width: w),
            segBox("Overdue", 3, Icons.warning_amber_rounded, width: w),
          ],
        );
      },
    );
  }
}

// =====================
// Homework Card
// =====================

class _HomeworkCard extends StatelessWidget {
  final HomeworkItem item;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onPrimary;

  const _HomeworkCard({
    required this.item,
    required this.now,
    required this.onTap,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDone = item.status == HomeworkStatus.submitted;
    final isOverdue = !isDone && item.deadline.isBefore(now);

    final green = const Color(0xFF16A34A);
    final amber = const Color(0xFFF59E0B);
    final red = const Color(0xFFDC2626);
    final blue = const Color(0xFF2563EB);

    final tint = isDone ? green : (isOverdue ? red : amber);

    final chipColor = isDone ? green : (isOverdue ? red : amber);
    final chipBg = isDark
        ? chipColor.withOpacity(.22)
        : chipColor.withOpacity(.14);
    final chipStroke = isDark
        ? chipColor.withOpacity(.38)
        : chipColor.withOpacity(.30);
    final chipFg = isDark ? Colors.white : chipColor;

    final titleC = isDark ? Colors.white : Colors.black87;
    final subC = isDark ? Colors.white70 : Colors.black54;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: _GlassCard(
        tint: tint,
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: titleC,
                    ),
                  ),
                ),
                _ModernChip(
                  text: isDone ? "DONE" : (isOverdue ? "OVERDUE" : "PENDING"),
                  icon: isDone
                      ? Icons.verified_rounded
                      : isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  fg: chipFg,
                  bg: chipBg,
                  stroke: chipStroke,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if ((item.teacher ?? "").isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 16, color: subC),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.teacher!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : blue,
                      ),
                    ),
                  ),
                ],
              ),
            if ((item.description ?? "").isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withOpacity(.90)
                      : Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaChip(
                  label: "GRADE",
                  value: item.grade,
                  icon: Icons.class_rounded,
                ),
                _MetaChip(
                  label: "SCORE",
                  value: item.score == null
                      ? "-"
                      : item.score!.toStringAsFixed(1),
                  icon: Icons.bar_chart_rounded,
                ),
                _MetaChip(
                  label: "SENT",
                  value: item.sentAt == null ? "-" : _fmt(item.sentAt!),
                  icon: Icons.send_rounded,
                ),
                _MetaChip(
                  label: "DUE",
                  value: _fmt(item.deadline),
                  icon: Icons.alarm_rounded,
                  emphasize: !isDone,
                  accent: isOverdue ? const Color(0xFFDC2626) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PrimaryButton(
                    label: isDone ? "View" : "Submit",
                    icon: isDone
                        ? Icons.visibility_rounded
                        : Icons.upload_rounded,
                    tint: isDone ? green : (isOverdue ? red : amber),
                    onTap: onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                _GhostIconButton(icon: Icons.more_horiz_rounded, onTap: onTap),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;
  final Color? accent;

  const _MetaChip({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.04);
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);

    final labelColor = isDark ? _DarkTokens.onMuted : Colors.black54;
    final valueColor = emphasize
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white.withOpacity(.92) : Colors.black87);

    final acc =
        accent ??
        (emphasize
            ? const Color(0xFF2563EB)
            : (isDark ? Colors.white70 : Colors.black54));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: acc),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(fontWeight: FontWeight.w800, color: labelColor),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = tint.withOpacity(isDark ? .20 : .12);
    final stroke = tint.withOpacity(.28);
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GhostIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.black.withOpacity(.04);
    final stroke = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final fg = isDark ? Colors.white70 : Colors.black54;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }
}

// =====================
// Bottom Sheet Detail
// =====================

class _HomeworkDetailSheet extends StatelessWidget {
  final HomeworkItem item;
  final DateTime now;

  const _HomeworkDetailSheet({required this.item, required this.now});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDone = item.status == HomeworkStatus.submitted;
    final isOverdue = !isDone && item.deadline.isBefore(now);

    final tint = isDone
        ? const Color(0xFF16A34A)
        : (isOverdue ? const Color(0xFFDC2626) : const Color(0xFFF59E0B));

    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: 220.ms,
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + viewInsets),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(.12)
                        : Colors.black.withOpacity(.10),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark ? const Color(0xFF0B1220) : Colors.white)
                          .withOpacity(isDark ? .94 : .90),
                      (isDark ? const Color(0xFF0B1220) : Colors.white)
                          .withOpacity(isDark ? .86 : .82),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset: const Offset(0, -12),
                      color: Colors.black.withOpacity(isDark ? .40 : .14),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          _ModernChip(
                            text: isDone
                                ? "DONE"
                                : (isOverdue ? "OVERDUE" : "PENDING"),
                            icon: isDone
                                ? Icons.verified_rounded
                                : isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded,
                            fg: isDark ? Colors.white : tint,
                            bg: tint.withOpacity(isDark ? .16 : .09),
                            stroke: tint.withOpacity(isDark ? .30 : .26),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        tint: tint,
                        radius: 20,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                              icon: Icons.class_rounded,
                              label: "Grade",
                              value: item.grade,
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.person_rounded,
                              label: "Teacher",
                              value: item.teacher ?? "-",
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.alarm_rounded,
                              label: "Deadline",
                              value: _fmt(item.deadline),
                              emphasize: !isDone,
                              accent: isOverdue
                                  ? const Color(0xFFDC2626)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.send_rounded,
                              label: "Sent",
                              value: item.sentAt == null
                                  ? "-"
                                  : _fmt(item.sentAt!),
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.bar_chart_rounded,
                              label: "Score",
                              value: item.score == null
                                  ? "-"
                                  : item.score!.toStringAsFixed(1),
                            ),
                            if ((item.description ?? "").isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                "Description",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? _DarkTokens.onMuted
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.description!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white.withOpacity(.92)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PrimaryButton(
                              label: isDone ? "Close" : "Submit",
                              icon: isDone
                                  ? Icons.close_rounded
                                  : Icons.upload_rounded,
                              tint: tint,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.10, end: 0),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  final Color? accent;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelC = isDark ? _DarkTokens.onMuted : Colors.black54;
    final valueC = emphasize
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white.withOpacity(.92) : Colors.black87);

    return Row(
      children: [
        Icon(icon, size: 18, color: accent ?? labelC),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "$label:",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, color: labelC),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: accent ?? valueC,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================
// Empty state
// =====================

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.08),
            ),
            child: Icon(
              Icons.inbox_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              query.isEmpty
                  ? "No homework items."
                  : "No results for \"$query\"",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

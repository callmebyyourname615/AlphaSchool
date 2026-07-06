// study_plan_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alpha_school/core/widgets/app_page_template.dart';
import 'package:alpha_school/core/widgets/app_modern_count_tabbar.dart' as tabs;

// ---- Helpers (avoid withOpacity deprecated) ----
int _alpha(double o) => (o * 255).round().clamp(0, 255);
Color _o(Color c, double opacity) => c.withAlpha(_alpha(opacity));

// ✅ SavingPage tokens (match /saving_page.dart vibe)
const Color _kSavingBtnColor = Color(0xFF3B5FD9);
const Color _kSavingBtnGlow = Color(0xFF284A9D);

// ✅ dark premium gradient that Saving page uses in panels
const Gradient _kSavingPremiumGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B2B5B), Color(0xFF071A33), Color(0xFF060B16)],
);

// ✅ tab indicator gradient (NOT the bright sky-blue one)
const Gradient _kSavingTabIndicatorGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_kSavingBtnColor, _kSavingBtnGlow, Color(0xFF0B2B5B)],
);

Color _accent(BuildContext context, bool isDark) =>
    isDark ? _kSavingBtnColor : Theme.of(context).colorScheme.primary;

Color _accentStrong(BuildContext context, bool isDark) =>
    isDark ? _kSavingBtnGlow : Theme.of(context).colorScheme.tertiary;

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({
    super.key,
    this.backgroundAsset = _kDefaultBg,
    this.showBack = true,
  });

  final String backgroundAsset;
  final bool showBack;

  static const String _kDefaultBg = 'assets/images/homepagewall/mainbg.jpeg';

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final List<SubjectDemo> _subjects = SubjectDemoFactory.build15();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ unselected label (Saving-like)
    final unselected = isDark ? _o(Colors.white, .60) : _o(Colors.black87, .58);

    return AppPageTemplate(
      title: "Study Plan",
      backgroundAsset: widget.backgroundAsset,
      showBack: widget.showBack,
      scrollable: false,

      // ✅ IMPORTANT: make it look like SavingPage when Dark mode
      premiumDark: isDark,
      premiumDarkGradient: _kSavingPremiumGradient,

      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tabs.AppModernCountTabBar(
            controller: _tab,

            // ✅ indicator uses Saving-like gradient (no more bright blue)
            indicatorGradient: _kSavingTabIndicatorGradient,

            labelColor: Colors.white,
            unselectedLabelColor: unselected,
            items: const [
              tabs.AppTabItem(
                label: "Evaluation",
                icon: LucideIcons.clipboardCheck,
                count: null,
              ),
              tabs.AppTabItem(
                label: "Exam scores",
                icon: LucideIcons.squarePen,
                count: null,
              ),
              tabs.AppTabItem(
                label: "Final score",
                icon: LucideIcons.award,
                count: null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: List.generate(3, (tabIndex) {
                return _SubjectListView(
                  subjects: _subjects,
                  tabIndex: tabIndex,
                  onTap: (s) {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: 280.ms,
                        reverseTransitionDuration: 220.ms,
                        pageBuilder: (_, a1, __) => FadeTransition(
                          opacity: a1,
                          child: SubjectDetailPage(
                            subject: s,
                            initialTabIndex: tabIndex,
                            backgroundAsset: widget.backgroundAsset,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectListView extends StatelessWidget {
  const _SubjectListView({
    required this.subjects,
    required this.tabIndex,
    required this.onTap,
  });

  final List<SubjectDemo> subjects;
  final int tabIndex;
  final void Function(SubjectDemo subject) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      itemCount: subjects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = subjects[i];
        final preview = s.previewScoreForTab(tabIndex);

        return _SubjectCardGlass(
              subject: s,
              tabIndex: tabIndex,
              preview: preview,
              onTap: () => onTap(s),
            )
            .animate()
            .fadeIn(duration: 220.ms, delay: (24 * i).ms)
            .slideY(begin: 0.12, end: 0, duration: 320.ms, delay: (24 * i).ms);
      },
    );
  }
}

class _SubjectCardGlass extends StatelessWidget {
  const _SubjectCardGlass({
    required this.subject,
    required this.tabIndex,
    required this.preview,
    required this.onTap,
  });

  final SubjectDemo subject;
  final int tabIndex;
  final ScorePreview preview;
  final VoidCallback onTap;

  String _subTitle(int tab) {
    switch (tab) {
      case 0:
        return "Homework • Classwork • Project • Attendance";
      case 1:
        return "Quiz • Unit test • Midterm • Final";
      default:
        return "Overall total score";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ Saving-like glass
    final cardBg = isDark ? _o(Colors.white, .075) : Colors.white;
    final border = isDark ? _o(Colors.white, .14) : _o(Colors.black, .08);
    final textMain = isDark ? Colors.white : Colors.black87;
    final textSub = _o(textMain, .66);

    final acc = _accent(context, isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: _o(Colors.black, isDark ? .22 : .06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _Avatar(initials: subject.initials, seed: subject.seed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniChip(
                          text: subject.level,
                          bg: _o(acc, isDark ? .18 : .10),
                          fg: isDark ? Colors.white : acc,
                          border: _o(acc, isDark ? .34 : .18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subTitle(tabIndex),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressBar(
                            value: preview.percent,
                            label: preview.label,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _ScoreBadge(text: preview.scoreText, isDark: isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(LucideIcons.chevronRight, color: _o(textMain, .55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.seed});
  final String initials;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? _o(Colors.white, .14) : _o(Colors.black, .10);

    // ✅ make avatar colors more “muted” (less neon than before)
    final hue = (seed % 360).toDouble();
    final bg = HSVColor.fromAHSV(1, hue, 0.25, isDark ? 0.80 : 0.92).toColor();

    final textC = bg.computeLuminance() > 0.62
        ? _o(Colors.black, .82)
        : _o(Colors.white, .92);

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: textC,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.text,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final acc = _accent(context, isDark);
    final bg = isDark ? _o(acc, .18) : _o(acc, .10);
    final border = _o(acc, isDark ? .34 : .18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white : acc,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.label,
    required this.isDark,
  });

  final double value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black87;
    final v = value.clamp(0.0, 1.0);
    final acc = _accent(context, isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _o(fg, .72),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              "${(v * 100).round()}%",
              style: TextStyle(
                color: _o(fg, .78),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Container(color: _o(fg, .12)),
                FractionallySizedBox(
                      widthFactor: v,
                      child: Container(color: _o(acc, .90)),
                    )
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideX(begin: -0.10, end: 0, duration: 320.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// =======================================================
/// Subject Detail Page
/// =======================================================
class SubjectDetailPage extends StatefulWidget {
  const SubjectDetailPage({
    super.key,
    required this.subject,
    required this.initialTabIndex,
    required this.backgroundAsset,
  });

  final SubjectDemo subject;
  final int initialTabIndex;
  final String backgroundAsset;

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _lessonIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<ScoreItemDemo> _itemsFor(int tabIndex, int lessonIndex) {
    final seed =
        widget.subject.seed + (tabIndex + 1) * 17 + (lessonIndex + 1) * 31;
    final r = Random(seed);

    if (tabIndex == 0) {
      return [
        ScoreItemDemo("Homework", r.nextInt(10) + 1, 10),
        ScoreItemDemo("Classwork", r.nextInt(10) + 1, 10),
        ScoreItemDemo("Project", r.nextInt(20) + 1, 20),
        ScoreItemDemo("Attendance / Behavior", r.nextInt(10) + 1, 10),
      ];
    } else if (tabIndex == 1) {
      return [
        ScoreItemDemo("Quiz", r.nextInt(10) + 1, 10),
        ScoreItemDemo("Unit test", r.nextInt(15) + 1, 15),
        ScoreItemDemo("Mid-unit", r.nextInt(25) + 1, 25),
        ScoreItemDemo("End of unit test", r.nextInt(20) + 1, 20),
      ];
    } else {
      return [
        ScoreItemDemo("Continuous assessment", r.nextInt(30) + 1, 30),
        ScoreItemDemo("Midterm exam", r.nextInt(30) + 1, 30),
        ScoreItemDemo("Final exam", r.nextInt(40) + 1, 40),
      ];
    }
  }

  int _sumEarned(List<ScoreItemDemo> items) =>
      items.fold(0, (a, b) => a + b.earned);
  int _sumTotal(List<ScoreItemDemo> items) =>
      items.fold(0, (a, b) => a + b.total);

  String _tabTitle(int index) {
    switch (index) {
      case 0:
        return "Evaluation";
      case 1:
        return "Exam scores";
      default:
        return "Final score";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselected = isDark ? _o(Colors.white, .60) : _o(Colors.black87, .58);

    return AppPageTemplate(
      title: widget.subject.name,
      backgroundAsset: widget.backgroundAsset,
      showBack: true,
      scrollable: false,

      // ✅ IMPORTANT: same behavior as Saving page in dark
      premiumDark: isDark,
      premiumDarkGradient: _kSavingPremiumGradient,

      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          tabs.AppModernCountTabBar(
            controller: _tab,
            indicatorGradient: _kSavingTabIndicatorGradient,
            labelColor: Colors.white,
            unselectedLabelColor: unselected,
            items: const [
              tabs.AppTabItem(
                label: "Evaluation",
                icon: LucideIcons.clipboardCheck,
                count: null,
              ),
              tabs.AppTabItem(
                label: "Exam scores",
                icon: LucideIcons.squarePen,
                count: null,
              ),
              tabs.AppTabItem(
                label: "Final score",
                icon: LucideIcons.award,
                count: null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: List.generate(3, (tabIndex) {
                final items = _itemsFor(tabIndex, _lessonIndex);
                final earned = _sumEarned(items);
                final total = _sumTotal(items);
                final percent = total == 0 ? 0.0 : earned / total;

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _DetailHeaderCard(
                          tabTitle: _tabTitle(tabIndex),
                          lessonIndex: _lessonIndex,
                          earned: earned,
                          total: total,
                          percent: percent,
                        )
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideY(begin: 0.10, end: 0, duration: 320.ms),
                    const SizedBox(height: 12),
                    _LessonWrapChips(
                      selected: _lessonIndex,
                      onSelect: (idx) => setState(() => _lessonIndex = idx),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                          duration: 220.ms,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Column(
                            key: ValueKey("tab=$tabIndex-lesson=$_lessonIndex"),
                            children: List.generate(items.length, (i) {
                              return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i == items.length - 1 ? 2 : 12,
                                    ),
                                    child: _ScoreItemGlassCard(item: items[i]),
                                  )
                                  .animate()
                                  .fadeIn(duration: 220.ms, delay: (28 * i).ms)
                                  .slideX(
                                    begin: 0.06,
                                    end: 0,
                                    duration: 300.ms,
                                    delay: (28 * i).ms,
                                  );
                            }),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 180.ms)
                        .slideY(begin: 0.04, end: 0, duration: 220.ms),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeaderCard extends StatelessWidget {
  const _DetailHeaderCard({
    required this.tabTitle,
    required this.lessonIndex,
    required this.earned,
    required this.total,
    required this.percent,
  });

  final String tabTitle;
  final int lessonIndex;
  final int earned;
  final int total;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? _o(Colors.white, .075) : Colors.white;
    final border = isDark ? _o(Colors.white, .14) : _o(Colors.black, .08);
    final fg = isDark ? Colors.white : Colors.black87;
    final acc = _accent(context, isDark);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: _o(Colors.black, isDark ? .22 : .06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tabTitle,
            style: TextStyle(
              color: isDark ? _o(Colors.white, .86) : acc,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Lesson ${lessonIndex + 1}",
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              _ScoreBadge(text: "${(percent * 100).round()}%", isDark: isDark),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(
            value: percent,
            label: "Total $earned / $total",
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _LessonWrapChips extends StatelessWidget {
  const _LessonWrapChips({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select lesson",
          style: TextStyle(color: _o(fg, .80), fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(8, (i) {
            final isSel = i == selected;
            return _SelectChip(
                  label: "Lesson ${i + 1}",
                  selected: isSel,
                  onTap: () => onSelect(i),
                )
                .animate()
                .fadeIn(duration: 180.ms, delay: (18 * i).ms)
                .scale(
                  begin: const Offset(0.98, 0.98),
                  end: const Offset(1, 1),
                );
          }),
        ),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
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

    final acc = _accent(context, isDark);

    final bg = selected
        ? _o(acc, isDark ? .22 : .14)
        : (isDark ? _o(Colors.white, .075) : Colors.white);
    final border = selected
        ? _o(acc, isDark ? .35 : .20)
        : (isDark ? _o(Colors.white, .14) : _o(Colors.black, .08));
    final fg = selected
        ? (isDark ? Colors.white : acc)
        : (isDark ? _o(Colors.white, .86) : _o(Colors.black87, .75));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child:
            AnimatedContainer(
                  duration: 220.ms,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: border),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: _o(acc, isDark ? .18 : .12),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: 220.ms,
                        curve: Curves.easeOutCubic,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? acc : border,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                )
                .animate(target: selected ? 1 : 0)
                .shakeX(duration: 260.ms, amount: 1.4),
      ),
    );
  }
}

class _ScoreItemGlassCard extends StatelessWidget {
  const _ScoreItemGlassCard({required this.item});
  final ScoreItemDemo item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? _o(Colors.white, .075) : Colors.white;
    final border = isDark ? _o(Colors.white, .14) : _o(Colors.black, .08);
    final fg = isDark ? Colors.white : Colors.black87;

    final acc = _accent(context, isDark);
    final accStrong = _accentStrong(context, isDark);

    final p = item.total == 0
        ? 0.0
        : (item.earned / item.total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: _o(Colors.black, isDark ? .22 : .06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _o(accStrong, isDark ? .18 : .10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _o(accStrong, isDark ? .30 : .18)),
                ),
                child: Text(
                  "${item.earned} / ${item.total}",
                  style: TextStyle(
                    color: isDark ? Colors.white : accStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: _o(fg, .12)),
                  FractionallySizedBox(
                        widthFactor: p,
                        child: Container(color: _o(acc, .90)),
                      )
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .slideX(begin: -0.10, end: 0, duration: 320.ms),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Topic: ${item.title} — scored ${item.earned} out of ${item.total}",
            style: TextStyle(color: _o(fg, .72), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// Demo models
/// =======================================================
class SubjectDemo {
  final String name;
  final String level;
  final int seed;

  SubjectDemo({required this.name, required this.level, required this.seed});

  String get initials {
    final parts = name.trim().split(RegExp(r"\s+"));
    if (parts.isEmpty) return "SB";
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts[0].isNotEmpty ? parts[0][0] : "S").toUpperCase() +
        (parts[1].isNotEmpty ? parts[1][0] : "B").toUpperCase();
  }

  ScorePreview previewScoreForTab(int tabIndex) {
    final r = Random(seed + (tabIndex + 1) * 999);
    const total = 100;
    final earned = 55 + r.nextInt(45);
    final percent = earned / total;

    if (tabIndex == 0) {
      return ScorePreview(
        percent: percent,
        label: "Progress",
        scoreText: "$earned",
      );
    }
    if (tabIndex == 1) {
      return ScorePreview(
        percent: percent,
        label: "Exam",
        scoreText: "$earned",
      );
    }

    final grade = percent >= 0.85
        ? "A"
        : percent >= 0.75
        ? "B"
        : percent >= 0.65
        ? "C"
        : percent >= 0.55
        ? "D"
        : "F";

    return ScorePreview(percent: percent, label: "Overall", scoreText: grade);
  }
}

class ScorePreview {
  final double percent;
  final String label;
  final String scoreText;
  ScorePreview({
    required this.percent,
    required this.label,
    required this.scoreText,
  });
}

class ScoreItemDemo {
  final String title;
  final int earned;
  final int total;
  ScoreItemDemo(this.title, this.earned, this.total);
}

class SubjectDemoFactory {
  static List<SubjectDemo> build15() {
    final names = <String>[
      "Mathematics",
      "Physics",
      "Chemistry",
      "Biology",
      "English",
      "Lao Language",
      "Thai Language",
      "History",
      "Geography",
      "Civics",
      "Computer Science",
      "Art",
      "Music",
      "Physical Education",
      "Economics",
    ];

    final levels = <String>["M.1", "M.2", "M.3", "M.4", "M.5", "M.6"];
    final r = Random(2026);

    return List.generate(15, (i) {
      return SubjectDemo(
        name: names[i],
        level: levels[r.nextInt(levels.length)],
        seed: 1000 + i * 77 + r.nextInt(50),
      );
    });
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../../core/theme/app_colors.dart';

class CalendarPage extends StatefulWidget {
  /// ✅ optional initial focus from CalendarYear
  final int? initialYear;
  final int? initialMonth;

  const CalendarPage({super.key, this.initialYear, this.initialMonth});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _itemScrollController = ItemScrollController();
  final _positionsListener = ItemPositionsListener.create();

  late final List<DateTime> _weekStarts; // start of week (Sunday)
  late final List<DateTime> _sectionMonths; // month section for each week row
  late final int _todayIndex;
  late final int _targetIndex;

  DateTime _visibleMonth = _firstOfMonth(DateTime.now());

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    // ✅ if CalendarYear passes month/year, start there
    final targetYear = widget.initialYear ?? now.year;
    final rawMonth = widget.initialMonth ?? now.month;
    final targetMonth = rawMonth < 1 ? 1 : (rawMonth > 12 ? 12 : rawMonth);
    final anchor = DateTime(targetYear, targetMonth, 15);

    // ✅ expand range enough to always include BOTH anchor month and today
    final diffMonths =
        ((anchor.year - now.year) * 12 + (anchor.month - now.month)).abs();
    final span = diffMonths + 6; // padding
    final range = span < 18 ? 18 : span;

    _weekStarts = _buildWeekStarts(
      anchor,
      monthsBack: range,
      monthsForward: range,
    );
    _sectionMonths = _buildSectionMonths(_weekStarts);

    _todayIndex = _findTodayIndex(_weekStarts, now);
    _targetIndex =
        _findTargetMonthIndex(targetYear, targetMonth) ?? _todayIndex;

    _visibleMonth = _sectionMonths[_targetIndex];

    _positionsListener.itemPositions.addListener(_handleVisibleMonth);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ open at selected month if provided, else today
      if (widget.initialYear != null || widget.initialMonth != null) {
        _scrollToIndex(_targetIndex, jump: true);
      } else {
        _scrollToToday(jump: true);
      }
    });
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_handleVisibleMonth);
    super.dispose();
  }

  // =========================
  // Premium background
  // =========================
  LinearGradient get _premiumGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF071A3A), Color(0xFF0B2A6F), Color(0xFF1246A8)],
  );

  void _handleVisibleMonth() {
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // pick top-most visible item (smallest index that is actually visible)
    final top = positions
        .where((p) => p.itemTrailingEdge > 0)
        .reduce((a, b) => a.index < b.index ? a : b);

    final m = _sectionMonths[top.index];
    if (!_isSameMonth(m, _visibleMonth)) {
      setState(() => _visibleMonth = m);
    }
  }

  void _scrollToIndex(int index, {bool jump = false}) {
    if (!_itemScrollController.isAttached) return;
    if (jump) {
      _itemScrollController.jumpTo(index: index);
    } else {
      _itemScrollController.scrollTo(
        index: index,
        duration: 420.ms,
        curve: Curves.easeOutCubic,
      );
    }
  }

  int? _findTargetMonthIndex(int year, int month) {
    // 1) best: week that actually contains day 1 of that month
    for (int i = 0; i < _weekStarts.length; i++) {
      final d1 = _firstDayInWeekThatIsOne(_weekStarts[i]);
      if (d1 != null && d1.year == year && d1.month == month) return i;
    }

    // 2) fallback: first section index where month changes to target
    final target = DateTime(year, month, 1);
    for (int i = 0; i < _sectionMonths.length; i++) {
      final isTarget = _isSameMonth(_sectionMonths[i], target);
      final wasTarget = i > 0 && _isSameMonth(_sectionMonths[i - 1], target);
      if (isTarget && !wasTarget) return i;
    }
    return null;
  }

  void _scrollToToday({bool jump = false}) {
    if (!_itemScrollController.isAttached) return;
    if (jump) {
      _itemScrollController.jumpTo(index: _todayIndex);
    } else {
      _itemScrollController.scrollTo(
        index: _todayIndex,
        duration: 420.ms,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final monthTitle = _monthTitle(_visibleMonth, locale);
    final yearTitle = _yearTitle(_visibleMonth, locale);

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: _premiumGradient)),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================
                // Header (iPhone-like)
                // =========================
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: LucideIcons.arrowLeft,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        yearTitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.78),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: .2,
                        ),
                      ),
                      const Spacer(),
                      _GlassIconButton(
                        icon: LucideIcons.calendarDays,
                        onTap: () => _scrollToToday(jump: false),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 220.ms).slideY(begin: .08, end: 0),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: AnimatedSwitcher(
                    duration: 220.ms,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .06),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      monthTitle,
                      key: ValueKey(monthTitle),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 38,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ),

                // Weekday row (Sun..Sat like iPhone screenshot)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: _WeekdayHeader(locale: locale),
                ),

                // =========================
                // Calendar list (scroll up/down)
                // =========================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _GlassPanel(
                      child: ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _positionsListener,
                        itemCount: _weekStarts.length,
                        padding: const EdgeInsets.only(bottom: 18),
                        itemBuilder: (context, index) {
                          final weekStart = _weekStarts[index];
                          final sectionMonth = _sectionMonths[index];

                          final isMonthStartWeek = _containsDayOne(weekStart);
                          final monthLabelDate = isMonthStartWeek
                              ? _firstDayInWeekThatIsOne(weekStart)
                              : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (monthLabelDate != null)
                                _MonthDivider(
                                      text: _monthTitle(
                                        _firstOfMonth(monthLabelDate),
                                        locale,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 220.ms)
                                    .slideY(begin: .08, end: 0),

                              _WeekRow(
                                weekStart: weekStart,
                                monthContext: sectionMonth,
                              ),

                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.white.withOpacity(.10),
                              ),
                            ],
                          );
                        },
                      ).animate().fadeIn(duration: 260.ms, delay: 80.ms),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Helpers: build weeks + sections
  // =========================
  static List<DateTime> _buildWeekStarts(
    DateTime now, {
    required int monthsBack,
    required int monthsForward,
  }) {
    final startMonth = DateTime(now.year, now.month - monthsBack, 1);
    final endMonth = DateTime(now.year, now.month + monthsForward + 1, 1);

    final start = _startOfWeek(startMonth);
    final end = _startOfWeek(endMonth);

    final out = <DateTime>[];
    var cur = start;
    while (!cur.isAfter(end)) {
      out.add(cur);
      cur = cur.add(const Duration(days: 7));
    }
    return out;
  }

  static List<DateTime> _buildSectionMonths(List<DateTime> weekStarts) {
    final out = <DateTime>[];
    var current = _firstOfMonth(weekStarts.first.add(const Duration(days: 3)));

    for (final ws in weekStarts) {
      final firstOfNewMonth = _firstDayInWeekThatIsOne(ws);
      if (firstOfNewMonth != null) {
        current = _firstOfMonth(firstOfNewMonth);
      }
      out.add(current);
    }
    return out;
  }

  static int _findTodayIndex(List<DateTime> weekStarts, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < weekStarts.length; i++) {
      final ws = weekStarts[i];
      if (!_isBeforeDay(today, ws) &&
          _isBeforeDay(today, ws.add(const Duration(days: 7)))) {
        return i;
      }
    }
    return (weekStarts.length / 2).floor();
  }

  // =========================
  // Locale formatting (iPhone-like Thai support)
  // =========================
  static String _monthTitle(DateTime d, Locale locale) {
    final tag = locale.toString();
    try {
      return DateFormat('MMMM', tag).format(d);
    } catch (_) {
      return DateFormat('MMMM', 'en').format(d);
    }
  }

  static String _yearTitle(DateTime d, Locale locale) {
    // iPhone Thai shows Buddhist year (พ.ศ.)
    if (locale.languageCode.toLowerCase() == 'th') {
      return 'พ.ศ. ${d.year + 543}';
    }
    return 'ค.ศ. ${d.year}';
  }

  // =========================
  // Date utils
  // =========================
  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static DateTime _startOfWeek(DateTime d) {
    // Sunday = 7 in Dart weekday
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.weekday % 7; // Sunday->0, Mon->1 ... Sat->6
    return day.subtract(Duration(days: diff));
  }

  static bool _containsDayOne(DateTime weekStart) {
    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      if (d.day == 1) return true;
    }
    return false;
  }

  static DateTime? _firstDayInWeekThatIsOne(DateTime weekStart) {
    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      if (d.day == 1) return d;
    }
    return null;
  }

  static bool _isBeforeDay(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, a.day);
    final bb = DateTime(b.year, b.month, b.day);
    return aa.isBefore(bb);
  }
}

// =========================
// UI pieces
// =========================

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final Locale locale;
  const _WeekdayHeader({required this.locale});

  @override
  Widget build(BuildContext context) {
    // iPhone Thai month view: อา จ อ พ พฤ ศ ส
    final labels = locale.languageCode.toLowerCase() == 'th'
        ? const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: [
        for (final s in labels)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s,
                style: TextStyle(
                  color: Colors.white.withOpacity(.70),
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthDivider extends StatelessWidget {
  final String text;
  const _MonthDivider({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              thickness: 1,
              height: 1,
              color: Colors.white.withOpacity(.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final DateTime weekStart;
  final DateTime monthContext; // month section used to dim outside days

  const _WeekRow({required this.weekStart, required this.monthContext});

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _inMonth(DateTime d) =>
      d.year == monthContext.year && d.month == monthContext.month;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return SizedBox(
      height: 92,
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: _DayCell(
                  day: d,
                  isToday: _isToday(d),
                  dim: !_inMonth(d),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool dim;

  const _DayCell({required this.day, required this.isToday, required this.dim});

  @override
  Widget build(BuildContext context) {
    final numberColor = Colors.white.withOpacity(dim ? .28 : 1.0);

    final todayFill = Colors.white.withOpacity(.18);
    final todayBorder = Colors.white.withOpacity(.92);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // number (ALL WHITE) + today highlight
        if (isToday)
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: todayFill,
              border: Border.all(color: todayBorder, width: 1.8),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                  color: Colors.black.withOpacity(.18),
                ),
              ],
            ),
            child: Text(
              '${day.day}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                height: 1.0,
              ),
            ),
          )
        else
          Text(
            '${day.day}',
            style: TextStyle(
              color: numberColor, // ✅ all numbers white (dim by opacity)
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1.0,
            ),
          ),

        const Spacer(),
        const SizedBox(height: 1), // keep spacing consistent (no pills)
      ],
    );
  }
}

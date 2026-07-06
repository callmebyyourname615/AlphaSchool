import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../../core/widgets/app_page_template.dart';
import 'calendar_page.dart';

/// =======================
/// YEAR CALENDAR PAGE (TableCalendar)
///
/// ✅ Update:
/// - From MonthCalendarPage -> YearCalendarPage using custom iPhone-like zoom route
/// - Smooth zoom-in + fade + slight slide
/// =======================

enum CalendarEventType { event, task, holiday }

class CalendarEventModel {
  final String id;
  final DateTime date; // date-only
  final String title;
  final String? note;
  final CalendarEventType type;

  const CalendarEventModel({
    required this.id,
    required this.date,
    required this.title,
    this.note,
    this.type = CalendarEventType.event,
  });
}

/// ✅ iPhone-like ZoomIn Route (no plugin needed)
class ZoomInPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration dur;

  ZoomInPageRoute({
    required this.page,
    this.dur = const Duration(milliseconds: 420),
    RouteSettings? settings,
  }) : super(
         settings: settings,
         transitionDuration: dur,
         reverseTransitionDuration: const Duration(milliseconds: 320),
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curve = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );

           final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curve);
           final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
           final slide = Tween<Offset>(
             begin: const Offset(0, 0.03),
             end: Offset.zero,
           ).animate(curve);

           return FadeTransition(
             opacity: fade,
             child: SlideTransition(
               position: slide,
               child: ScaleTransition(
                 scale: scale,
                 alignment: Alignment.center,
                 child: child,
               ),
             ),
           );
         },
       );
}

class YearCalendarPage extends StatefulWidget {
  final String backgroundAsset;

  /// ✅ allow caller to open specific year/month
  final int? initialYear;
  final int? initialMonth;

  const YearCalendarPage({
    super.key,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<YearCalendarPage> createState() => _YearCalendarPageState();
}

class _YearCalendarPageState extends State<YearCalendarPage> {
  late final int _year;
  late final List<CalendarEventModel> _all;

  DateTime get _today => _onlyDate(DateTime.now());
  int? get _focusMonth => widget.initialMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = widget.initialYear ?? now.year;
    _all = _demoEventsForYear(_year);
  }

  List<CalendarEventModel> get _eventsForToday {
    final t = _today;
    final items = _all.where((e) => _sameDay(e.date, t)).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return items;
  }

  void _openMonthInCalendarPage(int month) {
    Navigator.of(context).push(
      ZoomInPageRoute(
        page: CalendarPage(initialYear: _year, initialMonth: month),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _today;

    return AppPageTemplate(
      title: 'Year Calendar',
      backgroundAsset: widget.backgroundAsset,
      animate: true,
      premiumDark: true,
      showBack: true,
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _YearHeader(
                year: _year,
                today: today,
                totalEventsToday: _eventsForToday.length,
              )
              .animate()
              .fadeIn(duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 12),
          _MonthGridPreview(
                year: _year,
                today: today,
                events: _all,
                focusMonth: _focusMonth,
                onMonthTap: _openMonthInCalendarPage,
              )
              .animate()
              .fadeIn(delay: 60.ms, duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 14),
          _SectionTitle(
                title: 'Events Today • ${_formatDateLong(today)}',
                subtitle: _eventsForToday.isEmpty
                    ? 'No events'
                    : '${_eventsForToday.length} event${_eventsForToday.length == 1 ? '' : 's'}',
              )
              .animate()
              .fadeIn(delay: 120.ms, duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 10),
          if (_eventsForToday.isEmpty)
            _EmptyEventsCard(
                  isDark: isDark,
                  hint: 'This screen is preview-only.',
                )
                .animate()
                .fadeIn(delay: 160.ms, duration: 240.ms)
                .slideY(
                  begin: .06,
                  end: 0,
                  duration: 420.ms,
                  curve: Curves.easeOutCubic,
                )
          else
            _EventsTable(isDark: isDark, rows: _eventsForToday)
                .animate()
                .fadeIn(delay: 160.ms, duration: 240.ms)
                .slideY(
                  begin: .06,
                  end: 0,
                  duration: 420.ms,
                  curve: Curves.easeOutCubic,
                ),
        ],
      ),
    );
  }

  // ===== Helpers =====
  static DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDateShort(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String _formatDateLong(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static List<CalendarEventModel> _demoEventsForYear(int year) {
    DateTime d(int m, int day) => DateTime(year, m, day);
    return [
      CalendarEventModel(
        id: 'e1',
        date: d(1, 12),
        title: 'Parent Meeting',
        note: 'Room 2A • 09:00',
        type: CalendarEventType.event,
      ),
      CalendarEventModel(
        id: 'e2',
        date: d(2, 2),
        title: 'Design Review',
        note: 'Banner drafts',
        type: CalendarEventType.task,
      ),
      CalendarEventModel(
        id: 'e3',
        date: d(3, 8),
        title: 'Sports Day',
        note: 'Bring sports uniform',
        type: CalendarEventType.event,
      ),
      CalendarEventModel(
        id: 'e4',
        date: d(4, 13),
        title: 'Holiday',
        note: 'School closed',
        type: CalendarEventType.holiday,
      ),
      CalendarEventModel(
        id: 'e5',
        date: d(6, 5),
        title: 'Vaccination Check',
        note: 'Bring health book',
        type: CalendarEventType.event,
      ),
      CalendarEventModel(
        id: 'e6',
        date: d(8, 18),
        title: 'System Maintenance',
        note: 'Firebase deploy',
        type: CalendarEventType.task,
      ),
      CalendarEventModel(
        id: 'e7',
        date: d(10, 1),
        title: 'New Term Begins',
        note: 'Welcome back!',
        type: CalendarEventType.event,
      ),
      CalendarEventModel(
        id: 'e8',
        date: d(12, 24),
        title: 'Year-End Celebration',
        note: 'Auditorium • 15:00',
        type: CalendarEventType.event,
      ),
      CalendarEventModel(
        id: 'e9',
        date: d(12, 24),
        title: 'Decoration Setup',
        note: 'Front Office',
        type: CalendarEventType.task,
      ),
    ];
  }
}

/// =======================
/// YEAR HEADER
/// =======================
class _YearHeader extends StatelessWidget {
  final int year;
  final DateTime today;
  final int totalEventsToday;

  const _YearHeader({
    required this.year,
    required this.today,
    required this.totalEventsToday,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    final titleColor = isDark ? Colors.white : Colors.black.withOpacity(.90);
    final muted = isDark ? Colors.white.withOpacity(.70) : Colors.black54;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: Row(
        children: [
          _IconBubble(icon: LucideIcons.calendarDays, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year (Preview)',
                  style: t.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today: ${_YearCalendarPageState._formatDateShort(today)} • $totalEventsToday event(s)',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HintPill(isDark: isDark),
        ],
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  final bool isDark;
  const _HintPill({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(.10) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(.12)
              : Colors.black.withOpacity(.06),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.eye,
        size: 18,
        color: isDark ? Colors.white.withOpacity(.92) : Colors.black54,
      ),
    );
  }
}

/// =======================
/// MONTH GRID PREVIEW
/// =======================
class _MonthGridPreview extends StatefulWidget {
  final int year;
  final DateTime today;
  final List<CalendarEventModel> events;
  final int? focusMonth;

  /// ✅ tap month card -> open CalendarPage
  final ValueChanged<int>? onMonthTap;

  const _MonthGridPreview({
    required this.year,
    required this.today,
    required this.events,
    this.focusMonth,
    this.onMonthTap,
  });

  @override
  State<_MonthGridPreview> createState() => _MonthGridPreviewState();
}

class _MonthGridPreviewState extends State<_MonthGridPreview> {
  late final List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(12, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = widget.focusMonth;
      if (m == null || m < 1 || m > 12) return;
      final ctx = _keys[m - 1].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: 520.ms,
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      }
    });
  }

  double _clampD(double v, double min, double max) {
    if (max < min) return min;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 900 ? 4 : 3;

        const crossSpacing = 12.0;
        const mainSpacing = 12.0;

        // ✅ iPhone-friendly: give cards a bit more height on narrow screens
        final childAspectRatio = w < 420 ? 0.74 : (w < 520 ? 0.78 : 0.82);

        final itemW = (w - crossSpacing * (cols - 1)) / cols;
        final itemH = itemW / childAspectRatio;

        const pad = 9.0;
        const headerH = 24.0;
        const weekdayH = 18.0;
        const gaps = 8.0 + 6.0;

        // ✅ prevent negative height on extreme layouts
        final usableH = math.max(
          0.0,
          itemH - (pad * 2) - headerH - weekdayH - gaps,
        );

        final rawRowH = usableH / 6.0;
        final cellW = (itemW - (pad * 2)) / 7.0;

        final base = math.max(10.0, math.min(cellW, rawRowH));
        // ✅ smaller day number (mini table)
        final dayFontSize = _clampD(base * 0.34, 7.6, 12.0);

        // ✅ IMPORTANT: TableCalendar total height = rowHeight * 6
        // Never allow rowHeight to exceed available rawRowH (fix overflow on iPhone)
        final clampedRowH = _clampD(rawRowH, 9.0, 34.0);
        final tableRowHeight = math.max(1.0, math.min(clampedRowH, rawRowH));

        return GridView.builder(
          itemCount: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: mainSpacing,
            crossAxisSpacing: crossSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final month = i + 1;
            final isFocus = widget.focusMonth == month;

            return KeyedSubtree(
              key: _keys[i],
              child:
                  Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onMonthTap == null
                              ? null
                              : () => widget.onMonthTap!(month),
                          child: _MiniMonthCardPreview(
                            year: widget.year,
                            month: month,
                            today: widget.today,
                            events: widget.events,
                            dayFontSize: dayFontSize,
                            rowHeight: tableRowHeight,
                            isFocus: isFocus,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 180.ms)
                      .scale(
                        begin: isFocus
                            ? const Offset(0.96, 0.96)
                            : const Offset(1, 1),
                        end: const Offset(1, 1),
                        duration: 420.ms,
                        curve: Curves.easeOutCubic,
                      ),
            );
          },
        );
      },
    );
  }
}

class _MiniMonthCardPreview extends StatelessWidget {
  final int year;
  final int month;
  final DateTime today;
  final List<CalendarEventModel> events;
  final double dayFontSize;
  final double rowHeight;
  final bool isFocus;

  const _MiniMonthCardPreview({
    required this.year,
    required this.month,
    required this.today,
    required this.events,
    required this.dayFontSize,
    required this.rowHeight,
    this.isFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final baseBorder = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    final focusColor = t.colorScheme.primary.withOpacity(.95);
    final border = isFocus ? focusColor : baseBorder;

    final now = DateTime.now();
    final systemToday = DateTime(now.year, now.month, now.day);

    final isCurrentMonth =
        (systemToday.year == year && systemToday.month == month);

    final headerTextColor = isCurrentMonth
        ? Colors.white
        : (isDark ? Colors.white : Colors.black.withOpacity(.88));

    final monthTitle = _monthNameShort(month);

    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final focusedDay = isCurrentMonth ? systemToday : firstDay;
    final showTodayInThisCard = isCurrentMonth;

    Widget buildCell(DateTime day) {
      final d = DateTime(day.year, day.month, day.day);
      final markToday = showTodayInThisCard && _sameDay(d, systemToday);

      return _DayCell(
        day: d.day,
        isDark: isDark,
        fontSize: dayFontSize,
        markToday: markToday,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: isFocus ? 1.8 : 1),
        boxShadow: [
          BoxShadow(blurRadius: 16, offset: const Offset(0, 10), color: shadow),
          if (isFocus)
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: focusColor.withOpacity(isDark ? .22 : .16),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
        child: Column(
          children: [
            Container(
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: isCurrentMonth
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0B2A6F),
                          Color(0xFF0A3A8A),
                          Color(0xFF0B4DB3),
                        ],
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      monthTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.labelLarge?.copyWith(
                        color: headerTextColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.1,
                        height: 1.0,
                      ),
                    ),
                  ),
                  if (isCurrentMonth)
                    const Icon(LucideIcons.star, size: 16, color: Colors.white),
                  if (isFocus && !isCurrentMonth)
                    Icon(LucideIcons.circle, size: 10, color: focusColor),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                _Wd('M'),
                _Wd('T'),
                _Wd('W'),
                _Wd('T'),
                _Wd('F'),
                _Wd('S'),
                _Wd('S'),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: IgnorePointer(
                ignoring: true,
                child: TableCalendar(
                  firstDay: firstDay,
                  lastDay: lastDay,
                  focusedDay: focusedDay,
                  calendarFormat: CalendarFormat.month,
                  headerVisible: false,
                  daysOfWeekVisible: false,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableGestures: AvailableGestures.none,
                  sixWeekMonthsEnforced: true,
                  rowHeight: rowHeight,
                  eventLoader: (_) => const [],
                  enabledDayPredicate: (day) =>
                      day.month == month && day.year == year,
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    isTodayHighlighted: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, _) => buildCell(day),
                    todayBuilder: (context, day, _) => buildCell(day),
                    outsideBuilder: (context, day, _) =>
                        const SizedBox.shrink(),
                    disabledBuilder: (context, day, _) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _monthNameShort(int m) {
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
    return months[m - 1];
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isDark;
  final double fontSize;
  final bool markToday;

  const _DayCell({
    required this.day,
    required this.isDark,
    required this.fontSize,
    required this.markToday,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? Colors.white.withOpacity(.92)
        : Colors.black.withOpacity(.82);

    // ✅ Year grid: don't "mark" current day (no border/fill), only show red text.
    final textColor = markToday
        ? (isDark ? Colors.redAccent.withOpacity(.95) : Colors.red)
        : fg;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.0),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _Wd extends StatelessWidget {
  final String text;
  const _Wd(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final muted = isDark ? Colors.white.withOpacity(.70) : Colors.black54;

    return Expanded(
      child: Center(
        child: Text(
          text,
          style: t.textTheme.bodySmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// =======================
/// MONTH CALENDAR PAGE (interactive)
/// ✅ PickMonth -> zoom-in to YearCalendarPage
/// =======================
class MonthCalendarPage extends StatefulWidget {
  final int year;
  final int month;
  final List<CalendarEventModel> events;
  final String backgroundAsset;

  const MonthCalendarPage({
    super.key,
    required this.year,
    required this.month,
    required this.events,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<MonthCalendarPage> createState() => _MonthCalendarPageState();
}

class _MonthCalendarPageState extends State<MonthCalendarPage> {
  late DateTime _focused;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _focused = DateTime(widget.year, widget.month, 1);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (today.year == widget.year && today.month == widget.month) {
      _selected = today;
    } else {
      _selected = _focused;
    }
  }

  Future<void> _pickMonthAndGoYearPage() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        final t = Theme.of(ctx);
        final isDark = t.brightness == Brightness.dark;

        final cardBg = isDark ? Colors.white.withOpacity(.08) : Colors.white;
        final border = isDark
            ? Colors.white.withOpacity(.10)
            : Colors.black.withOpacity(.06);

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

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pick Month',
                          style: t.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    itemCount: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                    itemBuilder: (ctx2, i) {
                      final m = i + 1;
                      final isCurrent = m == widget.month;

                      final tileBg = isCurrent
                          ? t.colorScheme.primary.withOpacity(
                              isDark ? .22 : .14,
                            )
                          : (isDark
                                ? Colors.white.withOpacity(.06)
                                : const Color(0xFFF3F4F6));
                      final tileBorder = isCurrent
                          ? t.colorScheme.primary.withOpacity(.65)
                          : (isDark
                                ? Colors.white.withOpacity(.10)
                                : Colors.black.withOpacity(.06));

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(ctx, m),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: tileBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            months[i],
                            style: t.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked == null) return;

    // ✅ iPhone-like zoom transition (replace current page)
    Navigator.of(context).pushReplacement(
      ZoomInPageRoute(
        page: YearCalendarPage(
          initialYear: widget.year,
          initialMonth: picked,
          backgroundAsset: widget.backgroundAsset,
        ),
      ),
    );
  }

  List<CalendarEventModel> get _eventsForSelected {
    final d = _selected;
    final items = widget.events.where((e) => _sameDay(e.date, d)).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = '${_monthNameLong(widget.month)} ${widget.year}';
    final firstDay = DateTime(widget.year, widget.month, 1);
    final lastDay = DateTime(widget.year, widget.month + 1, 0);

    return AppPageTemplate(
      title: title,
      backgroundAsset: widget.backgroundAsset,
      animate: true,
      premiumDark: true,
      showBack: true,
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthHeaderCard(
                title: title,
                selected: _selected,
                onPickMonth: _pickMonthAndGoYearPage,
              )
              .animate()
              .fadeIn(duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 12),
          _MonthCalendarCard(
                isDark: isDark,
                firstDay: firstDay,
                lastDay: lastDay,
                focused: _focused,
                selected: _selected,
                onPick: (selected, focused) {
                  setState(() {
                    _selected = selected;
                    _focused = focused;
                  });
                },
              )
              .animate()
              .fadeIn(delay: 60.ms, duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 14),
          _SectionTitle(
                title: 'Events on ${_formatDateLong(_selected)}',
                subtitle: _eventsForSelected.isEmpty
                    ? 'No events'
                    : '${_eventsForSelected.length} event${_eventsForSelected.length == 1 ? '' : 's'}',
              )
              .animate()
              .fadeIn(delay: 120.ms, duration: 220.ms)
              .slideY(
                begin: .05,
                end: 0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 10),
          if (_eventsForSelected.isEmpty)
            _EmptyEventsCard(
                  isDark: isDark,
                  hint: 'Tap a day above to see events.',
                )
                .animate()
                .fadeIn(delay: 160.ms, duration: 240.ms)
                .slideY(
                  begin: .06,
                  end: 0,
                  duration: 420.ms,
                  curve: Curves.easeOutCubic,
                )
          else
            _EventsTable(isDark: isDark, rows: _eventsForSelected)
                .animate()
                .fadeIn(delay: 160.ms, duration: 240.ms)
                .slideY(
                  begin: .06,
                  end: 0,
                  duration: 420.ms,
                  curve: Curves.easeOutCubic,
                ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDateLong(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _monthNameLong(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m - 1];
  }
}

class _MonthHeaderCard extends StatelessWidget {
  final String title;
  final DateTime selected;
  final VoidCallback onPickMonth;

  const _MonthHeaderCard({
    required this.title,
    required this.selected,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    final titleColor = isDark ? Colors.white : Colors.black.withOpacity(.90);
    final muted = isDark ? Colors.white.withOpacity(.70) : Colors.black54;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B2A6F), Color(0xFF0B4DB3)],
              ),
            ),
            child: const Icon(LucideIcons.calendarDays, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selected: ${selected.day}/${selected.month}/${selected.year}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPickMonth,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(.10)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(.12)
                      : Colors.black.withOpacity(.06),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.calendarDays,
                size: 18,
                color: isDark ? Colors.white.withOpacity(.92) : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendarCard extends StatelessWidget {
  final bool isDark;
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focused;
  final DateTime selected;
  final void Function(DateTime selected, DateTime focused) onPick;

  const _MonthCalendarCard({
    required this.isDark,
    required this.firstDay,
    required this.lastDay,
    required this.focused,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    const blue = Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: TableCalendar(
        firstDay: firstDay,
        lastDay: lastDay,
        focusedDay: focused,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
        ),
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.horizontalSwipe,
        sixWeekMonthsEnforced: true,
        rowHeight: 44,
        eventLoader: (_) => const [],
        selectedDayPredicate: (day) => isSameDay(day, selected),
        onDaySelected: (sel, foc) =>
            onPick(DateTime(sel.year, sel.month, sel.day), foc),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          markerSize: 0,
          defaultTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            color: isDark
                ? Colors.white.withOpacity(.92)
                : Colors.black.withOpacity(.82),
          ),
          weekendTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            color: isDark
                ? Colors.white.withOpacity(.92)
                : Colors.black.withOpacity(.82),
          ),
          todayTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            color: isDark ? Colors.redAccent.withOpacity(.95) : Colors.red,
          ),
          selectedTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            color: isDark
                ? Colors.white.withOpacity(.92)
                : Colors.black.withOpacity(.82),
          ),
          isTodayHighlighted: true,
          todayDecoration: BoxDecoration(
            // ✅ no "current day" marker (no fill/border) — only red text via todayTextStyle
            borderRadius: BorderRadius.circular(12),
          ),
          selectedDecoration: BoxDecoration(
            color: blue.withOpacity(isDark ? .26 : .18),
            border: Border.all(color: blue.withOpacity(.95), width: 1.9),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// SECTION TITLE / EMPTY / TABLE (unchanged)
/// =======================
class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: t.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withOpacity(.72)
                      : t.colorScheme.onSurface.withOpacity(.70),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            LucideIcons.listChecks,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _EmptyEventsCard extends StatelessWidget {
  final bool isDark;
  final String hint;

  const _EmptyEventsCard({required this.isDark, required this.hint});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.calendarX,
            size: 44,
            color: isDark ? Colors.white.withOpacity(.86) : Colors.black54,
          ),
          const SizedBox(height: 10),
          Text(
            'No events',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: t.colorScheme.onSurface.withOpacity(.70),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsTable extends StatelessWidget {
  final bool isDark;
  final List<CalendarEventModel> rows;

  const _EventsTable({required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? Colors.white.withOpacity(.06) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .40 : .10);

    final headBg = isDark
        ? Colors.white.withOpacity(.08)
        : const Color(0xFFF3F4F6);
    final textColor = isDark
        ? Colors.white.withOpacity(.92)
        : Colors.black.withOpacity(.86);
    final muted = isDark ? Colors.white.withOpacity(.68) : Colors.black54;

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
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: headBg,
            child: Row(
              children: [
                _Th(text: 'Type', flex: 2, color: muted),
                const SizedBox(width: 10),
                _Th(text: 'Title', flex: 5, color: muted),
                const SizedBox(width: 10),
                _Th(text: 'Note', flex: 6, color: muted),
              ],
            ),
          ),
          for (int i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(.08)
                        : Colors.black.withOpacity(.06),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _TypePill(type: rows[i].type, isDark: isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: Text(
                      (rows[i].note ?? '-'),
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.6,
                        height: 1.2,
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
}

class _Th extends StatelessWidget {
  final String text;
  final int flex;
  final Color color;

  const _Th({required this.text, required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12.2,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final CalendarEventType type;
  final bool isDark;

  const _TypePill({required this.type, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = _typeColor(type);
    final label = _typeText(type);
    final icon = _typeIcon(type);

    final bg = isDark ? Colors.white.withOpacity(.10) : c.withOpacity(.10);
    final border = isDark ? Colors.white.withOpacity(.12) : c.withOpacity(.22);
    final fg = isDark ? Colors.white.withOpacity(.92) : c;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .15,
            ),
          ),
        ],
      ),
    );
  }

  static Color _typeColor(CalendarEventType t) {
    switch (t) {
      case CalendarEventType.event:
        return const Color(0xFF3B82F6);
      case CalendarEventType.task:
        return const Color(0xFFF59E0B);
      case CalendarEventType.holiday:
        return const Color(0xFF22C55E);
    }
  }

  static String _typeText(CalendarEventType t) {
    switch (t) {
      case CalendarEventType.event:
        return 'Event';
      case CalendarEventType.task:
        return 'Task';
      case CalendarEventType.holiday:
        return 'Holiday';
    }
  }

  static IconData _typeIcon(CalendarEventType t) {
    switch (t) {
      case CalendarEventType.event:
        return LucideIcons.calendarDays;
      case CalendarEventType.task:
        return LucideIcons.circleCheck;
      case CalendarEventType.holiday:
        return LucideIcons.partyPopper;
    }
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final bool isDark;

  const _IconBubble({required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withOpacity(.10) : const Color(0xFFF3F4F6),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(.12)
              : Colors.black.withOpacity(.06),
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white.withOpacity(.92) : Colors.black54,
        ),
      ),
    );
  }
}

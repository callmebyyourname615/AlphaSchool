import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_page_template.dart';

enum AppointmentStatus { pending, confirmed, postponed, cancelled }

class AppointmentModel {
  final String id;
  final String title;
  final String? note;

  DateTime date; // day of appointment
  TimeOfDay start;
  TimeOfDay end;

  AppointmentStatus status;

  AppointmentModel({
    required this.id,
    required this.title,
    this.note,
    required this.date,
    required this.start,
    required this.end,
    this.status = AppointmentStatus.pending,
  });
}

class AppointmentPage extends StatefulWidget {
  final String backgroundAsset;

  const AppointmentPage({
    super.key,
    this.backgroundAsset = 'assets/images/homepagewall/mainbg.jpeg',
  });

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth; // first day of current visible month
  late List<AppointmentModel> _all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = _onlyDate(now);
    _visibleMonth = DateTime(now.year, now.month, 1);
    _all = _demoAppointments(_selectedDate);
  }

  // ✅ avoid mouse_tracker assertion on desktop/web: schedule setState after frame
  void _safeSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  List<AppointmentModel> get _filtered {
    return _all.where((a) => _sameDay(a.date, _selectedDate)).toList()
      ..sort((a, b) => _toMinutes(a.start).compareTo(_toMinutes(b.start)));
  }

  /// ✅ Mark ทุกวันที่มี appointment
  Set<DateTime> get _markedDays {
    final s = <DateTime>{};
    for (final a in _all) {
      s.add(_onlyDate(a.date));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
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
              final t = Theme.of(context);
              final isDark = t.brightness == Brightness.dark;
              final cs = t.colorScheme;

              final headerMuted = isDark
                  ? Colors.white.withOpacity(.72)
                  : cs.onSurface.withOpacity(.70);

              return AppPageTemplate(
                title: 'ນັດໝາຍ',
                backgroundAsset: widget.backgroundAsset,
                animate: true,
                showBack: true,
                scrollable: true,
                premiumDark: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MarkedCalendarCard(
                          visibleMonth: _visibleMonth,
                          selectedDate: _selectedDate,
                          markedDays: _markedDays,
                          onPrevMonth: () {
                            _safeSetState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month - 1,
                                1,
                              );
                            });
                          },
                          onNextMonth: () {
                            _safeSetState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month + 1,
                                1,
                              );
                            });
                          },
                          onPickDate: (d) {
                            _safeSetState(() {
                              _selectedDate = _onlyDate(d);
                              _visibleMonth = DateTime(d.year, d.month, 1);
                            });
                          },
                        )
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideY(
                          begin: .06,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 14),
                    _SectionHeader(
                          title: _formatDateLong(_selectedDate),
                          subtitle:
                              '${_filtered.length} appointment${_filtered.length == 1 ? '' : 's'}',
                          mutedColor: headerMuted,
                        )
                        .animate()
                        .fadeIn(delay: 80.ms, duration: 220.ms)
                        .slideY(
                          begin: .05,
                          end: 0,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 10),
                    if (_filtered.isEmpty)
                      _EmptyState(onAddDemo: _addOneDemo)
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 240.ms)
                          .slideY(
                            begin: .06,
                            end: 0,
                            duration: 420.ms,
                            curve: Curves.easeOutCubic,
                          )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < _filtered.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child:
                                  _AppointmentCard(
                                        appt: _filtered[i],
                                        onConfirm: () => _confirm(_filtered[i]),
                                        onPostpone: () =>
                                            _postpone(_filtered[i]),
                                        onCancel: () => _cancel(_filtered[i]),
                                      )
                                      .animate()
                                      .fadeIn(
                                        delay: (120 + i * 60).ms,
                                        duration: 240.ms,
                                      )
                                      .slideY(
                                        begin: .06,
                                        end: 0,
                                        duration: 420.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                            ),
                        ],
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

  // ===== Actions =====

  void _confirm(AppointmentModel a) {
    if (a.status == AppointmentStatus.cancelled) return;
    setState(() => a.status = AppointmentStatus.confirmed);
    _toast('Confirmed');
  }

  void _postpone(AppointmentModel a) {
    if (a.status == AppointmentStatus.cancelled) return;
    setState(() {
      a.status = AppointmentStatus.postponed;
      a.date = _onlyDate(a.date.add(const Duration(days: 1)));
    });
    _toast('Postponed to ${_formatDateShort(a.date)}');
  }

  void _cancel(AppointmentModel a) {
    setState(() => a.status = AppointmentStatus.cancelled);
    _toast('Cancelled');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _addOneDemo() {
    final d = _selectedDate;
    setState(() {
      _all.add(
        AppointmentModel(
          id: 'new_${DateTime.now().millisecondsSinceEpoch}',
          title: 'New Appointment',
          note: 'Tap Confirm / Postpone / Cancel',
          date: d,
          start: const TimeOfDay(hour: 10, minute: 0),
          end: const TimeOfDay(hour: 10, minute: 30),
        ),
      );
    });
  }

  // ===== Helpers =====

  static DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

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

  static List<AppointmentModel> _demoAppointments(DateTime baseDay) {
    final d0 = _onlyDate(baseDay);
    final d1 = _onlyDate(baseDay.add(const Duration(days: 1)));
    final d2 = _onlyDate(baseDay.add(const Duration(days: 3)));

    return [
      AppointmentModel(
        id: 'a1',
        title: 'Parent Meeting',
        note: 'Class teacher • Room 2A',
        date: d0,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 9, minute: 30),
        status: AppointmentStatus.pending,
      ),
      AppointmentModel(
        id: 'a2',
        title: 'Vaccination Check',
        note: 'Bring student health book',
        date: d0,
        start: const TimeOfDay(hour: 13, minute: 30),
        end: const TimeOfDay(hour: 14, minute: 0),
        status: AppointmentStatus.confirmed,
      ),
      AppointmentModel(
        id: 'a3',
        title: 'Sports Practice',
        note: 'Basketball court',
        date: d1,
        start: const TimeOfDay(hour: 16, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 0),
        status: AppointmentStatus.postponed,
      ),
      AppointmentModel(
        id: 'a4',
        title: 'Make-up Session',
        note: 'Front office',
        date: d2,
        start: const TimeOfDay(hour: 11, minute: 0),
        end: const TimeOfDay(hour: 11, minute: 20),
        status: AppointmentStatus.pending,
      ),
    ];
  }
}

// ================= CALENDAR (WITH MARKS) =================

class _MarkedCalendarCard extends StatelessWidget {
  final DateTime visibleMonth; // first day of month
  final DateTime selectedDate;

  /// ✅ วันไหนมี appointment จะอยู่ใน set นี้
  final Set<DateTime> markedDays;

  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onPickDate;

  const _MarkedCalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.markedDays,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final Gradient premiumPanelGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF0B2B5B).withOpacity(.78),
        const Color(0xFF071A33).withOpacity(.88),
        const Color(0xFF060B16).withOpacity(.92),
      ],
    );

    final cardBg = isDark ? null : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .45 : .10);

    final headerText = isDark ? Colors.white : Colors.black.withOpacity(.85);
    final muted = isDark ? Colors.white.withOpacity(.72) : Colors.black54;

    final year = visibleMonth.year;
    final month = visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final firstWeekday = DateTime(year, month, 1).weekday; // Mon=1..Sun=7
    final offset = (firstWeekday + 6) % 7;

    final totalCells = offset + daysInMonth;
    final rows = ((totalCells + 6) ~/ 7).clamp(5, 6);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    const markRed = Color(0xFFEF4444);
    const selectedBlue = Color(0xFF3B82F6);

    String monthName(int m) {
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

    final weekdayLabels = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    Widget content = Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: onPrevMonth,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 40,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(.10)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(.12)
                        : Colors.black.withOpacity(.06),
                  ),
                ),
                child: Icon(Icons.chevron_left_rounded, color: headerText),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${monthName(month)} $year',
                    style: t.textTheme.titleMedium?.copyWith(
                      color: headerText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onNextMonth,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 40,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(.10)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(.12)
                        : Colors.black.withOpacity(.06),
                  ),
                ),
                child: Icon(Icons.chevron_right_rounded, color: headerText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final w in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            const mainAxisSpacing = 6.0;
            const crossAxisSpacing = 6.0;
            const childAspectRatio = 1.12;

            final w = c.maxWidth;
            final cellW = (w - crossAxisSpacing * 6) / 7.0;
            final cellH = cellW / childAspectRatio;
            final gridH = rows * cellH + (rows - 1) * mainAxisSpacing;

            return SizedBox(
              height: gridH,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: mainAxisSpacing,
                  crossAxisSpacing: crossAxisSpacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, i) {
                  final day = i - offset + 1;
                  if (day < 1 || day > daysInMonth) return const SizedBox();

                  final date = DateTime(year, month, day);
                  final isSelected = _sameDay(date, selectedDate);
                  final isToday = _sameDay(date, todayDate);

                  final hasAppt = markedDays.contains(
                    DateTime(date.year, date.month, date.day),
                  );

                  final textColor = isDark
                      ? Colors.white
                      : Colors.black.withOpacity(.85);

                  final markBg = hasAppt
                      ? markRed.withOpacity(isDark ? .18 : .10)
                      : Colors.transparent;

                  final markBorder = hasAppt
                      ? markRed.withOpacity(isDark ? .70 : .45)
                      : Colors.transparent;

                  final bg = isSelected
                      ? selectedBlue.withOpacity(isDark ? .26 : .18)
                      : (hasAppt ? markBg : Colors.transparent);

                  final borderColor = isSelected
                      ? selectedBlue.withOpacity(isDark ? .75 : .55)
                      : (hasAppt
                            ? markBorder
                            : (isToday
                                  ? (isDark
                                        ? Colors.white.withOpacity(.55)
                                        : Colors.black.withOpacity(.25))
                                  : Colors.transparent));

                  return Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => onPickDate(date),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected ? 1.4 : 1.0,
                          ),
                          boxShadow: hasAppt && !isSelected
                              ? [
                                  BoxShadow(
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                    color: markRed.withOpacity(
                                      isDark ? .18 : .10,
                                    ),
                                  ),
                                ]
                              : null,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );

    content = content
        .animate(key: ValueKey('${visibleMonth.year}-${visibleMonth.month}'))
        .fadeIn(duration: 220.ms)
        .slideY(begin: .03, end: 0, duration: 260.ms, curve: Curves.easeOut);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        gradient: isDark ? premiumPanelGrad : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: content,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ================= LIST UI =================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color mutedColor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final titleColor = isDark
        ? Colors.white.withOpacity(.94)
        : t.colorScheme.onSurface;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.titleMedium?.copyWith(
                  color: titleColor, // ✅ FIX: ensure visible in dark
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: t.textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
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
            Icons.event_available_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appt;
  final VoidCallback onConfirm;
  final VoidCallback onPostpone;
  final VoidCallback onCancel;

  const _AppointmentCard({
    required this.appt,
    required this.onConfirm,
    required this.onPostpone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xFF071A33).withOpacity(.32)
        : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .45 : .10);

    // ✅ FIX: make sure all text uses visible color in dark
    final onText = isDark ? Colors.white.withOpacity(.94) : cs.onSurface;
    final onMuted = isDark
        ? Colors.white.withOpacity(.72)
        : cs.onSurface.withOpacity(.70);
    final onSoft = isDark
        ? Colors.white.withOpacity(.78)
        : cs.onSurface.withOpacity(.75);

    const accent = Color(0xFF3B82F6);

    const statusGreen = Color(0xFF22C55E);
    const statusYellow = Color(0xFFF59E0B);
    const statusRed = Color(0xFFEF4444);

    Color statusColor;
    if (appt.status == AppointmentStatus.confirmed) {
      statusColor = statusGreen;
    } else if (appt.status == AppointmentStatus.pending) {
      statusColor = statusYellow;
    } else if (appt.status == AppointmentStatus.cancelled) {
      statusColor = statusRed;
    } else {
      statusColor = statusYellow;
    }

    final timeText =
        '${_AppointmentPageState._formatTime(appt.start)} - ${_AppointmentPageState._formatTime(appt.end)}';

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
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accent.withOpacity(isDark ? .70 : .85),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconBubble(
                          icon: Icons.schedule_rounded,
                          color: accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appt.title,
                                style: t.textTheme.titleMedium?.copyWith(
                                  color: onText, // ✅ FIX
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: onSoft.withOpacity(.85), // ✅ FIX
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _AppointmentPageState._formatDateShort(
                                      appt.date,
                                    ),
                                    style: t.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: onSoft, // ✅ FIX
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: onSoft.withOpacity(.85), // ✅ FIX
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeText,
                                    style: t.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: onSoft, // ✅ FIX
                                    ),
                                  ),
                                ],
                              ),
                              if ((appt.note ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  appt.note!.trim(),
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: onMuted, // ✅ FIX
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusPill(
                          label: appt.status.name.toUpperCase(),
                          color: statusColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'ຍອມຮັບ',
                            icon: Icons.check_rounded,
                            accent: const Color(0xFF22C55E),
                            onTap: appt.status == AppointmentStatus.cancelled
                                ? null
                                : onConfirm,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            label: 'ເລື່ອນນັດໝາຍ',
                            icon: Icons.update_rounded,
                            accent: const Color(0xFFF59E0B),
                            onTap: appt.status == AppointmentStatus.cancelled
                                ? null
                                : onPostpone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            label: 'ຍົກເລີກ',
                            icon: Icons.close_rounded,
                            accent: const Color(0xFFEF4444),
                            onTap: appt.status == AppointmentStatus.cancelled
                                ? null
                                : onCancel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      child: Center(child: Icon(icon, size: 20, color: color)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(.10) : color.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(.12)
              : color.withOpacity(.25),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white.withOpacity(.92) : color,
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;

    final bg = accent.withOpacity(disabled ? .08 : .12);
    final border = accent.withOpacity(.22);

    final fg = disabled
        ? (isDark
              ? Colors.white.withOpacity(.35)
              : Colors.black.withOpacity(.35))
        : accent;

    return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(.98, .98),
          end: const Offset(1, 1),
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddDemo;

  const _EmptyState({required this.onAddDemo});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF071A33).withOpacity(.28) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(.12)
        : Colors.black.withOpacity(.06);
    final shadow = Colors.black.withOpacity(isDark ? .45 : .10);

    // ✅ FIX: ensure visible in dark
    final titleColor = isDark
        ? Colors.white.withOpacity(.94)
        : t.colorScheme.onSurface;
    final bodyColor = isDark
        ? Colors.white.withOpacity(.72)
        : t.colorScheme.onSurface.withOpacity(.70);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: shadow),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 42,
            color: isDark
                ? Colors.white.withOpacity(.85)
                : Colors.black.withOpacity(.70),
          ),
          const SizedBox(height: 10),
          Text(
            'ບໍ່ມີລາຍການນັດໝາຍໃນມື້ນີ້',
            style: t.textTheme.titleMedium?.copyWith(
              color: titleColor, // ✅ FIX
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ເລືອກມື້ທີ່ມີນັດໝາຍໂດຍສັງເກດຈາກປຸ່ມສີແເດງໃນປະຕິທິນ.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: bodyColor, // ✅ FIX
            ),
          ),
          const SizedBox(height: 12),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onAddDemo,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: isDark
                          ? Colors.white.withOpacity(.90)
                          : Colors.black.withOpacity(.75),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add demo',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white.withOpacity(.92)
                            : Colors.black.withOpacity(.75),
                      ),
                    ),
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

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/services/global_alert_service.dart';
import '../../../../../core/services/session_service.dart';
import 'appointment_model.dart';
import 'appointment_service.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1E2D5B);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF5F7FA);
const _kCardBg = Colors.white;
const _kBorder = Color(0xFFE8ECF0);
const _kMuted = Color(0xFF9CA3AF);
const _kText = Color(0xFF1F2937);

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
  late DateTime _visibleMonth;
  late List<AppointmentModel> _all;
  final _svc = AppointmentService();
  SharedPreferences? _prefs;
  String _sessionUserId = '';

  static const _prefKey = 'appt_reschedule_counts';

  bool _loading = true;
  String? _error;
  AppointmentStatus? _filterStatus;
  Set<DateTime> _markedDates = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = _date(now);
    _visibleMonth = DateTime(now.year, now.month);
    _all = [];
    _loadSessionUserId();
    _load();
  }

  Future<void> _loadSessionUserId() async {
    final session = await SessionService().load();
    if (mounted && session != null) {
      setState(() => _sessionUserId = session.id);
    }
  }

  // ── local reschedule-count store ─────────────────────────────────────────────
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<int> _localCount(String id) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return 0;
    final map = Map<String, dynamic>.from(
      raw.split(',').where((e) => e.contains(':')).fold(<String, dynamic>{}, (
        m,
        e,
      ) {
        final parts = e.split(':');
        if (parts.length == 2) m[parts[0]] = int.tryParse(parts[1]) ?? 0;
        return m;
      }),
    );
    return (map[id] as int?) ?? 0;
  }

  Future<void> _saveCount(String id, int count) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_prefKey) ?? '';
    final map = Map<String, int>.from(
      raw.split(',').where((e) => e.contains(':')).fold(<String, int>{}, (
        m,
        e,
      ) {
        final parts = e.split(':');
        if (parts.length == 2) m[parts[0]] = int.tryParse(parts[1]) ?? 0;
        return m;
      }),
    );
    map[id] = count;
    await prefs.setString(
      _prefKey,
      map.entries.map((e) => '${e.key}:${e.value}').join(','),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.fetchAppointments();
      // Merge with locally persisted counts — take the higher value
      final prefs = await _getPrefs();
      final raw = prefs.getString(_prefKey) ?? '';
      final localMap = Map<String, int>.from(
        raw.split(',').where((e) => e.contains(':')).fold(<String, int>{}, (
          m,
          e,
        ) {
          final parts = e.split(':');
          if (parts.length == 2) m[parts[0]] = int.tryParse(parts[1]) ?? 0;
          return m;
        }),
      );
      for (final appt in list) {
        final stored = localMap[appt.id] ?? 0;
        if (stored > appt.rescheduleCount) {
          appt.rescheduleCount = stored;
        }
      }
      if (!mounted) return;
      setState(() {
        _all = list;
        _markedDates = {for (final a in list) _date(a.date)};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load appointments';
        _loading = false;
      });
    }
  }

  List<AppointmentModel> get _filtered {
    var list = _forDay(_selectedDate);
    if (_filterStatus != null) {
      list = list.where((a) => a.status == _filterStatus).toList();
    }
    list.sort((a, b) => _mins(a.start).compareTo(_mins(b.start)));
    return list;
  }

  List<AppointmentModel> _forDay(DateTime d) =>
      _all.where((a) => _same(a.date, d)).toList();

  // ── actions ─────────────────────────────────────────────────────────────
  void _confirm(AppointmentModel a) {
    if (a.status == AppointmentStatus.cancelled) return;
    GlobalAlert.showConfirmation(
      title: 'Confirm Appointment',
      message: 'Confirm "${a.title}" scheduled on ${_shortDate(a.date)}?',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
      icon: LucideIcons.circleCheck,
    ).then((confirmed) {
      if (confirmed != true) return;
      GlobalAlert.showLoading(message: 'Confirming...');
      _svc
          .confirmAppointment(a)
          .then((_) {
            GlobalAlert.dismiss();
            if (!mounted) return;
            setState(() => a.status = AppointmentStatus.confirmed);
            GlobalAlert.showSuccess(
              title: 'Confirmed!',
              message: 'The appointment has been confirmed successfully.',
            );
          })
          .catchError((_) {
            GlobalAlert.dismiss();
            GlobalAlert.showError(
              title: 'Failed',
              message: 'Could not confirm the appointment. Please try again.',
            );
          });
    });
  }

  void _reschedule(AppointmentModel a) {
    if (a.status == AppointmentStatus.cancelled) return;
    showModalBottomSheet<(DateTime, TimeOfDay, TimeOfDay)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RescheduleSheet(appt: a),
    ).then((result) {
      if (result == null) return;
      final (newDate, newStart, newEnd) = result;
      final dateStr = _shortDate(newDate);
      GlobalAlert.showConfirmation(
        title: 'Confirm Reschedule',
        message: 'Move "${a.title}" to $dateStr?',
        confirmText: 'Reschedule',
        cancelText: 'Cancel',
        icon: LucideIcons.calendarDays,
      ).then((confirmed) {
        if (confirmed != true || !mounted) return;
        GlobalAlert.showLoading(message: 'Rescheduling...');
        _svc
            .rescheduleAppointment(a, newDate, newStart, newEnd)
            .then((_) {
              GlobalAlert.dismiss();
              if (!mounted) return;
              final newCount = a.rescheduleCount + 1;
              setState(() {
                a.status = AppointmentStatus.postponed;
                a.date = newDate;
                a.start = newStart;
                a.end = newEnd;
                a.rescheduleCount = newCount;
                _selectedDate = _date(newDate);
                _visibleMonth = DateTime(newDate.year, newDate.month);
              });
              _saveCount(a.id, newCount);
              GlobalAlert.showSuccess(
                title: 'Rescheduled!',
                message: 'Appointment has been moved to $dateStr.',
              );
            })
            .catchError((_) {
              GlobalAlert.dismiss();
              GlobalAlert.showError(
                title: 'Failed',
                message:
                    'Could not reschedule the appointment. Please try again.',
              );
            });
      });
    });
  }

  void _cancel(AppointmentModel a) {
    final isOwner = _sessionUserId.isNotEmpty && a.createdBy == _sessionUserId;
    GlobalAlert.showConfirmation(
      title: isOwner ? 'Delete Appointment' : 'Decline Appointment',
      message: isOwner ? 'Delete "${a.title}"?' : 'Decline "${a.title}"?',
      confirmText: isOwner ? 'Delete' : 'Decline',
      cancelText: 'Keep',
      icon: isOwner ? LucideIcons.trash2 : LucideIcons.circleX,
      confirmColor: _kRed,
    ).then((confirmed) {
      if (confirmed != true) return;
      GlobalAlert.showLoading(
        message: isOwner ? 'Deleting...' : 'Declining...',
      );
      final request = isOwner
          ? _svc.deleteAppointment(a)
          : _svc.declineAppointment(a);
      request
          .then((_) {
            GlobalAlert.dismiss();
            if (!mounted) return;
            if (isOwner) {
              setState(() {
                _all.removeWhere((item) => item.id == a.id);
                _markedDates = {for (final item in _all) _date(item.date)};
              });
              _snack('Appointment deleted');
            } else {
              setState(() => a.status = AppointmentStatus.cancelled);
              _snack('Appointment declined');
            }
          })
          .catchError((_) {
            GlobalAlert.dismiss();
            GlobalAlert.showError(
              title: 'Failed',
              message: isOwner
                  ? 'Could not delete the appointment. Please try again.'
                  : 'Could not decline the appointment. Please try again.',
            );
          });
    });
  }

  void _timeline(AppointmentModel a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimelineSheet(appt: a),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }

  // ── filter sheet ────────────────────────────────────────────────────────
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _filterStatus,
        onSelect: (s) {
          setState(() => _filterStatus = s);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── add appointment sheet ────────────────────────────────────────────────
  Future<void> _showAddSheet() async {
    final result = await showModalBottomSheet<AppointmentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAppointmentSheet(initialDate: _selectedDate),
    );
    if (result == null || !mounted) return;
    GlobalAlert.showLoading(message: 'Saving appointment...');
    try {
      await _svc.createAppointment(result);
      GlobalAlert.dismiss();
      if (!mounted) return;
      _selectedDate = _date(result.date);
      _visibleMonth = DateTime(result.date.year, result.date.month);
      await _load();
      GlobalAlert.showSuccess(
        title: 'Appointment Created',
        message: 'The appointment has been saved successfully.',
      );
    } catch (_) {
      GlobalAlert.dismiss();
      GlobalAlert.showError(
        title: 'Failed',
        message: 'Could not save the appointment. Please try again.',
      );
    }
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(
              onBack: () => Navigator.maybePop(context),
              onAdd: _showAddSheet,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CalendarCard(
                          visibleMonth: _visibleMonth,
                          selectedDate: _selectedDate,
                          marked: _markedDates,
                          onPrev: () => setState(
                            () => _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                            ),
                          ),
                          onNext: () => setState(
                            () => _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            ),
                          ),
                          onPick: (d) => setState(() {
                            _selectedDate = _date(d);
                            _visibleMonth = DateTime(d.year, d.month);
                          }),
                        )
                        .animate()
                        .fadeIn(duration: 240.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 380.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      count: _filtered.length,
                      activeFilter: _filterStatus,
                      onFilter: _showFilterSheet,
                    ).animate().fadeIn(delay: 60.ms, duration: 220.ms),
                    const SizedBox(height: 12),
                    if (_loading)
                      const _LoadCard().animate().fadeIn(
                        delay: 100.ms,
                        duration: 220.ms,
                      )
                    else if (_error != null)
                      _ErrorCard(
                        message: _error!,
                        onRetry: _load,
                      ).animate().fadeIn(delay: 100.ms, duration: 220.ms)
                    else ...[
                      for (int i = 0; i < _filtered.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              _ApptCard(
                                    appt: _filtered[i],
                                    isOwner:
                                        _sessionUserId.isNotEmpty &&
                                        _filtered[i].createdBy ==
                                            _sessionUserId,
                                    onConfirm: () => _confirm(_filtered[i]),
                                    onReschedule: () =>
                                        _reschedule(_filtered[i]),
                                    onCancel: () => _cancel(_filtered[i]),
                                    onTimeline: () => _timeline(_filtered[i]),
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: 100 + i * 60),
                                    duration: 240.ms,
                                  )
                                  .slideY(
                                    begin: .04,
                                    end: 0,
                                    duration: 360.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                        ),
                      if (_filtered.isEmpty)
                        _NoMoreCard().animate().fadeIn(
                          delay: 100.ms,
                          duration: 240.ms,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static int _mins(TimeOfDay t) => t.hour * 60 + t.minute;
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _shortDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String formatTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String formatCardDate(DateTime d) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
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
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }
}

// ── Page Header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAdd;
  const _PageHeader({required this.onBack, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(LucideIcons.arrowLeft, size: 20, color: _kNavy),
            splashRadius: 22,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Schedule & Appointments',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: .35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.plus,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar Card ────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Set<DateTime> marked;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPick;

  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.marked,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  static const _wdLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthNames = [
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

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final year = visibleMonth.year;
    final month = visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWd = DateTime(year, month, 1).weekday; // Mon=1..Sun=7
    final offset = firstWd % 7; // Sun=0, Mon=1, ..., Sat=6

    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child:
          Column(
                children: [
                  // ── Month nav ──
                  Row(
                    children: [
                      _NavBtn(icon: LucideIcons.chevronLeft, onTap: onPrev),
                      Expanded(
                        child: Text(
                          '${_monthNames[month - 1]} $year',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: _kNavy,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                      _NavBtn(icon: LucideIcons.chevronRight, onTap: onNext),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Weekday labels ──
                  Row(
                    children: [
                      for (final w in _wdLabels)
                        Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kMuted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Day grid ──
                  _buildGrid(year, month, daysInMonth, offset, todayD),
                ],
              )
              .animate(key: ValueKey('$year-$month'))
              .fadeIn(duration: 200.ms)
              .slideY(begin: .02, end: 0, duration: 240.ms),
    );
  }

  Widget _buildGrid(
    int year,
    int month,
    int daysInMonth,
    int offset,
    DateTime todayD,
  ) {
    final cells = <Widget>[];

    // Leading empty cells (previous month)
    final prevMonthDays = DateTime(year, month, 0).day;
    for (int i = 0; i < offset; i++) {
      final day = prevMonthDays - offset + i + 1;
      cells.add(_DayCell(day: day, faded: true, onTap: null));
    }

    // Current month days
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final isToday = _same(date, todayD);
      final isSelected = _same(date, selectedDate);
      cells.add(
        _DayCell(
          day: d,
          isSelected: isSelected,
          isToday: isToday,
          hasMark: marked.contains(DateTime(date.year, date.month, date.day)),
          onTap: () => onPick(date),
        ),
      );
    }

    // Trailing empty cells (next month)
    final total = cells.length;
    final rows = ((total + 6) ~/ 7);
    final trailing = rows * 7 - total;
    for (int i = 1; i <= trailing; i++) {
      cells.add(_DayCell(day: i, faded: true, onTap: null));
    }

    return Column(
      children: [
        for (int r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r < rows - 1 ? 4 : 0),
            child: Row(
              children: [
                for (int c = 0; c < 7; c++) Expanded(child: cells[r * 7 + c]),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder),
          color: Colors.white,
        ),
        child: Icon(icon, size: 20, color: _kNavy),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool faded;
  final bool isSelected;
  final bool isToday;
  final bool hasMark;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    this.faded = false,
    this.isSelected = false,
    this.isToday = false,
    this.hasMark = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color? bgColor;
    final Border? ring;

    if (faded) {
      textColor = _kMuted.withValues(alpha: .45);
      bgColor = null;
      ring = null;
    } else if (isSelected) {
      textColor = Colors.white;
      bgColor = _kBlue;
      ring = null;
    } else if (isToday) {
      textColor = _kBlue;
      bgColor = null;
      ring = Border.all(color: _kBlue, width: 1.5);
    } else if (hasMark) {
      textColor = _kOrange;
      bgColor = _kOrange.withValues(alpha: .12);
      ring = null;
    } else {
      textColor = _kText;
      bgColor = null;
      ring = null;
    }

    final showBadge = hasMark && !isSelected && !faded;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Day circle
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: ring,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected || isToday || hasMark
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                // Badge dot — top-right corner
                if (showBadge)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
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

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int count;
  final AppointmentStatus? activeFilter;
  final VoidCallback onFilter;
  const _SectionHeader({
    required this.count,
    required this.activeFilter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = activeFilter != null;
    return Row(
      children: [
        const Text(
          'Appointments',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kNavy,
            letterSpacing: -.2,
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              _statusLabel(activeFilter!),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onFilter,
          child: Row(
            children: [
              Icon(
                LucideIcons.slidersHorizontal,
                size: 18,
                color: hasFilter ? _kNavy : _kBlue,
              ),
              const SizedBox(width: 4),
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: hasFilter ? _kNavy : _kBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _statusLabel(AppointmentStatus s) => switch (s) {
    AppointmentStatus.confirmed => 'Confirmed',
    AppointmentStatus.cancelled => 'Cancelled',
    AppointmentStatus.postponed => 'Postponed',
    AppointmentStatus.pending => 'Pending',
  };
}

// ── Appointment Card ─────────────────────────────────────────────────────────

class _ApptCard extends StatelessWidget {
  final AppointmentModel appt;
  final bool isOwner;
  final VoidCallback onConfirm;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;
  final VoidCallback onTimeline;

  const _ApptCard({
    required this.appt,
    required this.isOwner,
    required this.onConfirm,
    required this.onReschedule,
    required this.onCancel,
    required this.onTimeline,
  });

  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('meet') || t.contains('parent') || t.contains('teacher')) {
      return LucideIcons.users;
    }
    if (t.contains('vacc') ||
        t.contains('health') ||
        t.contains('medical') ||
        t.contains('nurse') ||
        t.contains('doctor')) {
      return LucideIcons.syringe;
    }
    if (t.contains('sport') || t.contains('activity')) {
      return LucideIcons.circle;
    }
    return LucideIcons.notebookPen;
  }

  static Color _iconBg(String title) {
    final t = title.toLowerCase();
    if (t.contains('meet') || t.contains('parent') || t.contains('teacher')) {
      return const Color(0xFFEEF2FF);
    }
    if (t.contains('vacc') ||
        t.contains('health') ||
        t.contains('medical') ||
        t.contains('nurse') ||
        t.contains('doctor')) {
      return const Color(0xFFECFDF5);
    }
    return const Color(0xFFEFF6FF);
  }

  static Color _iconColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('meet') || t.contains('parent') || t.contains('teacher')) {
      return const Color(0xFF6366F1);
    }
    if (t.contains('vacc') ||
        t.contains('health') ||
        t.contains('medical') ||
        t.contains('nurse') ||
        t.contains('doctor')) {
      return _kGreen;
    }
    return _kBlue;
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = appt.status == AppointmentStatus.confirmed;
    final isCancelled = appt.status == AppointmentStatus.cancelled;
    final isPostponed = appt.status == AppointmentStatus.postponed;

    Color statusColor;
    String statusLabel;
    if (isConfirmed) {
      statusColor = _kGreen;
      statusLabel = 'Confirmed';
    } else if (isCancelled) {
      statusColor = _kRed;
      statusLabel = 'Cancelled';
    } else if (isPostponed) {
      statusColor = _kOrange;
      statusLabel = 'Postponed';
    } else {
      statusColor = _kOrange;
      statusLabel = 'Pending';
    }

    final timeStr =
        '${_AppointmentPageState.formatTime(appt.start)} - ${_AppointmentPageState.formatTime(appt.end)}';
    final dateStr = _AppointmentPageState.formatCardDate(appt.date);
    final location = (appt.note ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top row: icon + info + status ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _iconBg(appt.title),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(appt.title),
                  size: 22,
                  color: _iconColor(appt.title),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        letterSpacing: -.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/icons/Calendar.png',
                          width: 13,
                          height: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '|',
                            style: TextStyle(color: _kMuted, fontSize: 12),
                          ),
                        ),
                        const Icon(LucideIcons.clock, size: 13, color: _kMuted),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 13,
                            color: _kMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTimeline,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBlue.withValues(alpha: .18)),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.ganttChart, size: 16, color: _kBlue),
                  const SizedBox(width: 7),
                  const Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: _kBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Action buttons ──
          Row(
            children: [
              // Confirm — disabled after first confirm
              Expanded(
                child: _ActionBtn(
                  label: isConfirmed ? 'Confirmed' : 'Confirm',
                  icon: LucideIcons.check,
                  filled: !isConfirmed,
                  color: isConfirmed ? _kGreen : _kNavy,
                  disabled: isCancelled || isConfirmed,
                  onTap: (isCancelled || isConfirmed) ? null : onConfirm,
                ),
              ),
              const SizedBox(width: 8),
              // Reschedule — disabled after 3 times, shows remaining badge
              Expanded(
                child: _RescheduleBtn(
                  remaining: appt.rescheduleRemaining,
                  disabled: isCancelled || !appt.canReschedule,
                  onTap: (isCancelled || !appt.canReschedule)
                      ? null
                      : onReschedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: isOwner ? 'Delete' : 'Cancel',
                  icon: isOwner ? LucideIcons.trash2 : LucideIcons.x,
                  filled: isOwner,
                  color: isOwner ? _kRed : _kText,
                  disabled: isCancelled,
                  onTap: isCancelled ? null : onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineSheet extends StatelessWidget {
  final AppointmentModel appt;

  const _TimelineSheet({required this.appt});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;
    final events = _events();
    return Container(
      height: MediaQuery.of(context).size.height * .82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, safe + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: const Center(
                  child: Icon(LucideIcons.ganttChart, size: 18, color: _kBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity timeline',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _kNavy,
                      ),
                    ),
                    Text(
                      appt.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${events.length} update${events.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _kMuted,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: Text(
                      'No timeline activity yet.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: events.length,
                    itemBuilder: (_, index) =>
                        _TimelineEventRow(
                              event: events[index],
                              isLast: index == events.length - 1,
                            )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 35 * index),
                              duration: 220.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: .06,
                              end: 0,
                              delay: Duration(milliseconds: 35 * index),
                              duration: 260.ms,
                              curve: Curves.easeOutCubic,
                            ),
                  ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEvent> _events() {
    final events = <_TimelineEvent>[];
    final createdAt = appt.createdAt;
    final rescheduledAt = appt.rescheduledAt ?? appt.updatedAt ?? createdAt;
    final originalDate = appt.originalDate ?? appt.date;
    final originalStart = appt.originalStart ?? appt.start;
    final originalEnd = appt.originalEnd ?? appt.end;
    final creatorName = appt.createdByName.isNotEmpty
        ? appt.createdByName
        : appt.createdBy;

    events.add(
      _TimelineEvent(
        title: 'Appointment record created',
        variant: _TimelineVariant.created,
        time: createdAt,
        actor: creatorName.isEmpty ? null : creatorName,
        badge: 'Created',
        details: [
          if (creatorName.isNotEmpty) 'Created by $creatorName',
          if (appt.title.isNotEmpty) 'Title: ${appt.title}',
        ],
      ),
    );

    events.add(
      _TimelineEvent(
        title: 'Schedule recorded',
        variant: _TimelineVariant.scheduled,
        time: createdAt,
        badge: _fmtDate(originalDate),
        details: [
          'Date: ${_fmtDate(originalDate)}',
          'Time: ${_fmtTime(originalStart)} - ${_fmtTime(originalEnd)}',
          if ((appt.note ?? '').trim().isNotEmpty)
            'Location: ${(appt.note ?? '').trim()}',
        ],
      ),
    );

    for (final person in appt.participants) {
      events.add(
        _TimelineEvent(
          title: 'Participant invited',
          variant: _TimelineVariant.invited,
          actor: person.name,
          badge: person.roleLabel,
          time: person.createdAt ?? createdAt,
          details: [
            '${person.name} added as participant',
            'Type: ${person.personType}',
            'Initial status: PENDING',
          ],
        ),
      );

      if (person.responseHistory.isNotEmpty) {
        for (final history in person.responseHistory) {
          final event = _responseEvent(person, history);
          if (event != null) events.add(event);
        }
      } else if (person.respondedAt != null) {
        final event = _responseEvent(
          person,
          ParticipantResponseHistoryModel(
            status: person.status,
            eventAt: person.respondedAt,
            note: person.responseNote,
            rescheduleCount: person.rescheduleCount,
          ),
        );
        if (event != null) events.add(event);
      }
    }

    final hasReschedule =
        appt.rescheduledAt != null ||
        appt.previousRescheduledDate != null ||
        appt.status == AppointmentStatus.postponed;
    if (hasReschedule) {
      final previousDate = appt.previousRescheduledDate ?? originalDate;
      final previousStart = appt.previousRescheduledStart ?? originalStart;
      final previousEnd = appt.previousRescheduledEnd ?? originalEnd;
      events.add(
        _TimelineEvent(
          title: 'Appointment rescheduled',
          variant: _TimelineVariant.scheduled,
          time: rescheduledAt,
          badge: _fmtDate(appt.date),
          details: [
            'New schedule: ${_fmtDate(appt.date)} · ${_fmtTime(appt.start)} - ${_fmtTime(appt.end)}',
            'Previous: ${_fmtDate(previousDate)} · ${_fmtTime(previousStart)} - ${_fmtTime(previousEnd)}',
          ],
        ),
      );

      for (final person in appt.participants) {
        events.add(
          _TimelineEvent(
            title: 'Participant notified of new schedule',
            variant: _TimelineVariant.invited,
            actor: person.name,
            badge: person.roleLabel,
            time: rescheduledAt,
            details: [
              'New schedule shared with ${person.name}',
              '${_fmtDate(appt.date)} · ${_fmtTime(appt.start)} - ${_fmtTime(appt.end)}',
            ],
          ),
        );
      }
    }

    events.sort((a, b) {
      final at = a.time?.millisecondsSinceEpoch;
      final bt = b.time?.millisecondsSinceEpoch;
      if (at != null && bt != null && at != bt) return bt.compareTo(at);
      if (at != null && bt == null) return -1;
      if (at == null && bt != null) return 1;
      return a.priority.compareTo(b.priority);
    });
    return events;
  }

  _TimelineEvent? _responseEvent(
    AppointmentParticipantModel person,
    ParticipantResponseHistoryModel history,
  ) {
    final status = history.status.toUpperCase();
    if (!const [
      'ACCEPTED',
      'CONFIRMED',
      'DECLINED',
      'CANCELLED',
      'RESCHEDULED',
    ].contains(status)) {
      return null;
    }
    final declined = status == 'DECLINED' || status == 'CANCELLED';
    final rescheduled = status == 'RESCHEDULED';
    return _TimelineEvent(
      title: rescheduled
          ? 'Reschedule requested'
          : declined
          ? 'Participant declined'
          : 'Participant accepted',
      variant: rescheduled
          ? _TimelineVariant.reschedule
          : declined
          ? _TimelineVariant.declined
          : _TimelineVariant.accepted,
      actor: person.name,
      badge: person.roleLabel,
      time: history.eventAt ?? person.respondedAt,
      details: [
        rescheduled
            ? 'Requested a different schedule'
            : 'Response changed to $status',
        'By ${person.name}',
        if (rescheduled &&
            (history.proposedDate != null ||
                history.proposedStart != null ||
                history.proposedEnd != null))
          'Proposed: ${history.proposedDate == null ? '—' : _fmtDate(history.proposedDate!)} · ${history.proposedStart == null ? '—' : _fmtTime(history.proposedStart!)} - ${history.proposedEnd == null ? '—' : _fmtTime(history.proposedEnd!)}',
        if (rescheduled)
          'Attempts: ${history.rescheduleCount}/${AppointmentModel.maxReschedule}',
        if (history.note.isNotEmpty) history.note,
      ],
    );
  }

  static String _fmtTime(TimeOfDay t) => _AppointmentPageState.formatTime(t);
  static String _fmtDate(DateTime d) => _AppointmentPageState.formatCardDate(d);
}

enum _TimelineVariant {
  created,
  scheduled,
  invited,
  accepted,
  declined,
  reschedule,
  updated,
}

class _TimelineEvent {
  final String title;
  final _TimelineVariant variant;
  final String? actor;
  final String? badge;
  final DateTime? time;
  final List<String> details;

  const _TimelineEvent({
    required this.title,
    required this.variant,
    this.actor,
    this.badge,
    this.time,
    this.details = const [],
  });

  int get priority => switch (variant) {
    _TimelineVariant.accepted || _TimelineVariant.declined => 0,
    _TimelineVariant.invited => 1,
    _TimelineVariant.updated => 2,
    _TimelineVariant.created => 3,
    _TimelineVariant.scheduled => 4,
    _TimelineVariant.reschedule => 5,
  };
}

class _TimelineEventRow extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;

  const _TimelineEventRow({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = _color(event.variant);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _icon(event.variant),
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: color.withValues(alpha: .16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _surface(event.variant),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border(event.variant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w900,
                              color: _kText,
                              letterSpacing: -.1,
                            ),
                          ),
                        ),
                        if (event.badge != null)
                          _TimelinePill(label: event.badge!, color: color),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(_icon(event.variant), size: 13, color: color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            [
                              _timeLabel(event.time),
                              if (event.actor != null) event.actor!,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.6,
                              fontWeight: FontWeight.w700,
                              color: _kMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.details.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: event.details.take(3).map((detail) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _detailSurface(event.variant),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _border(event.variant),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: .72,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        _detailIcon(detail),
                                        size: 12,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        detail,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.32,
                                          fontWeight: FontWeight.w600,
                                          color: _kText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (event.details.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${event.details.length - 3} more detail${event.details.length - 3 == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime? value) {
    if (value == null) return 'Time not recorded';
    final local = value.toLocal();
    final date = _AppointmentPageState.formatCardDate(local);
    final time = _AppointmentPageState.formatTime(
      TimeOfDay(hour: local.hour, minute: local.minute),
    );
    return '$date · $time';
  }

  static IconData _icon(_TimelineVariant variant) => switch (variant) {
    _TimelineVariant.accepted => LucideIcons.check,
    _TimelineVariant.declined => LucideIcons.x,
    _TimelineVariant.reschedule => LucideIcons.refreshCw,
    _TimelineVariant.created => LucideIcons.fileText,
    _TimelineVariant.scheduled => LucideIcons.calendarDays,
    _TimelineVariant.invited => LucideIcons.clock3,
    _TimelineVariant.updated => LucideIcons.squarePen,
  };

  static Color _color(_TimelineVariant variant) => switch (variant) {
    _TimelineVariant.accepted => _kGreen,
    _TimelineVariant.declined => _kRed,
    _TimelineVariant.reschedule => const Color(0xFFEC4899),
    _TimelineVariant.created => _kNavy,
    _TimelineVariant.scheduled => _kBlue,
    _TimelineVariant.invited => _kOrange,
    _TimelineVariant.updated => const Color(0xFF6366F1),
  };

  static Color _surface(_TimelineVariant variant) => switch (variant) {
    _TimelineVariant.accepted => const Color(0xFFF0FDF4),
    _TimelineVariant.declined => const Color(0xFFFEF2F2),
    _TimelineVariant.reschedule => const Color(0xFFFDF2F8),
    _TimelineVariant.created => const Color(0xFFF8FAFC),
    _TimelineVariant.scheduled => const Color(0xFFEFF6FF),
    _TimelineVariant.invited => const Color(0xFFFFFBEB),
    _TimelineVariant.updated => const Color(0xFFF5F3FF),
  };

  static Color _detailSurface(_TimelineVariant variant) =>
      Colors.white.withValues(alpha: .62);

  static Color _border(_TimelineVariant variant) =>
      _color(variant).withValues(alpha: .18);

  static IconData _detailIcon(String detail) {
    final text = detail.toLowerCase();
    if (text.contains('accepted') || text.contains('changed to')) {
      return LucideIcons.check;
    }
    if (text.contains('declined') || text.contains('cancelled')) {
      return LucideIcons.x;
    }
    if (text.contains('schedule') ||
        text.contains('date') ||
        text.contains('time') ||
        text.contains('proposed')) {
      return LucideIcons.clock;
    }
    if (text.contains('location')) return LucideIcons.mapPin;
    if (text.contains('created') ||
        text.contains('participant') ||
        text.contains(' by ')) {
      return LucideIcons.user;
    }
    return LucideIcons.circle;
  }
}

class _TimelinePill extends StatelessWidget {
  final String label;
  final Color color;

  const _TimelinePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.2,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ── Reschedule button with remaining-count badge ──────────────────────────────

class _RescheduleBtn extends StatelessWidget {
  final int remaining;
  final bool disabled;
  final VoidCallback? onTap;

  const _RescheduleBtn({
    required this.remaining,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? _kMuted.withValues(alpha: .5) : _kText;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.calendarDays,
                    size: 13,
                    color: effectiveColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Reschedule',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: effectiveColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Remaining count badge — top-right
            Positioned(
              top: -6,
              right: -6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: disabled ? _kMuted : _kOrange,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$remaining',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: .1,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget? iconOverride;
  final bool filled;
  final Color color;
  final bool disabled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    this.iconOverride,
    required this.filled,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? _kMuted.withValues(alpha: .5) : color;
    final bg = filled
        ? (disabled ? _kMuted.withValues(alpha: .1) : color)
        : Colors.transparent;
    final border = filled
        ? Colors.transparent
        : (disabled ? _kBorder : _kBorder);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconOverride ??
                Icon(
                  icon,
                  size: 14,
                  color: filled
                      ? (disabled ? _kMuted : Colors.white)
                      : effectiveColor,
                ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: filled
                      ? (disabled ? _kMuted : Colors.white)
                      : effectiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── No More Card ─────────────────────────────────────────────────────────────

class _NoMoreCard extends StatelessWidget {
  const _NoMoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEDFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/icons/Calendar.png',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No more appointments today',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Enjoy your day! You're all caught up.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
          ),
          _CalendarIllustration(),
        ],
      ),
    );
  }
}

class _CalendarIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(LucideIcons.smile, size: 18, color: _kBlue),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.check,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error & Loading cards ─────────────────────────────────────────────────────

class _LoadCard extends StatelessWidget {
  const _LoadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
          ),
          const SizedBox(width: 12),
          const Text(
            'Loading appointments...',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.cloudOff, size: 36, color: _kMuted),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _kText),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.refreshCw, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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

// ── Filter Sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final AppointmentStatus? current;
  final ValueChanged<AppointmentStatus?> onSelect;

  const _FilterSheet({required this.current, required this.onSelect});

  static const _options = <String, AppointmentStatus?>{
    'All': null,
    'Pending': AppointmentStatus.pending,
    'Confirmed': AppointmentStatus.confirmed,
    'Postponed': AppointmentStatus.postponed,
    'Cancelled': AppointmentStatus.cancelled,
  };

  static const _dotColors = <AppointmentStatus, Color>{
    AppointmentStatus.pending: _kOrange,
    AppointmentStatus.confirmed: _kGreen,
    AppointmentStatus.postponed: _kOrange,
    AppointmentStatus.cancelled: _kRed,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Filter by status',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kNavy,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in _options.entries)
            _FilterOption(
              label: entry.key,
              dotColor: entry.value != null ? _dotColors[entry.value!] : _kBlue,
              isSelected: current == entry.value,
              onTap: () => onSelect(entry.value),
            ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final Color? dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.label,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _kBlue.withValues(alpha: .07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kBlue : _kBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor ?? _kBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? _kBlue : _kText,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(LucideIcons.circleCheck, size: 18, color: _kBlue),
          ],
        ),
      ),
    );
  }
}

// ── Add Appointment Sheet ─────────────────────────────────────────────────────

class _AddAppointmentSheet extends StatefulWidget {
  final DateTime initialDate;
  const _AddAppointmentSheet({required this.initialDate});

  @override
  State<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends State<_AddAppointmentSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _svc = AppointmentService();

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;
  bool _employeeError = false;

  List<AdminModel> _admins = [];
  List<AdminModel> _selectedAdmins = [];
  List<ParentInviteModel> _parents = [];
  List<ParentInviteModel> _selectedParents = [];
  List<StudentInviteModel> _students = [];
  Map<String, AppointmentConflict> _employeeConflicts = {};
  Map<String, AppointmentConflict> _parentConflicts = {};
  bool _loadingAdmins = true;
  bool _loadingInvitees = true;
  String _currentUserId = '';
  String _currentParentId = '';

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _start = const TimeOfDay(hour: 9, minute: 0);
    _end = const TimeOfDay(hour: 10, minute: 0);
    _loadCurrentUser();
    _fetchAdmins();
    _fetchInvitees();
  }

  Future<void> _loadCurrentUser() async {
    final session = await SessionService().load();
    if (!mounted) return;
    final userId = session?.id.trim() ?? '';
    setState(() {
      _currentUserId = userId;
      _currentParentId = _parents.any((p) => p.id == userId) ? userId : '';
    });
    await _refreshConflicts();
  }

  Future<void> _fetchAdmins() async {
    try {
      final list = await _svc.fetchAdmins();
      if (!mounted) return;
      setState(() {
        _admins = list;
        _loadingAdmins = false;
      });
      await _refreshConflicts();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAdmins = false);
    }
  }

  Future<void> _fetchInvitees() async {
    try {
      final results = await Future.wait([
        _svc.fetchParents(),
        _svc.fetchStudents(),
      ]);
      if (!mounted) return;
      setState(() {
        _parents = results[0] as List<ParentInviteModel>;
        _students = results[1] as List<StudentInviteModel>;
        _currentParentId = _parents.any((p) => p.id == _currentUserId)
            ? _currentUserId
            : '';
        _loadingInvitees = false;
      });
      await _refreshConflicts();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInvitees = false);
    }
  }

  Future<void> _refreshConflicts() async {
    if (_admins.isEmpty && _parents.isEmpty) return;
    try {
      final employeeIds = _admins
          .map((a) => a.id)
          .where((id) => id.isNotEmpty)
          .toList();
      final parentIds = _parents
          .map((p) => p.id)
          .followedBy(
            _currentParentId.isEmpty ? const <String>[] : [_currentParentId],
          )
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final results = await Future.wait([
        _svc.checkConflicts(
          date: _date,
          start: _start,
          end: _end,
          personIds: employeeIds,
        ),
        _svc.checkConflicts(
          date: _date,
          start: _start,
          end: _end,
          personIds: parentIds,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _employeeConflicts = results[0];
        _parentConflicts = results[1];
        _selectedAdmins = _selectedAdmins
            .where((a) => !_employeeConflicts.containsKey(a.id))
            .toList();
        _selectedParents = _selectedParents
            .where((p) => !_parentConflicts.containsKey(p.id))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employeeConflicts = {};
        _parentConflicts = {};
      });
    }
  }

  Future<void> _pickEmployees() async {
    final result = await showModalBottomSheet<List<AdminModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminPickerSheet(
        admins: _admins,
        selected: _selectedAdmins,
        conflicts: _employeeConflicts,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedAdmins = result;
        if (result.isNotEmpty) _employeeError = false;
      });
    }
  }

  Future<void> _pickParents() async {
    await _refreshConflicts();
    if (!mounted) return;
    final result = await showModalBottomSheet<List<ParentInviteModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParentInviteSheet(
        parents: _parents,
        students: _students,
        selected: _selectedParents,
        conflicts: _parentConflicts,
        loading: _loadingInvitees,
        hiddenParentId: _currentParentId,
      ),
    );
    if (result != null) {
      setState(() => _selectedParents = result);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) {
    const mo = [
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
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  String _fmtTime(TimeOfDay t) => '${_fmt2(t.hour)}:${_fmt2(t.minute)}';
  int _toMins(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _kBlue)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _refreshConflicts();
    }
  }

  Future<TimeOfDay?> _showScrollPicker(TimeOfDay initial) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScrollTimePickerSheet(initial: initial),
    );
  }

  Future<void> pickStartAt() async {
    final picked = await _showScrollPicker(_start);
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked;
      if (!_isAfter(_end, _start)) _end = _addHour(_start);
    });
    await _refreshConflicts();
  }

  Future<void> pickEndAt() async {
    final picked = await _showScrollPicker(_end);
    if (picked == null || !mounted) return;
    if (!_isAfter(picked, _start)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _end = picked);
    await _refreshConflicts();
  }

  bool _isAfter(TimeOfDay end, TimeOfDay start) =>
      _toMins(end) > _toMins(start);

  TimeOfDay _addHour(TimeOfDay t) {
    final total = _toMins(t) + 60;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedAdmins.isEmpty) {
      setState(() => _employeeError = true);
      return;
    }

    await _refreshConflicts();
    final blockedEmployees = _selectedAdmins
        .where((admin) => _employeeConflicts.containsKey(admin.id))
        .map((admin) => admin.name)
        .toList();
    final blockedParents = _selectedParents
        .where((parent) => _parentConflicts.containsKey(parent.id))
        .map((parent) => parent.name)
        .toList();
    final currentUserConflict = _currentParentId.isNotEmpty
        ? _parentConflicts[_currentParentId]
        : null;
    if (blockedEmployees.isNotEmpty ||
        blockedParents.isNotEmpty ||
        currentUserConflict != null) {
      GlobalAlert.showError(
        title: 'Time Conflict',
        message:
            'Some invitees are already booked at this time.\n${[...blockedEmployees, ...blockedParents, if (currentUserConflict != null) 'You (${currentUserConflict.timeLabel})'].join(', ')}',
      );
      return;
    }

    final autoParentIds = {
      if (_currentParentId.isNotEmpty) _currentParentId,
      ..._selectedParents.map((p) => p.id),
    }.where((id) => id.isNotEmpty).toList();

    final empLabel = _selectedAdmins.isEmpty
        ? 'No employees selected'
        : '${_selectedAdmins.length} employee${_selectedAdmins.length > 1 ? 's' : ''} selected';
    final parentLabel = autoParentIds.isEmpty
        ? 'No parents invited'
        : '${autoParentIds.length} parent${autoParentIds.length > 1 ? 's' : ''} invited';

    final confirmed = await GlobalAlert.showConfirmation(
      title: 'Create Appointment',
      message:
          '"$title"\n${_fmtDate(_date)} · ${_fmtTime(_start)} – ${_fmtTime(_end)}\n$empLabel\n$parentLabel',
      confirmText: 'Create',
      cancelText: 'Back',
      icon: LucideIcons.notebookPen,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final model = AppointmentModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      date: DateTime(_date.year, _date.month, _date.day),
      start: _start,
      end: _end,
      status: AppointmentStatus.pending,
      participantIds: _selectedAdmins.map((a) => a.id).toList(),
      participantTypes: {
        for (final admin in _selectedAdmins)
          admin.id: _personTypeForAdmin(admin),
      },
      parentIds: autoParentIds,
      branchId: _selectedAdmins
          .map((admin) => admin.branchId)
          .firstWhere((id) => id.isNotEmpty, orElse: () => ''),
    );
    Navigator.pop(context, model);
  }

  String _personTypeForAdmin(AdminModel admin) {
    final normalized = admin.role.toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    if (normalized.contains('teacher')) return 'TEACHER';
    if (normalized.contains('supersuperadmin')) return 'SUPER_SUPER_ADMIN';
    if (normalized.contains('superadmin') || normalized.contains('super')) {
      return 'SUPER_ADMIN';
    }
    return 'ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'New Appointment',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                    letterSpacing: -.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(LucideIcons.x, color: _kMuted, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            _FieldLabel(label: 'Title'),
            const SizedBox(height: 6),
            _TextField(
              controller: _titleCtrl,
              hint: 'e.g. Parent–Teacher Meeting',
            ),
            const SizedBox(height: 14),

            // Date
            _FieldLabel(label: 'Date'),
            const SizedBox(height: 6),
            _PickerTile(
              icon: LucideIcons.calendarDays,
              iconOverride: Image.asset(
                'assets/images/icons/Calendar.png',
                width: 16,
                height: 16,
              ),
              label: _fmtDate(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),

            // Time row
            Row(
              children: [
                Expanded(
                  child: _TimeCard(
                    label: 'Start At',
                    value: _fmtTime(_start),
                    icon: LucideIcons.clock,
                    onTap: pickStartAt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeCard(
                    label: 'End At',
                    value: _fmtTime(_end),
                    icon: LucideIcons.timer,
                    onTap: pickEndAt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Meeting place
            _FieldLabel(label: 'Meetings Place (optional)'),
            const SizedBox(height: 6),
            _TextField(
              controller: _noteCtrl,
              hint: 'Add a meeting place...',
              maxLines: 2,
            ),
            const SizedBox(height: 14),

            // Invite parents
            _FieldLabel(label: 'Invite Parents (optional)'),
            const SizedBox(height: 6),
            _ParentInviteTile(
              selected: _selectedParents,
              loading: _loadingInvitees,
              onTap: _loadingInvitees ? null : _pickParents,
            ),
            const SizedBox(height: 14),

            // Employee / Participants
            _FieldLabel(label: 'Employees *', error: _employeeError),
            const SizedBox(height: 6),
            _EmployeeTile(
              selected: _selectedAdmins,
              loading: _loadingAdmins,
              hasError: _employeeError,
              onTap: _admins.isEmpty && !_loadingAdmins ? null : _pickEmployees,
            ),
            if (_employeeError)
              const Padding(
                padding: EdgeInsets.only(top: 5, left: 2),
                child: Text(
                  'Please select at least one employee',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _kRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Save button
            GestureDetector(
              onTap: _saving ? null : _submit,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _saving ? _kMuted : _kNavy,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Appointment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool error;
  const _FieldLabel({required this.label, this.error = false});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: error ? _kRed : _kMuted,
    ),
  );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: _kText,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBlue, width: 1.5),
        ),
      ),
    );
  }
}

// ── Employee tile (dropdown trigger) ─────────────────────────────────────────

class _EmployeeTile extends StatelessWidget {
  final List<AdminModel> selected;
  final bool loading;
  final bool hasError;
  final VoidCallback? onTap;

  const _EmployeeTile({
    required this.selected,
    required this.loading,
    this.hasError = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: hasError ? _kRed.withValues(alpha: .04) : _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError ? _kRed : _kBorder,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.users,
              size: 16,
              color: hasError ? _kRed : (selected.isEmpty ? _kMuted : _kBlue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: loading
                  ? const Text(
                      'Loading employees...',
                      style: TextStyle(fontSize: 14, color: _kMuted),
                    )
                  : selected.isEmpty
                  ? const Text(
                      'Select employees',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kMuted,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selected
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kBlue.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _kBlue.withValues(alpha: .25),
                                ),
                              ),
                              child: Text(
                                a.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kBlue,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: loading ? _kMuted : _kNavy,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentInviteTile extends StatelessWidget {
  final List<ParentInviteModel> selected;
  final bool loading;
  final VoidCallback? onTap;

  const _ParentInviteTile({
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.usersRound,
              size: 17,
              color: selected.isEmpty ? _kMuted : _kBlue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: loading
                  ? const Text(
                      'Loading parents...',
                      style: TextStyle(fontSize: 14, color: _kMuted),
                    )
                  : selected.isEmpty
                  ? const Text(
                      'Invite parents',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kMuted,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selected
                          .map(
                            (parent) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kBlue.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _kBlue.withValues(alpha: .25),
                                ),
                              ),
                              child: Text(
                                parent.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kBlue,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: loading ? _kMuted : _kNavy,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin picker sheet ────────────────────────────────────────────────────────

class _AdminPickerSheet extends StatefulWidget {
  final List<AdminModel> admins;
  final List<AdminModel> selected;
  final Map<String, AppointmentConflict> conflicts;

  const _AdminPickerSheet({
    required this.admins,
    required this.selected,
    this.conflicts = const {},
  });

  @override
  State<_AdminPickerSheet> createState() => _AdminPickerSheetState();
}

class _AdminPickerSheetState extends State<_AdminPickerSheet> {
  late List<AdminModel> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  bool _isSelected(AdminModel a) => _selected.any((s) => s.id == a.id);

  void _toggle(AdminModel a) {
    if (!_isSelected(a) && widget.conflicts.containsKey(a.id)) return;
    setState(() {
      if (_isSelected(a)) {
        _selected.removeWhere((s) => s.id == a.id);
      } else {
        _selected.add(a);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, safe + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Select Employees',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_selected.length} selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.admins.length,
              itemBuilder: (_, i) {
                final admin = widget.admins[i];
                final picked = _isSelected(admin);
                final conflict = widget.conflicts[admin.id];
                return GestureDetector(
                  onTap: () => _toggle(admin),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: conflict != null
                          ? _kRed.withValues(alpha: .05)
                          : picked
                          ? _kBlue.withValues(alpha: .07)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: conflict != null
                            ? _kRed.withValues(alpha: .30)
                            : picked
                            ? _kBlue.withValues(alpha: .35)
                            : _kBorder,
                        width: picked ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: conflict != null
                                ? _kRed.withValues(alpha: .10)
                                : picked
                                ? _kBlue.withValues(alpha: .12)
                                : _kBg,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              admin.name.isNotEmpty
                                  ? admin.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: conflict != null
                                    ? _kRed
                                    : picked
                                    ? _kBlue
                                    : _kMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                admin.name,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: picked ? _kNavy : _kText,
                                ),
                              ),
                              if (admin.role.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: picked
                                        ? _kBlue.withValues(alpha: .12)
                                        : _kNavy.withValues(alpha: .07),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    admin.role,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: picked ? _kBlue : _kMuted,
                                    ),
                                  ),
                                ),
                              ],
                              if (conflict != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Already booked ${conflict.timeLabel}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kRed,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (conflict != null)
                          const Icon(LucideIcons.clock3, color: _kRed, size: 20)
                        else
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: picked ? _kBlue : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: picked ? _kBlue : _kBorder,
                                width: 1.5,
                              ),
                            ),
                            child: picked
                                ? const Icon(
                                    LucideIcons.check,
                                    size: 13,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Done button — disabled when nothing selected
          GestureDetector(
            onTap: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 50,
              decoration: BoxDecoration(
                color: _selected.isEmpty
                    ? _kMuted.withValues(alpha: .35)
                    : _kNavy,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                _selected.isEmpty
                    ? 'Select at least one employee'
                    : 'Done  (${_selected.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _selected.isEmpty ? _kMuted : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentInviteSheet extends StatefulWidget {
  final List<ParentInviteModel> parents;
  final List<StudentInviteModel> students;
  final List<ParentInviteModel> selected;
  final Map<String, AppointmentConflict> conflicts;
  final bool loading;
  final String hiddenParentId;

  const _ParentInviteSheet({
    required this.parents,
    required this.students,
    required this.selected,
    required this.conflicts,
    required this.loading,
    this.hiddenParentId = '',
  });

  @override
  State<_ParentInviteSheet> createState() => _ParentInviteSheetState();
}

class _ParentInviteSheetState extends State<_ParentInviteSheet> {
  late List<ParentInviteModel> _selected;
  final _searchCtrl = TextEditingController();
  bool _byStudent = false;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isSelected(ParentInviteModel parent) =>
      _selected.any((item) => item.id == parent.id);

  void _toggleParent(ParentInviteModel parent) {
    if (!_isSelected(parent) && widget.conflicts.containsKey(parent.id)) return;
    setState(() {
      if (_isSelected(parent)) {
        _selected.removeWhere((item) => item.id == parent.id);
      } else {
        _selected.add(parent);
      }
    });
  }

  void _toggleStudentParents(StudentInviteModel student) {
    final selectable = student.parents
        .where(
          (parent) =>
              parent.id != widget.hiddenParentId &&
              !widget.conflicts.containsKey(parent.id),
        )
        .toList();
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every((parent) => _isSelected(parent));
    setState(() {
      if (allSelected) {
        for (final parent in selectable) {
          _selected.removeWhere((item) => item.id == parent.id);
        }
      } else {
        for (final parent in selectable) {
          if (!_isSelected(parent)) _selected.add(parent);
        }
      }
    });
  }

  List<ParentInviteModel> get _filteredParents {
    final q = _searchCtrl.text.trim().toLowerCase();
    final visibleParents = widget.parents
        .where((parent) => parent.id != widget.hiddenParentId)
        .toList();
    if (q.isEmpty) return visibleParents;
    return visibleParents
        .where((parent) => parent.name.toLowerCase().contains(q))
        .toList();
  }

  List<StudentInviteModel> get _filteredStudents {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return widget.students
        .where((student) => student.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * .82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, safe + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Invite Parents',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _modeButton(
                    'By Parent',
                    !_byStudent,
                    () => setState(() {
                      _byStudent = false;
                      _searchCtrl.clear();
                    }),
                  ),
                ),
                Expanded(
                  child: _modeButton(
                    'By Student',
                    _byStudent,
                    () => setState(() {
                      _byStudent = true;
                      _searchCtrl.clear();
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _TextField(
            controller: _searchCtrl,
            hint: _byStudent
                ? 'Search student by name...'
                : 'Search parent by name...',
          ),
          const SizedBox(height: 12),
          if (widget.loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
              ),
            )
          else
            Expanded(
              child: _byStudent
                  ? _studentList()
                  : _parentList(_filteredParents),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context, _selected),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kNavy,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Done  (${_selected.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _kMuted,
          ),
        ),
      ),
    );
  }

  Widget _parentList(List<ParentInviteModel> parents) {
    if (parents.isEmpty) {
      return const Center(
        child: Text('No parents found.', style: TextStyle(color: _kMuted)),
      );
    }
    return ListView.builder(
      itemCount: parents.length,
      itemBuilder: (_, index) => _parentRow(parents[index]),
    );
  }

  Widget _studentList() {
    if (_searchCtrl.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Type a student name to find their parents.',
          style: TextStyle(color: _kMuted),
        ),
      );
    }
    final students = _filteredStudents;
    if (students.isEmpty) {
      return const Center(
        child: Text('No students found.', style: TextStyle(color: _kMuted)),
      );
    }
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (_, index) {
        final student = students[index];
        final visibleParents = student.parents
            .where((parent) => parent.id != widget.hiddenParentId)
            .toList();
        final selectable = visibleParents
            .where((parent) => !widget.conflicts.containsKey(parent.id))
            .toList();
        final allSelected =
            selectable.isNotEmpty &&
            selectable.every((parent) => _isSelected(parent));
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _avatar(student.name, selected: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                          ),
                        ),
                        if (student.className.isNotEmpty)
                          Text(
                            student.className,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: selectable.isEmpty
                        ? null
                        : () => _toggleStudentParents(student),
                    child: Text(allSelected ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (visibleParents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 44, bottom: 4),
                  child: Text(
                    'No parents linked',
                    style: TextStyle(color: _kMuted, fontSize: 12),
                  ),
                )
              else
                ...visibleParents.map(_parentRow),
            ],
          ),
        );
      },
    );
  }

  Widget _parentRow(ParentInviteModel parent) {
    final selected = _isSelected(parent);
    final conflict = widget.conflicts[parent.id];
    return GestureDetector(
      onTap: () => _toggleParent(parent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: conflict != null
              ? _kRed.withValues(alpha: .05)
              : selected
              ? _kBlue.withValues(alpha: .07)
              : _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: conflict != null
                ? _kRed.withValues(alpha: .30)
                : selected
                ? _kBlue.withValues(alpha: .35)
                : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _avatar(
              parent.name,
              selected: selected,
              conflict: conflict != null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parent.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: conflict != null ? _kRed : _kText,
                    ),
                  ),
                  if (conflict != null)
                    Text(
                      'Already booked ${conflict.timeLabel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _kRed,
                      ),
                    )
                  else if (parent.contact.isNotEmpty ||
                      parent.gradeName.isNotEmpty ||
                      parent.className.isNotEmpty)
                    Text(
                      [
                        parent.contact,
                        parent.gradeName,
                        parent.className,
                      ].where((item) => item.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (conflict != null)
              const Icon(LucideIcons.clock3, color: _kRed, size: 20)
            else
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                color: selected ? _kBlue : _kMuted,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name, {required bool selected, bool conflict = false}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: conflict
            ? _kRed.withValues(alpha: .10)
            : selected
            ? _kBlue.withValues(alpha: .12)
            : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: conflict ? _kRed.withValues(alpha: .25) : _kBorder,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: conflict
              ? _kRed
              : selected
              ? _kBlue
              : _kMuted,
        ),
      ),
    );
  }
}

// ── Scroll Time Picker Sheet ──────────────────────────────────────────────────

class _ScrollTimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _ScrollTimePickerSheet({required this.initial});

  @override
  State<_ScrollTimePickerSheet> createState() => _ScrollTimePickerSheetState();
}

class _ScrollTimePickerSheetState extends State<_ScrollTimePickerSheet> {
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Widget _wheel({
    required FixedExtentScrollController ctrl,
    required int itemCount,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 80,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 48,
        perspective: 0.003,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildListDelegate(
          children: List.generate(
            itemCount,
            (i) => Center(
              child: Text(
                _two(i),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _kNavy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, safe + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Text(
                'Select Time',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _kNavy,
                  letterSpacing: -.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(
                  context,
                  TimeOfDay(hour: _hour, minute: _minute),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _kNavy,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Wheels
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection highlight
                Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Hour + separator + Minute
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wheel(
                      ctrl: _hourCtrl,
                      itemCount: 24,
                      onChanged: (v) => _hour = v,
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _kNavy,
                      ),
                    ),
                    _wheel(
                      ctrl: _minCtrl,
                      itemCount: 60,
                      onChanged: (v) => _minute = v,
                    ),
                  ],
                ),
                // Top fade
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 72,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 72,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.white, Color(0x00FFFFFF)],
                        ),
                      ),
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

// ── Time Card ─────────────────────────────────────────────────────────────────

class _TimeCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _kBlue),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kNavy,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final Widget? iconOverride;
  final String label;
  final VoidCallback onTap;
  const _PickerTile({
    required this.icon,
    this.iconOverride,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            iconOverride ?? Icon(icon, size: 16, color: _kBlue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reschedule Sheet ──────────────────────────────────────────────────────────

class _RescheduleSheet extends StatefulWidget {
  final AppointmentModel appt;
  const _RescheduleSheet({required this.appt});

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _date;
  late DateTime _visibleMonth;
  late TimeOfDay _start;
  late TimeOfDay _end;

  late final FixedExtentScrollController _sHour;
  late final FixedExtentScrollController _sMin;
  late final FixedExtentScrollController _eHour;
  late final FixedExtentScrollController _eMin;

  int _dir = 1;

  static const _monthNames = [
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
  static const _wdLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static final _mins5 = List.generate(12, (i) => i * 5);

  @override
  void initState() {
    super.initState();
    _date = widget.appt.date;
    _visibleMonth = DateTime(_date.year, _date.month);
    _start = widget.appt.start;
    _end = widget.appt.end;
    _sHour = FixedExtentScrollController(initialItem: _start.hour);
    _sMin = FixedExtentScrollController(initialItem: _minIdx(_start.minute));
    _eHour = FixedExtentScrollController(initialItem: _end.hour);
    _eMin = FixedExtentScrollController(initialItem: _minIdx(_end.minute));
  }

  int _minIdx(int min) {
    int best = 0, diff = 999;
    for (int i = 0; i < _mins5.length; i++) {
      final d = (_mins5[i] - min).abs();
      if (d < diff) {
        diff = d;
        best = i;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _sHour.dispose();
    _sMin.dispose();
    _eHour.dispose();
    _eMin.dispose();
    super.dispose();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String _two(int n) => n.toString().padLeft(2, '0');

  void _prev() => setState(() {
    _dir = -1;
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
  });

  void _next() => setState(() {
    _dir = 1;
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
  });

  void _confirm() => Navigator.pop(context, (_date, _start, _end));

  Widget _buildGrid(DateTime vm) {
    final y = vm.year;
    final m = vm.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final offset = DateTime(y, m, 1).weekday % 7;
    final todayRaw = DateTime.now();
    final today = DateTime(todayRaw.year, todayRaw.month, todayRaw.day);
    final prevDays = DateTime(y, m, 0).day;

    final cells = <Widget>[];
    for (int i = 0; i < offset; i++) {
      cells.add(
        _DayCell(day: prevDays - offset + i + 1, faded: true, onTap: null),
      );
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(y, m, d);
      cells.add(
        _RSDay(
          day: d,
          isToday: _sameDay(date, today),
          isSelected: _sameDay(date, _date),
          onTap: () => setState(() => _date = date),
        ),
      );
    }
    final trailing = (7 - cells.length % 7) % 7;
    for (int i = 1; i <= trailing; i++) {
      cells.add(_DayCell(day: i, faded: true, onTap: null));
    }
    final rows = cells.length ~/ 7;
    return Column(
      children: [
        for (int r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r < rows - 1 ? 4 : 0),
            child: Row(
              children: List.generate(
                7,
                (c) => Expanded(child: cells[r * 7 + c]),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenH * 0.94),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 6, 20, safe + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reschedule',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _kNavy,
                                  letterSpacing: -.4,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pick a new date & time',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _kBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: _kBorder),
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 18,
                              color: _kMuted,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 200.ms),
                    const SizedBox(height: 10),

                    // Appointment context chip
                    Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _kBlue.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _kBlue.withValues(alpha: .16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.notebookPen,
                                size: 14,
                                color: _kBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.appt.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_two(widget.appt.start.hour)}:${_two(widget.appt.start.minute)}'
                                ' → ${_two(widget.appt.end.hour)}:${_two(widget.appt.end.minute)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _kMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 50.ms, duration: 220.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 280.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 22),

                    // Date label
                    const _RSLabel(
                      label: 'New Date',
                      icon: LucideIcons.calendarDays,
                    ).animate().fadeIn(delay: 90.ms, duration: 200.ms),
                    const SizedBox(height: 10),

                    // Calendar card
                    Container(
                          decoration: BoxDecoration(
                            color: _kBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _kBorder),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _NavBtn(
                                    icon: LucideIcons.chevronLeft,
                                    onTap: _prev,
                                  ),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 260,
                                      ),
                                      transitionBuilder: (child, anim) =>
                                          FadeTransition(
                                            opacity: anim,
                                            child: child,
                                          ),
                                      child: Text(
                                        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                                        key: ValueKey(_visibleMonth),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: _kNavy,
                                          letterSpacing: -.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _NavBtn(
                                    icon: LucideIcons.chevronRight,
                                    onTap: _next,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  for (final w in _wdLabels)
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          w,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _kMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, anim) {
                                  final isNew =
                                      child.key == ValueKey(_visibleMonth);
                                  final begin = Offset(
                                    isNew ? _dir * 0.28 : -_dir * 0.28,
                                    0,
                                  );
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position:
                                          Tween<Offset>(
                                            begin: begin,
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: anim,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  key: ValueKey(_visibleMonth),
                                  child: _buildGrid(_visibleMonth),
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 120.ms, duration: 260.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 320.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 22),

                    // Time label
                    const _RSLabel(
                      label: 'New Time',
                      icon: LucideIcons.clock,
                    ).animate().fadeIn(delay: 160.ms, duration: 200.ms),
                    const SizedBox(height: 10),

                    // Time wheels
                    Row(
                          children: [
                            Expanded(
                              child: _TimeWheelCard(
                                label: 'START',
                                hourCtrl: _sHour,
                                minCtrl: _sMin,
                                mins: _mins5,
                                onHourChanged: (h) => setState(
                                  () => _start = TimeOfDay(
                                    hour: h,
                                    minute: _start.minute,
                                  ),
                                ),
                                onMinChanged: (i) => setState(
                                  () => _start = TimeOfDay(
                                    hour: _start.hour,
                                    minute: _mins5[i],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimeWheelCard(
                                label: 'END',
                                hourCtrl: _eHour,
                                minCtrl: _eMin,
                                mins: _mins5,
                                onHourChanged: (h) => setState(
                                  () => _end = TimeOfDay(
                                    hour: h,
                                    minute: _end.minute,
                                  ),
                                ),
                                onMinChanged: (i) => setState(
                                  () => _end = TimeOfDay(
                                    hour: _end.hour,
                                    minute: _mins5[i],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(delay: 190.ms, duration: 260.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 320.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 26),

                    _RSConfirmBtn(onTap: _confirm)
                        .animate()
                        .fadeIn(delay: 230.ms, duration: 240.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 280.ms,
                          curve: Curves.easeOutCubic,
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

// ── Reschedule: selectable day cell ──────────────────────────────────────────

class _RSDay extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _RSDay({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color? bgColor;

    if (isSelected) {
      textColor = Colors.white;
      bgColor = _kNavy;
    } else if (isToday) {
      textColor = _kBlue;
      bgColor = _kBlue.withValues(alpha: .10);
    } else {
      textColor = _kText;
      bgColor = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 38,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected
                    ? FontWeight.w900
                    : (isToday ? FontWeight.w800 : FontWeight.w600),
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reschedule: section label ─────────────────────────────────────────────────

class _RSLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _RSLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: _kNavy),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: _kNavy,
            letterSpacing: -.1,
          ),
        ),
      ],
    );
  }
}

// ── Reschedule: time wheel card ───────────────────────────────────────────────

class _TimeWheelCard extends StatelessWidget {
  final String label;
  final FixedExtentScrollController hourCtrl;
  final FixedExtentScrollController minCtrl;
  final List<int> mins;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinChanged;

  const _TimeWheelCard({
    required this.label,
    required this.hourCtrl,
    required this.minCtrl,
    required this.mins,
    required this.onHourChanged,
    required this.onMinChanged,
  });

  static String _two(int n) => n.toString().padLeft(2, '0');

  Widget _wheel({
    required FixedExtentScrollController ctrl,
    required List<String> items,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 46,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 42,
        perspective: 0.003,
        diameterRatio: 1.45,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: items
              .map(
                (e) => Center(
                  child: Text(
                    e,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                      height: 1,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(24, (i) => _two(i));
    final minLabels = mins.map((m) => _two(m)).toList();

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: _kMuted,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 126,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _kNavy.withValues(alpha: .10)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wheel(
                      ctrl: hourCtrl,
                      items: hours,
                      onChanged: onHourChanged,
                    ),
                    const SizedBox(
                      width: 10,
                      height: 42,
                      child: Center(
                        child: Text(
                          ':',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _kNavy,
                          ),
                        ),
                      ),
                    ),
                    _wheel(
                      ctrl: minCtrl,
                      items: minLabels,
                      onChanged: onMinChanged,
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF5F7FA), Color(0x00F5F7FA)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFFF5F7FA), Color(0x00F5F7FA)],
                        ),
                      ),
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

// ── Reschedule: confirm button ────────────────────────────────────────────────

class _RSConfirmBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _RSConfirmBtn({required this.onTap});

  @override
  State<_RSConfirmBtn> createState() => _RSConfirmBtnState();
}

class _RSConfirmBtnState extends State<_RSConfirmBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _kNavy,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kNavy.withValues(alpha: .28),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.check, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Confirm Reschedule',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

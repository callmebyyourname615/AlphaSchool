import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  bool _loading = true;
  String? _error;
  AppointmentStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = _date(now);
    _visibleMonth = DateTime(now.year, now.month);
    _all = [];
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _svc.fetchAppointments();
      if (!mounted) return;
      setState(() {
        _all = list;
        if (_all.isNotEmpty && _forDay(_selectedDate).isEmpty) {
          _selectedDate = _date(_all.first.date);
          _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not load appointments'; _loading = false; });
    }
  }

  void _post(VoidCallback fn) =>
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(fn); });

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

  Set<DateTime> get _marked => {for (final a in _all) _date(a.date)};

  // ── actions ─────────────────────────────────────────────────────────────
  void _confirm(AppointmentModel a) {
    if (a.status == AppointmentStatus.cancelled) return;
    setState(() => a.status = AppointmentStatus.confirmed);
    _snack('Confirmed');
  }

  void _reschedule(AppointmentModel a) {
    if (a.status == AppointmentStatus.cancelled) return;
    setState(() {
      a.status = AppointmentStatus.postponed;
      a.date = _date(a.date.add(const Duration(days: 1)));
    });
    _snack('Rescheduled to ${_shortDate(a.date)}');
  }

  void _cancel(AppointmentModel a) {
    setState(() => a.status = AppointmentStatus.cancelled);
    _snack('Cancelled');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
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
    setState(() {
      _all.add(result);
      _selectedDate = _date(result.date);
      _visibleMonth = DateTime(result.date.year, result.date.month);
    });
    _snack('Appointment added');
    // persist to API (fire-and-forget; local state already updated)
    _svc.createAppointment(result).catchError((_) {});
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CalendarCard(
                      visibleMonth: _visibleMonth,
                      selectedDate: _selectedDate,
                      marked: _marked,
                      onPrev: () => _post(() => _visibleMonth =
                          DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                      onNext: () => _post(() => _visibleMonth =
                          DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
                      onPick: (d) => _post(() {
                        _selectedDate = _date(d);
                        _visibleMonth = DateTime(d.year, d.month);
                      }),
                    ).animate().fadeIn(duration: 240.ms).slideY(
                          begin: .04, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      count: _filtered.length,
                      activeFilter: _filterStatus,
                      onFilter: _showFilterSheet,
                    ).animate().fadeIn(delay: 60.ms, duration: 220.ms),
                    const SizedBox(height: 12),
                    if (_loading)
                      const _LoadCard()
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 220.ms)
                    else if (_error != null)
                      _ErrorCard(message: _error!, onRetry: _load)
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 220.ms)
                    else ...[
                      for (int i = 0; i < _filtered.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ApptCard(
                            appt: _filtered[i],
                            onConfirm: () => _confirm(_filtered[i]),
                            onReschedule: () => _reschedule(_filtered[i]),
                            onCancel: () => _cancel(_filtered[i]),
                          ).animate().fadeIn(
                                delay: Duration(milliseconds: 100 + i * 60),
                                duration: 240.ms,
                              ).slideY(
                                begin: .04,
                                end: 0,
                                duration: 360.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                      _NoMoreCard()
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 100 + _filtered.length * 60),
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
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _kNavy),
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
              child: const Icon(Icons.add, color: Colors.white, size: 24),
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
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
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
      child: Column(
        children: [
          // ── Month nav ──
          Row(
            children: [
              _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
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
              _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
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
      ).animate(key: ValueKey('$year-$month'))
          .fadeIn(duration: 200.ms)
          .slideY(begin: .02, end: 0, duration: 240.ms),
    );
  }

  Widget _buildGrid(
    int year, int month, int daysInMonth, int offset, DateTime todayD) {
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
      cells.add(_DayCell(
        day: d,
        isSelected: isSelected,
        isToday: isToday,
        hasMark: marked.contains(DateTime(date.year, date.month, date.day)),
        onTap: () => onPick(date),
      ));
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
                for (int c = 0; c < 7; c++)
                  Expanded(child: cells[r * 7 + c]),
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
    Color textColor;
    Color? bgColor;

    if (faded) {
      textColor = _kMuted.withValues(alpha: .45);
      bgColor = null;
    } else if (isSelected) {
      textColor = Colors.white;
      bgColor = _kBlue;
    } else {
      textColor = _kText;
      bgColor = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 38,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isToday && !isSelected) ? _kBlue : Colors.transparent,
              ),
            ),
          ],
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onFilter,
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: hasFilter ? _kNavy : _kBlue),
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
    AppointmentStatus.pending   => 'Pending',
  };
}

// ── Appointment Card ─────────────────────────────────────────────────────────

class _ApptCard extends StatelessWidget {
  final AppointmentModel appt;
  final VoidCallback onConfirm;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  const _ApptCard({
    required this.appt,
    required this.onConfirm,
    required this.onReschedule,
    required this.onCancel,
  });

  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('meet') || t.contains('parent') || t.contains('teacher')) {
      return Icons.people_alt_rounded;
    }
    if (t.contains('vacc') || t.contains('health') || t.contains('medical') ||
        t.contains('nurse') || t.contains('doctor')) {
      return Icons.vaccines_rounded;
    }
    if (t.contains('sport') || t.contains('activity')) {
      return Icons.sports_soccer_rounded;
    }
    return Icons.event_note_rounded;
  }

  static Color _iconBg(String title) {
    final t = title.toLowerCase();
    if (t.contains('meet') || t.contains('parent') || t.contains('teacher')) {
      return const Color(0xFFEEF2FF);
    }
    if (t.contains('vacc') || t.contains('health') || t.contains('medical') ||
        t.contains('nurse') || t.contains('doctor')) {
      return const Color(0xFFECFDF5);
    }
    return const Color(0xFFEFF6FF);
  }

  static Color _iconColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('meet') || t.contains('parent') || t.contains('teacher')) {
      return const Color(0xFF6366F1);
    }
    if (t.contains('vacc') || t.contains('health') || t.contains('medical') ||
        t.contains('nurse') || t.contains('doctor')) {
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
                        Image.asset('assets/images/icons/Calendar.png', width: 13, height: 13),
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
                          child: Text('|', style: TextStyle(color: _kMuted, fontSize: 12)),
                        ),
                        const Icon(Icons.access_time_rounded, size: 13, color: _kMuted),
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
                          const Icon(Icons.location_on_outlined, size: 13, color: _kMuted),
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
          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: isConfirmed ? 'Confirmed' : 'Confirm',
                  icon: Icons.check_rounded,
                  filled: !isConfirmed,
                  color: isConfirmed ? _kGreen : _kNavy,
                  disabled: isCancelled,
                  onTap: isCancelled ? null : onConfirm,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: 'Reschedule',
                  icon: Icons.calendar_month_outlined,
                  iconOverride: Image.asset('assets/images/icons/Calendar.png', width: 14, height: 14),
                  filled: false,
                  color: _kText,
                  disabled: isCancelled,
                  onTap: isCancelled ? null : onReschedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: 'Cancel',
                  icon: Icons.close_rounded,
                  filled: false,
                  color: _kText,
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
            iconOverride ?? Icon(
              icon,
              size: 14,
              color: filled ? (disabled ? _kMuted : Colors.white) : effectiveColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: filled ? (disabled ? _kMuted : Colors.white) : effectiveColor,
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
            child: Image.asset('assets/images/icons/Calendar.png', width: 20, height: 20),
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
                const Icon(Icons.sentiment_satisfied_alt_rounded, size: 18, color: _kBlue),
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
              child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
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
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kMuted),
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
          const Icon(Icons.cloud_off_rounded, size: 36, color: _kMuted),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: _kText)),
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
                  Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
              width: 40, height: 4,
              decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Filter by status',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy, letterSpacing: -.2),
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
          border: Border.all(color: isSelected ? _kBlue : _kBorder, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
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
              const Icon(Icons.check_circle_rounded, size: 18, color: _kBlue),
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

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _start = const TimeOfDay(hour: 9, minute: 0);
    _end = const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }
  String _fmtTime(TimeOfDay t) => '${_fmt2(t.hour)}:${_fmt2(t.minute)}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // auto-advance end by 1h if now <= start
        if (_toMins(picked) >= _toMins(_end)) {
          final total = _toMins(picked) + 60;
          _end = TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  int _toMins(TimeOfDay t) => t.hour * 60 + t.minute;

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _saving = true);
    final model = AppointmentModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      date: DateTime(_date.year, _date.month, _date.day),
      start: _start,
      end: _end,
      status: AppointmentStatus.pending,
    );
    Navigator.pop(context, model);
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'New Appointment',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy, letterSpacing: -.2),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: _kMuted, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            _FieldLabel(label: 'Title'),
            const SizedBox(height: 6),
            _TextField(controller: _titleCtrl, hint: 'e.g. Parent–Teacher Meeting'),
            const SizedBox(height: 14),

            // Date
            _FieldLabel(label: 'Date'),
            const SizedBox(height: 6),
            _PickerTile(
              icon: Icons.calendar_today_outlined,
              iconOverride: Image.asset('assets/images/icons/Calendar.png', width: 16, height: 16),
              label: _fmtDate(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),

            // Time row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'Start'),
                      const SizedBox(height: 6),
                      _PickerTile(
                        icon: Icons.access_time_rounded,
                        label: _fmtTime(_start),
                        onTap: () => _pickTime(true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'End'),
                      const SizedBox(height: 6),
                      _PickerTile(
                        icon: Icons.access_time_filled_rounded,
                        label: _fmtTime(_end),
                        onTap: () => _pickTime(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Note / location
            _FieldLabel(label: 'Location / Note (optional)'),
            const SizedBox(height: 6),
            _TextField(controller: _noteCtrl, hint: 'e.g. Room 101', maxLines: 2),
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
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Appointment',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
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
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted),
  );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _TextField({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final Widget? iconOverride;
  final String label;
  final VoidCallback onTap;
  const _PickerTile({required this.icon, this.iconOverride, required this.label, required this.onTap});

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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

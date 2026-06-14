import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../shared/models/student_card_item.dart';
import 'participant_model.dart';
import 'participant_service.dart';

// ── Palette (mirrors appointment_page.dart) ──────────────────────────────────
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

class ParticipantPage extends StatefulWidget {
  final StudentCardItem? selectedStudent;

  const ParticipantPage({super.key, this.selectedStudent});

  @override
  State<ParticipantPage> createState() => _ParticipantPageState();
}

class _ParticipantPageState extends State<ParticipantPage> {
  Future<ParticipantSummary>? _future;
  late DateTime _filterDate;

  StudentCardItem? get _student => widget.selectedStudent;

  Future<void> _pickDate(ParticipantSummary? summary) async {
    final now = DateTime.now();
    final first = summary?.days.isNotEmpty == true
        ? summary!.days.last.date
        : DateTime(now.year - 1);
    final last = summary?.days.isNotEmpty == true
        ? (summary!.days.first.date.isAfter(now)
              ? summary.days.first.date
              : now)
        : now;

    final initial = _filterDate.isBefore(first)
        ? first
        : (_filterDate.isAfter(last) ? last : _filterDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kBlue,
            onPrimary: Colors.white,
            onSurface: _kText,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _kBlue),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
        () => _filterDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  void _resetToToday() {
    final now = DateTime.now();
    setState(() => _filterDate = DateTime(now.year, now.month, now.day));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static String _formatDate(DateTime d) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterDate = DateTime(now.year, now.month, now.day);
    final student = _student;
    if (student != null) {
      _future = ParticipantService().fetchSummary(student);
    }
  }

  Future<void> _reload() async {
    final student = _student;
    if (student == null) return;
    setState(() {
      _future = ParticipantService().fetchSummary(student);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final student = _student;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(onBack: () => Navigator.maybePop(context)),
            if (student == null)
              const Expanded(child: _NoStudentState())
            else
              Expanded(
              child: FutureBuilder<ParticipantSummary>(
                future: _future,
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState != ConnectionState.done;
                  final error = snapshot.error?.toString();
                  final summary = snapshot.data;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + bottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        () {
                          final selectedDay = summary?.days
                              .where((d) => _sameDay(d.date, _filterDate))
                              .toList()
                              .firstOrNull;
                          return _HeroCard(
                            student: student,
                            percent: selectedDay?.percent ?? 0,
                            latestLabel: loading
                                ? 'Loading…'
                                : _formatDate(_filterDate),
                          );
                        }()
                            .animate()
                            .fadeIn(duration: 240.ms)
                            .slideY(
                              begin: .04,
                              end: 0,
                              duration: 380.ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 20),
                        _SectionRow(
                          title: 'Activity Weights',
                          subtitle: _isToday(_filterDate)
                              ? 'Today'
                              : 'Selected day',
                          filterDate: _filterDate,
                          onPick: () => _pickDate(summary),
                          onResetToday: _resetToToday,
                        ).animate().fadeIn(delay: 60.ms, duration: 220.ms),
                        const SizedBox(height: 12),
                        if (loading)
                          const _LoadCard().animate().fadeIn(
                            delay: 100.ms,
                            duration: 220.ms,
                          )
                        else if (error != null)
                          _ErrorCard(message: error, onRetry: _reload)
                              .animate()
                              .fadeIn(delay: 100.ms, duration: 220.ms)
                        else ...[
                          () {
                            final days = (summary?.days ?? [])
                                .where((d) => _sameDay(d.date, _filterDate))
                                .toList();

                            if (days.isEmpty) {
                              return _NoMatchCard(
                                onResetToday: _resetToToday,
                                isToday: _isToday(_filterDate),
                              ).animate().fadeIn(
                                delay: 100.ms,
                                duration: 240.ms,
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int i = 0; i < days.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child:
                                        _DayCard(day: days[i], index: i)
                                            .animate()
                                            .fadeIn(
                                              delay: Duration(
                                                milliseconds: 100 + i * 60,
                                              ),
                                              duration: 240.ms,
                                            )
                                            .slideY(
                                              begin: .04,
                                              end: 0,
                                              duration: 360.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                  ),
                              ],
                            );
                          }(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page Header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _PageHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: _kNavy,
            ),
            splashRadius: 22,
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Participation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                    letterSpacing: -.4,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Daily activity scores',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
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

// ── Section Row (title + date filter chip) ───────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime filterDate;
  final VoidCallback onPick;
  final VoidCallback onResetToday;

  const _SectionRow({
    required this.title,
    required this.subtitle,
    required this.filterDate,
    required this.onPick,
    required this.onResetToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _kNavy,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _DateChip(
          date: filterDate,
          onPick: onPick,
          onResetToday: onResetToday,
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPick;
  final VoidCallback onResetToday;

  const _DateChip({
    required this.date,
    required this.onPick,
    required this.onResetToday,
  });

  String _label(DateTime d) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _ParticipantPageState._isToday(date);

    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 8, isToday ? 12 : 6, 8),
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              _label(date),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -.05,
              ),
            ),
            if (!isToday) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onResetToday,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── No-match (filter set but day has no records) ─────────────────────────────

class _NoMatchCard extends StatelessWidget {
  final VoidCallback onResetToday;
  final bool isToday;

  const _NoMatchCard({required this.onResetToday, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 22,
              color: _kBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isToday ? 'No activities today' : 'No activities on this day',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try picking a different day from the calendar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
          if (!isToday) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onResetToday,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Back to today',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _kBlue,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoStudentState extends StatelessWidget {
  const _NoStudentState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 28,
                color: _kBlue,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a student',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick a student from the home screen to view their participation scores.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Card (student + overall ring) ───────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final StudentCardItem student;
  final int percent;
  final String latestLabel;

  const _HeroCard({
    required this.student,
    required this.percent,
    required this.latestLabel,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 26,
              color: _kBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                    letterSpacing: -.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 13,
                      color: _kMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        student.studentId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((student.className ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.class_outlined,
                        size: 13,
                        color: _kMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          student.className!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 13,
                      color: _kMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        latestLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            ),
          ),
          const SizedBox(width: 12),
          _PercentRing(percent: percent),
        ],
      ),
    );
  }
}

class _PercentRing extends StatefulWidget {
  final int percent;

  const _PercentRing({required this.percent});

  @override
  State<_PercentRing> createState() => _PercentRingState();
}

class _PercentRingState extends State<_PercentRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(
      begin: 0,
      end: (widget.percent / 100).clamp(0, 1).toDouble(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuint));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _PercentRing old) {
    super.didUpdateWidget(old);
    if (old.percent != widget.percent) {
      _from = _anim.value;
      _anim = Tween<double>(
        begin: _from,
        end: (widget.percent / 100).clamp(0, 1).toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuint));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final f = _anim.value;
          final shown = (f * 100).round();
          return CustomPaint(
            painter: _RingPainter(
              fraction: f,
              fg: _kBlue,
              track: const Color(0xFFEFF2F7),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$shown',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _kNavy,
                      letterSpacing: -.4,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    '%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    )
        .animate()
        .scale(
          begin: const Offset(.85, .85),
          end: const Offset(1, 1),
          duration: 380.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 260.ms);
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color fg;
  final Color track;

  _RingPainter({required this.fraction, required this.fg, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (fraction <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = fg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.fg != fg || old.track != track;
}

// ── Day Card (one date, list of activities) ──────────────────────────────────

class _DayCard extends StatelessWidget {
  final DayGroup day;
  final int index;

  const _DayCard({required this.day, required this.index});

  Color _statusColor(int p) {
    if (p >= 80) return _kGreen;
    if (p >= 50) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(day.percent);

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
          // ── Header row: icon + date + score badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 19,
                  color: _kBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        letterSpacing: -.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.fact_check_outlined,
                          size: 13,
                          color: _kMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${day.rows.length} '
                          '${day.rows.length == 1 ? "activity" : "activities"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: '${day.percent}%', color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _kBorder),
          // ── Activity rows ──
          for (int i = 0; i < day.rows.length; i++) ...[
            _ActivityRow(row: day.rows[i]),
            if (i < day.rows.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF1F3F6),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final DayRow row;

  const _ActivityRow({required this.row});

  Color get _scoreColor {
    if (row.max <= 0) return _kMuted;
    if (row.score >= row.max) return _kGreen;
    if (row.score <= 0) return _kMuted;
    return _kNavy;
  }

  @override
  Widget build(BuildContext context) {
    final full = row.max > 0 && row.score >= row.max;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: full ? _kGreen.withValues(alpha: .08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StatusDot(fraction: row.fraction),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.activityName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _kText,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _fmt(row.score),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' / ${_fmt(row.max)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _StatusDot extends StatelessWidget {
  final double fraction;

  const _StatusDot({required this.fraction});

  @override
  Widget build(BuildContext context) {
    final full = fraction >= 1;
    final zero = fraction <= 0;
    final color = full ? _kGreen : (zero ? const Color(0xFFD1D5DB) : _kBlue);

    return SizedBox(
      width: 8,
      height: 8,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: .2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ── State cards ──────────────────────────────────────────────────────────────

class _LoadCard extends StatelessWidget {
  const _LoadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation(_kBlue),
        ),
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
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_tethering_error_rounded,
              size: 22,
              color: _kRed,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Couldn't load scores",
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Try again',
                style: TextStyle(
                  fontSize: 13,
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
}


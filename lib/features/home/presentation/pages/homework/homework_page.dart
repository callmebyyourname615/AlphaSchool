import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../shared/models/student_card_item.dart';
import 'homework_detail_page.dart';
import 'homework_models.dart';
import 'homework_service.dart';

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

// ── Page ─────────────────────────────────────────────────────────────────────

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({
    super.key,
    this.title = "Homework",
    this.selectedStudent,
  });

  final String title;
  final StudentCardItem? selectedStudent;

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  final _searchCtrl = TextEditingController();
  final _service = HomeworkService();

  int _filter = 0; // 0 all · 1 pending · 2 done · 3 overdue
  HomeworkSort _sort = HomeworkSort.nearestDue;

  Future<List<HomeworkItem>>? _future;
  List<HomeworkItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadHomework();
  }

  void _loadHomework() {
    final s = widget.selectedStudent;
    _future = _service.fetchForStudent(
      studentId: s?.id,
      branchId: s?.branchId,
      classId: s?.classId,
    );
  }

  Future<void> _reload() async {
    setState(_loadHomework);
    await _future;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final student = widget.selectedStudent;
    final hasScope = (student?.classId ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(
              title: widget.title,
              onBack: () => Navigator.maybePop(context),
            ),
            if (!hasScope)
              const Expanded(child: _NoStudentState())
            else
              Expanded(
                child: FutureBuilder<List<HomeworkItem>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const _LoadingState();
                    }
                    if (snap.hasError) {
                      return _ErrorState(
                        message: snap.error.toString(),
                        onRetry: _reload,
                      );
                    }
                    _items = snap.data ?? const [];
                    return _buildContent(context, bottomInset);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double bottomInset) {
    final now = DateTime.now();

    final done = _items
        .where((e) => e.visual(now) == HomeworkVisual.done)
        .length;
    final pending = _items
        .where((e) => e.visual(now) == HomeworkVisual.pending)
        .length;
    final overdue = _items
        .where((e) => e.visual(now) == HomeworkVisual.overdue)
        .length;
    final ratio = _items.isEmpty ? 0.0 : (done / _items.length);

    // ── filter + search + sort ──
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _items.where((e) {
      if (q.isEmpty) return true;
      return e.subject.toLowerCase().contains(q) ||
          e.grade.toLowerCase().contains(q) ||
          (e.teacher ?? '').toLowerCase().contains(q);
    }).toList();

    list = switch (_filter) {
      0 => list,
      1 => list.where((e) => e.visual(now) == HomeworkVisual.pending).toList(),
      2 => list.where((e) => e.visual(now) == HomeworkVisual.done).toList(),
      _ => list.where((e) => e.visual(now) == HomeworkVisual.overdue).toList(),
    };

    list.sort(
      (a, b) => switch (_sort) {
        HomeworkSort.nearestDue => a.deadline.compareTo(b.deadline),
        HomeworkSort.latestDue => b.deadline.compareTo(a.deadline),
        HomeworkSort.subjectAZ => a.subject.toLowerCase().compareTo(
          b.subject.toLowerCase(),
        ),
      },
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OverviewCard(
                total: _items.length,
                done: done,
                pending: pending,
                overdue: overdue,
                ratio: ratio,
              )
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(
                begin: .04,
                end: 0,
                duration: 380.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 16),
          _SearchSortRow(
            controller: _searchCtrl,
            sort: _sort,
            onSortChanged: (v) => setState(() => _sort = v),
          ).animate().fadeIn(delay: 60.ms, duration: 220.ms),
          const SizedBox(height: 18),
          _SectionRow(
            title: 'Homework List',
            trailing: '${list.length} ${list.length == 1 ? "item" : "items"}',
          ).animate().fadeIn(delay: 90.ms, duration: 220.ms),
          const SizedBox(height: 12),
          _TabStrip(
            value: _filter,
            counts: [_items.length, pending, done, overdue],
            onChanged: (v) => setState(() => _filter = v),
          ).animate().fadeIn(delay: 110.ms, duration: 220.ms),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const _EmptyCard().animate().fadeIn(delay: 140.ms, duration: 220.ms)
          else
            for (int i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    _HomeworkCard(
                          item: list[i],
                          visual: list[i].visual(now),
                          onSubmit: () => _openDetail(list[i]),
                          onOpen: () => _openDetail(list[i]),
                        )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 140 + i * 60),
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
      ),
    );
  }

  Future<void> _openDetail(HomeworkItem item) async {
    final student = widget.selectedStudent;
    if (student == null) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HomeworkDetailPage(item: item, student: student),
      ),
    );
    if (submitted == true && mounted) {
      setState(() {
        _items = _items
            .map(
              (value) => value.id == item.id
                  ? value.copyWithStatus(HomeworkStatus.submitted)
                  : value,
            )
            .toList();
      });
    }
  }
}

// ── Page Header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          _SquareIconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 44),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _kText,
                    letterSpacing: -.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SquareIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: _kNavy),
      ),
    );
  }
}

// ── Overview Card ────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final int total;
  final int done;
  final int pending;
  final int overdue;
  final double ratio;

  const _OverviewCard({
    required this.total,
    required this.done,
    required this.pending,
    required this.overdue,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 26,
                  color: _kBlue,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Homework Progress',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _kText,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RatioRing(done: done, total: total),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressBar(ratio: ratio),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _KpiPill(
                  icon: Icons.dashboard_rounded,
                  color: _kBlue,
                  label: 'All',
                  count: total,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiPill(
                  icon: Icons.schedule_rounded,
                  color: _kOrange,
                  label: 'Pending',
                  count: pending,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiPill(
                  icon: Icons.verified_rounded,
                  color: _kGreen,
                  label: 'Done',
                  count: done,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiPill(
                  icon: Icons.error_outline_rounded,
                  color: _kRed,
                  label: 'Overdue',
                  count: overdue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatioRing extends StatelessWidget {
  final int done;
  final int total;

  const _RatioRing({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 64,
      height: 64,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutQuint,
        builder: (context, t, _) {
          return CustomPaint(
            painter: _RingPainter(
              fraction: t,
              fg: _kBlue,
              track: const Color(0xFFEFF2F7),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: _kBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$done/$total',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: _kNavy,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color fg;
  final Color track;

  _RingPainter({required this.fraction, required this.fg, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
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

class _ProgressBar extends StatelessWidget {
  final double ratio;

  const _ProgressBar({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return Stack(
                  children: [
                    Container(
                      width: w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => Container(
                        width: (w * t).clamp(0.0, w),
                        decoration: BoxDecoration(
                          color: _kBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$pct%',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: _kBlue,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _KpiPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _KpiPill({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _kText,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search + Sort Row ────────────────────────────────────────────────────────

class _SearchSortRow extends StatelessWidget {
  final TextEditingController controller;
  final HomeworkSort sort;
  final ValueChanged<HomeworkSort> onSortChanged;

  const _SearchSortRow({
    required this.controller,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, size: 18, color: _kMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Search subject / grade / teacher…',
                      hintStyle: TextStyle(
                        color: _kMuted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: const TextStyle(
                      color: _kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SortChip(sort: sort, onChanged: onSortChanged),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final HomeworkSort sort;
  final ValueChanged<HomeworkSort> onChanged;

  const _SortChip({required this.sort, required this.onChanged});

  String _label(HomeworkSort s) => switch (s) {
    HomeworkSort.nearestDue => 'Due',
    HomeworkSort.latestDue => 'Latest',
    HomeworkSort.subjectAZ => 'A–Z',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HomeworkSort>(
      initialValue: sort,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _kBorder),
      ),
      color: _kCardBg,
      elevation: 6,
      itemBuilder: (_) => [
        for (final s in HomeworkSort.values)
          PopupMenuItem(
            value: s,
            child: Text(
              switch (s) {
                HomeworkSort.nearestDue => 'Nearest due',
                HomeworkSort.latestDue => 'Latest due',
                HomeworkSort.subjectAZ => 'Subject A–Z',
              },
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: sort == s ? _kBlue : _kText,
              ),
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.unfold_more_rounded, size: 16, color: _kText),
            const SizedBox(width: 6),
            Text(
              _label(sort),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 16, color: _kMuted),
          ],
        ),
      ),
    );
  }
}

// ── Section Row + Tab Strip ──────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionRow({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kNavy,
              letterSpacing: -.2,
            ),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  final int value;
  final List<int> counts;
  final ValueChanged<int> onChanged;

  const _TabStrip({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _TabSpec('All', Icons.dashboard_rounded, _kBlue),
      _TabSpec('Pending', Icons.schedule_rounded, _kOrange),
      _TabSpec('Done', Icons.verified_rounded, _kGreen),
      _TabSpec('Overdue', Icons.error_outline_rounded, _kRed),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            _TabPill(
              spec: tabs[i],
              active: value == i,
              onTap: () => onChanged(i),
            ),
            if (i < tabs.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final Color color;

  const _TabSpec(this.label, this.icon, this.color);
}

class _TabPill extends StatelessWidget {
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: active ? spec.color : _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? spec.color : _kBorder),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: spec.color.withValues(alpha: .25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              spec.icon,
              size: 15,
              color: active ? Colors.white : spec.color,
            ),
            const SizedBox(width: 6),
            Text(
              spec.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : _kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Homework Card ────────────────────────────────────────────────────────────

class _HomeworkCard extends StatelessWidget {
  final HomeworkItem item;
  final HomeworkVisual visual;
  final VoidCallback onSubmit;
  final VoidCallback onOpen;

  const _HomeworkCard({
    required this.item,
    required this.visual,
    required this.onSubmit,
    required this.onOpen,
  });

  Color get _statusColor => switch (visual) {
    HomeworkVisual.done => _kGreen,
    HomeworkVisual.pending => _kOrange,
    HomeworkVisual.overdue => _kRed,
  };

  String get _statusLabel => switch (visual) {
    HomeworkVisual.done => 'Done',
    HomeworkVisual.pending => 'Pending',
    HomeworkVisual.overdue => 'Overdue',
  };

  IconData get _statusIcon => switch (visual) {
    HomeworkVisual.done => Icons.verified_rounded,
    HomeworkVisual.pending => Icons.schedule_rounded,
    HomeworkVisual.overdue => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _statusColor.withValues(alpha: .18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: subject + status badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _kText,
                        letterSpacing: -.2,
                      ),
                    ),
                    if ((item.teacher ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: _kBlue,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.teacher!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kBlue,
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
              _StatusBadge(
                label: _statusLabel,
                icon: _statusIcon,
                color: _statusColor,
              ),
            ],
          ),
          if ((item.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.description!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _kText,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // ── Meta chips ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.menu_book_rounded,
                label: 'Grade',
                value: item.grade,
              ),
              _MetaChip(
                icon: Icons.equalizer_rounded,
                label: 'Total',
                value: item.totalScore == null
                    ? '—'
                    : _fmtScore(item.totalScore!),
              ),
              _MetaChip(
                icon: Icons.send_rounded,
                label: 'Sent',
                value: item.sentAt == null ? '—' : _fmtTime(item.sentAt!),
              ),
              _MetaChip(
                icon: Icons.event_rounded,
                label: 'Due',
                value: _fmtDate(item.deadline),
                valueColor: visual == HomeworkVisual.overdue ? _kRed : _kText,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visual == HomeworkVisual.done) ...[
            _ScoreContainer(item: item),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: visual == HomeworkVisual.done ? onOpen : onSubmit,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: visual == HomeworkVisual.done
                          ? _kCardBg
                          : _statusColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(13),
                      border: visual == HomeworkVisual.done
                          ? Border.all(color: _kBorder)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          visual == HomeworkVisual.done
                              ? Icons.visibility_outlined
                              : Icons.upload_rounded,
                          size: 17,
                          color: visual == HomeworkVisual.done
                              ? _kNavy
                              : _statusColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          visual == HomeworkVisual.done
                              ? 'View detail'
                              : 'Submit homework',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: visual == HomeworkVisual.done
                                ? _kNavy
                                : _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtScore(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmtTime(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

  static String _fmtDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

class _ScoreContainer extends StatelessWidget {
  const _ScoreContainer({required this.item});

  final HomeworkItem item;

  @override
  Widget build(BuildContext context) {
    final isGraded = item.isGraded && item.yourScore != null;
    final color = isGraded ? _kGreen : _kOrange;
    final value = isGraded
        ? '${_format(item.yourScore!)}${item.totalScore == null ? '' : ' / ${_format(item.totalScore!)}'}'
        : 'Pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Your Score',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kText,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kMuted),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _kMuted,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? _kText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty ────────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt_rounded, size: 22, color: _kBlue),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nothing here',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No homework matches the current filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation(_kBlue),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_tethering_error_rounded,
                size: 24,
                color: _kRed,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load homework",
              style: TextStyle(
                fontSize: 15,
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
                  horizontal: 22,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 13.5,
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
              'No student selected',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Pick a student from the home screen — we'll show only the homework assigned to their class.",
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

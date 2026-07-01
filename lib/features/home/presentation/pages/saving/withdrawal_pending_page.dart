import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'saving_service.dart';

/// Post-submit tracking screen for parent withdrawal requests.
///
/// The withdrawal flow walks through five backend states:
///   pending → admin_confirmed → super_admin_approved → parent_received
///   (or teacher_received for class savings). Any *_rejected branches map to
///   the terminal "Rejected" state.
///
/// The page polls `pay-receives/:id` on demand so the parent can refresh and
/// watch their request advance.
class WithdrawalPendingPage extends StatefulWidget {
  const WithdrawalPendingPage({
    super.key,
    required this.payReceiveId,
    required this.amount,
    required this.studentName,
    this.initialStatus = 'pending',
    this.note,
  });

  final String payReceiveId;
  final double amount;
  final String studentName;
  final String initialStatus;
  final String? note;

  @override
  State<WithdrawalPendingPage> createState() => _WithdrawalPendingPageState();
}

class _WithdrawalPendingPageState extends State<WithdrawalPendingPage> {
  static const _blue = Color(0xFF0756D1);
  static const _blueSoft = Color(0xFFEAF1FF);
  static const _blueSofter = Color(0xFFF7F9FE);
  static const _navy = Color(0xFF071B55);
  static const _muted = Color(0xFF64739B);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate100 = Color(0xFFEFF2F8);
  static const _emerald = Color(0xFF059669);
  static const _emeraldSoft = Color(0xFFECFDF5);
  static const _amber = Color(0xFFF59E0B);
  static const _amberSoft = Color(0xFFFFF7E6);
  static const _rose = Color(0xFFE11D48);
  static const _roseSoft = Color(0xFFFFF1F2);

  final _service = SavingService();
  final _moneyFmt = NumberFormat('#,##0');

  late String _status;
  bool _refreshing = false;
  DateTime _submittedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _status = _normalize(widget.initialStatus);
    // Pull the latest state once so backend-derived fields (created_at,
    // updated_at) are available in case the caller didn't pass them in.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(silent: true));
  }

  String _normalize(String s) {
    final v = s.trim().toLowerCase();
    if (v.isEmpty) return 'pending';
    return v;
  }

  bool get _isTerminal =>
      _status == 'parent_received' ||
      _status == 'teacher_received' ||
      _status.contains('rejected');

  bool get _isRejected => _status.contains('rejected');

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent) setState(() => _refreshing = true);
    final record = await _service.fetchWithdrawalStatus(widget.payReceiveId);
    if (!mounted) return;
    if (record != null) {
      final next = _normalize((record['status'] ?? '').toString());
      final created = record['created_at']?.toString();
      setState(() {
        if (next.isNotEmpty) _status = next;
        if (created != null && created.isNotEmpty) {
          final parsed = DateTime.tryParse(created);
          if (parsed != null) _submittedAt = parsed;
        }
        _refreshing = false;
      });
    } else {
      if (!silent) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blueSofter,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(),
                  const SizedBox(height: 12),
                  _hero(),
                  const SizedBox(height: 16),
                  _amountCard(),
                  const SizedBox(height: 16),
                  _timeline(),
                  const SizedBox(height: 20),
                  _primaryAction(),
                  const SizedBox(height: 10),
                  _doneLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft, size: 18, color: _navy),
          tooltip: 'Back',
        ),
        const Spacer(),
      ],
    );
  }

  Widget _hero() {
    final config = _heroConfig();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _slate100),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _HeroIcon(
            icon: config.icon,
            color: config.color,
            background: config.background,
            spinning: !_isTerminal,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: config.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: config.color.withValues(alpha: .4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.circle, color: config.color, size: 8),
                const SizedBox(width: 6),
                Text(
                  config.badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: config.deepText,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            config.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _navy,
              letterSpacing: -.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            config.subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: _muted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  _HeroConfig _heroConfig() {
    if (_status == 'parent_received' || _status == 'teacher_received') {
      return _HeroConfig(
        title: 'Cash received',
        subtitle: 'The school has released your withdrawal. Enjoy!',
        badgeText: 'COMPLETED',
        icon: LucideIcons.circleCheck,
        color: _emerald,
        background: _emeraldSoft,
        deepText: const Color(0xFF065F46),
      );
    }
    if (_isRejected) {
      return _HeroConfig(
        title: 'Request rejected',
        subtitle:
            'The school could not process this withdrawal. Please contact the office for details.',
        badgeText: 'REJECTED',
        icon: LucideIcons.circleX,
        color: _rose,
        background: _roseSoft,
        deepText: const Color(0xFF9F1239),
      );
    }
    if (_status == 'super_admin_approved') {
      return _HeroConfig(
        title: 'Approved — ready for pickup',
        subtitle:
            'Visit the school office to collect the cash. The teacher will hand it over and confirm.',
        badgeText: 'READY FOR PICKUP',
        icon: LucideIcons.handCoins,
        color: _blue,
        background: _blueSoft,
        deepText: _blue,
      );
    }
    if (_status == 'admin_confirmed') {
      return _HeroConfig(
        title: 'Admin confirmed',
        subtitle:
            'Your request was reviewed and forwarded to the super admin for final approval.',
        badgeText: 'WAITING SUPER ADMIN',
        icon: LucideIcons.userCheck,
        color: _blue,
        background: _blueSoft,
        deepText: _blue,
      );
    }
    // pending (and unknown statuses)
    return _HeroConfig(
      title: 'Send successfully',
      subtitle:
          'Your withdrawal request was received. The school will review it shortly.',
      badgeText: 'PENDING REVIEW',
      icon: LucideIcons.hourglass,
      color: _amber,
      background: _amberSoft,
      deepText: const Color(0xFFB45309),
    );
  }

  Widget _amountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _slate100),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.arrowDownToLine,
              color: _blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WITHDRAW',
                  style: TextStyle(
                    fontSize: 10,
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_moneyFmt.format(widget.amount)} ₭',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              DateFormat('d MMM · HH:mm').format(_submittedAt),
              style: const TextStyle(
                fontSize: 11,
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline() {
    final steps = _buildSteps();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14, left: 4),
            child: Text(
              'TRACKING',
              style: TextStyle(
                fontSize: 11,
                color: _blue,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          for (int i = 0; i < steps.length; i++) ...[
            _timelineRow(steps[i], isLast: i == steps.length - 1),
          ],
        ],
      ),
    );
  }

  List<_TimelineStep> _buildSteps() {
    final reachedIdx = _reachedIndex();
    final stagesActive = !_isRejected;
    const labels = [
      _TimelineStage(
        title: 'Send successfully',
        subtitle: 'Request received by the system',
        icon: LucideIcons.send,
      ),
      _TimelineStage(
        title: 'Pending review',
        subtitle: 'Waiting for admin to confirm',
        icon: LucideIcons.hourglass,
      ),
      _TimelineStage(
        title: 'Admin confirmed',
        subtitle: 'Forwarded to super admin',
        icon: LucideIcons.userCheck,
      ),
      _TimelineStage(
        title: 'Super admin approved',
        subtitle: 'Approved — ready for pickup',
        icon: LucideIcons.shieldCheck,
      ),
      _TimelineStage(
        title: 'Cash received',
        subtitle: 'Withdrawal complete',
        icon: LucideIcons.circleCheck,
      ),
    ];
    return [
      for (int i = 0; i < labels.length; i++)
        _TimelineStep(
          stage: labels[i],
          state: !stagesActive && i > 0
              ? _StepState.dimmed
              : i < reachedIdx
              ? _StepState.done
              : i == reachedIdx
              ? (_isTerminal && !_isRejected
                  ? _StepState.done
                  : _StepState.active)
              : _StepState.upcoming,
        ),
      if (_isRejected)
        _TimelineStep(
          stage: const _TimelineStage(
            title: 'Rejected',
            subtitle: 'Contact the school for next steps',
            icon: LucideIcons.circleX,
          ),
          state: _StepState.rejected,
        ),
    ];
  }

  int _reachedIndex() {
    switch (_status) {
      case 'pending':
        return 1; // current: Pending review
      case 'admin_confirmed':
        return 2;
      case 'super_admin_approved':
        return 3;
      case 'parent_received':
      case 'teacher_received':
        return 4;
      default:
        return 0;
    }
  }

  Widget _timelineRow(_TimelineStep step, {required bool isLast}) {
    Color circleBg;
    Color circleFg;
    Color titleColor;
    Color subtitleColor;
    Color lineColor;
    Widget iconWidget;

    switch (step.state) {
      case _StepState.done:
        circleBg = _emerald.withValues(alpha: .14);
        circleFg = _emerald;
        titleColor = _navy;
        subtitleColor = _muted;
        lineColor = _emerald.withValues(alpha: .35);
        iconWidget = const Icon(LucideIcons.check, size: 16, color: _emerald);
        break;
      case _StepState.active:
        circleBg = _amberSoft;
        circleFg = _amber;
        titleColor = _navy;
        subtitleColor = _muted;
        lineColor = _slate100;
        iconWidget = step.stage.icon == LucideIcons.hourglass
            ? const _SpinningHourglass(color: _amber, size: 16)
            : Icon(step.stage.icon, size: 16, color: _amber);
        break;
      case _StepState.upcoming:
        circleBg = _slate100;
        circleFg = _slate400;
        titleColor = _slate400;
        subtitleColor = _slate400;
        lineColor = _slate100;
        iconWidget = Icon(step.stage.icon, size: 16, color: _slate400);
        break;
      case _StepState.dimmed:
        circleBg = _slate100;
        circleFg = _slate400;
        titleColor = _slate400;
        subtitleColor = _slate400;
        lineColor = _slate100;
        iconWidget = Icon(step.stage.icon, size: 14, color: _slate400);
        break;
      case _StepState.rejected:
        circleBg = _roseSoft;
        circleFg = _rose;
        titleColor = _rose;
        subtitleColor = _muted;
        lineColor = _slate100;
        iconWidget = const Icon(LucideIcons.circleX, size: 16, color: _rose);
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: circleBg,
                  shape: BoxShape.circle,
                  border: step.state == _StepState.active
                      ? Border.all(color: circleFg.withValues(alpha: .35), width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: iconWidget,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: lineColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 4,
                bottom: isLast ? 0 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.stage.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: -.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.stage.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      height: 1.35,
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

  Widget _primaryAction() {
    final terminal = _isTerminal;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: terminal && !_isRejected
            ? () => Navigator.of(context).pop(true)
            : _refreshing
            ? null
            : () => _refresh(),
        icon: _refreshing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                terminal
                    ? (_isRejected ? LucideIcons.arrowLeft : LucideIcons.check)
                    : LucideIcons.refreshCw,
                size: 18,
              ),
        label: Text(
          _refreshing
              ? 'Checking status...'
              : terminal
              ? (_isRejected ? 'Back to savings' : 'Done')
              : 'Check status',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRejected ? _rose : _blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _doneLink() {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(
        foregroundColor: _muted,
        minimumSize: const Size.fromHeight(40),
      ),
      child: const Text(
        'Close',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HeroConfig {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color color;
  final Color background;
  final Color deepText;
  const _HeroConfig({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.color,
    required this.background,
    required this.deepText,
  });
}

class _TimelineStage {
  final String title;
  final String subtitle;
  final IconData icon;
  const _TimelineStage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

enum _StepState { done, active, upcoming, dimmed, rejected }

class _TimelineStep {
  final _TimelineStage stage;
  final _StepState state;
  const _TimelineStep({required this.stage, required this.state});
}

/// Animated hero icon — soft expanding ripple plus a breathing icon badge.
/// Used while the request is in flight (pending / admin_confirmed / etc.).
class _HeroIcon extends StatefulWidget {
  const _HeroIcon({
    required this.icon,
    required this.color,
    required this.background,
    this.spinning = true,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final bool spinning;

  @override
  State<_HeroIcon> createState() => _HeroIconState();
}

class _HeroIconState extends State<_HeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _HeroIcon old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      width: 84,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_c.value);
              final extra = 28.0 * t;
              return Opacity(
                opacity: (1 - t) * 0.55,
                child: Container(
                  width: 84 + extra,
                  height: 84 + extra,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 2),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_c.value);
              final scale = widget.spinning ? 0.96 + 0.05 * t : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.background,
                border: Border.all(color: widget.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .22),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 38, color: widget.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinningHourglass extends StatefulWidget {
  const _SpinningHourglass({required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  State<_SpinningHourglass> createState() => _SpinningHourglassState();
}

class _SpinningHourglassState extends State<_SpinningHourglass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final eased = Curves.easeInOutCubic.transform(_c.value);
        return Transform.rotate(
          angle: eased * 2 * 3.14159,
          child: Icon(
            LucideIcons.hourglass,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/global_alert_service.dart';
import '../../data/student_registration_service.dart';

class StudentPendingPage extends StatefulWidget {
  const StudentPendingPage({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentLocalId,
    this.nickname,
    this.initialApprovalStatus,
    this.initialRejectReason,
  });

  /// Backend UUID — used for polling /students/:id.
  final String studentId;

  /// Human-readable name shown on the card.
  final String studentName;

  /// Temporary code (e.g. PENDING-1782300876) for the parent's reference.
  final String? studentLocalId;

  final String? nickname;
  final String? initialApprovalStatus;
  final String? initialRejectReason;

  @override
  State<StudentPendingPage> createState() => _StudentPendingPageState();
}

class _StudentPendingPageState extends State<StudentPendingPage> {
  static const _blue = Color(0xFF0756D1);
  static const _blueLight = Color(0xFF1473E6);
  static const _blueSoft = Color(0xFFEAF1FF);
  static const _blueSofter = Color(0xFFF7F9FE);
  static const _blueSurface = Color(0xFFF1F6FF);
  static const _navy = Color(0xFF071B55);
  static const _muted = Color(0xFF64739B);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate100 = Color(0xFFEFF2F8);
  static const _amber = Color(0xFFF59E0B);
  static const _amberSurface = Color(0xFFFFF7E6);
  static const _amberBorder = Color(0xFFFCD9A2);
  static const _rose = Color(0xFFE11D48);
  static const _roseDark = Color(0xFF9F1239);
  static const _roseSurface = Color(0xFFFFF1F2);
  static const _roseBorder = Color(0xFFFFCDD5);
  static const _border = _slate200;
  static const _text = _navy;

  final ApiClient _api = ApiClient();
  bool _checking = false;
  bool _deleting = false;
  bool _rejected = false;
  String _rejectReason = '';

  @override
  void initState() {
    super.initState();
    final initialStatus = widget.initialApprovalStatus?.trim().toLowerCase();
    if (initialStatus == 'rejected') {
      _rejected = true;
      _rejectReason = widget.initialRejectReason?.trim() ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_rejected) {
        _showRejectedAlert(_rejectReason);
        return;
      }
      _checkStatus();
    });
  }

  String get _initials {
    final parts = widget.studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final res = await _api.get('/students/${widget.studentId}');
      if (!mounted) return;
      final record = _studentRecord(res);
      final status = _approvalStatus(record);
      final active =
          status == 'approved' ||
          record['is_active'] == true ||
          record['isActive'] == true;
      if (active) {
        // Approved — the cached draft for this student is no longer needed.
        await StudentDraftStore.clear(widget.studentId);
        if (!mounted) return;
        // Pop the page FIRST. Showing a GlobalAlert before pop would push
        // a dialog onto the navigator, and Navigator.pop would then pop the
        // dialog instead of this page, leaving the user stuck on
        // "Checking status...". choose_students surfaces the success toast.
        Navigator.of(context).pop(true);
        return;
      }
      if (status == 'rejected') {
        final reason = _readString(record, const [
          'reject_reason',
          'rejectReason',
          'rejection_reason',
          'rejectionReason',
        ]);
        setState(() {
          _rejected = true;
          _rejectReason = reason;
          _checking = false;
        });
        _showRejectedAlert(reason);
        return;
      }
    } catch (_) {
      // Stay silent on transient errors — the parent can retry.
    }
    if (!mounted) return;
    setState(() => _checking = false);
  }

  void _showRejectedAlert(String reason) {
    GlobalAlert.showError(
      title: 'Student rejected',
      message: reason.trim().isEmpty
          ? 'Admin rejected ${widget.studentName}. Please review the student information and submit again.'
          : reason.trim(),
    );
  }

  Map<String, dynamic> _studentRecord(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      final student = response['student'];
      if (student is Map<String, dynamic>) return student;
      return response;
    }
    return const {};
  }

  String _approvalStatus(Map<String, dynamic> record) {
    final raw = (record['approval_status'] ?? record['approvalStatus'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (raw == 'approved' || raw == 'rejected' || raw == 'pending') {
      return raw!;
    }
    return '';
  }

  String _readString(Map<String, dynamic> record, List<String> keys) {
    for (final key in keys) {
      final value = record[key];
      if (value != null) return value.toString().trim();
    }
    return '';
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
                  _summary(),
                  const SizedBox(height: 16),
                  _timeline(),
                  const SizedBox(height: 20),
                  _primary(),
                  const SizedBox(height: 10),
                  _secondary(),
                  const SizedBox(height: 6),
                  _doneLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Sections
  // ────────────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(LucideIcons.arrowLeft, size: 18, color: _navy),
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _blueSofter,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _blueSoft),
      ),
      child: Column(
        children: [
          _rejected
              ? const _RejectedIcon()
              : const _PendingPulseIcon(
                  color: _amber,
                  background: _amberSurface,
                ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _rejected ? _roseSurface : _amberSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _rejected ? _rose.withValues(alpha: .35) : _amberBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _rejected ? LucideIcons.circleX : LucideIcons.circle,
                  color: _rejected ? _rose : _amber,
                  size: _rejected ? 12 : 8,
                ),
                const SizedBox(width: 6),
                Text(
                  _rejected ? 'REJECTED' : 'PENDING APPROVAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _rejected ? _roseDark : const Color(0xFFB45309),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _rejected ? 'Student Rejected' : 'Student Submitted',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: 'Thank you, ',
              style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
              children: [
                TextSpan(
                  text: widget.studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                TextSpan(
                  text: _rejected
                      ? '. Admin reviewed this application and requested changes.'
                      : '. Your application has been received and is now waiting for admin approval.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (_rejected) ...[
            const SizedBox(height: 14),
            _rejectionReasonCard(),
          ],
        ],
      ),
    );
  }

  Widget _rejectionReasonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _roseBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.messageCircleWarning, color: _rose, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason from admin',
                  style: TextStyle(
                    color: _roseDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rejectReason.isEmpty
                      ? 'Please review the student information and submit again.'
                      : _rejectReason,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _blueSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.nickname != null && widget.nickname!.isNotEmpty)
                      _miniChip(label: widget.nickname!),
                    if (widget.studentLocalId != null)
                      _miniChip(label: widget.studentLocalId!, mono: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip({required String label, bool mono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: _muted,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null,
          letterSpacing: mono ? 0.6 : 0,
        ),
      ),
    );
  }

  Widget _timeline() {
    final steps = [
      const _TimelineStep(
        'Submitted',
        'Application received',
        LucideIcons.circleCheck,
        _blue,
        true,
      ),
      _TimelineStep(
        _rejected ? 'Rejected' : 'Pending Review',
        _rejected ? 'Admin requested changes' : 'Waiting for admin approval',
        _rejected ? LucideIcons.circleX : LucideIcons.hourglass,
        _rejected ? _rose : _amber,
        true,
      ),
      _TimelineStep(
        _rejected ? 'Resubmit' : 'Approved',
        _rejected
            ? 'Update details and send again'
            : "You'll be notified once approved",
        _rejected ? LucideIcons.filePenLine : LucideIcons.badgeCheck,
        _slate400,
        false,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _slate100),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++)
            _timelineRow(steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }

  Widget _timelineRow(_TimelineStep s, {required bool isLast}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: s.active ? s.color.withValues(alpha: .14) : _slate100,
                  shape: BoxShape.circle,
                ),
                child: s.icon == LucideIcons.hourglass
                    ? _SpinningHourglass(color: s.color, size: 16)
                    : Icon(s.icon, color: s.color, size: 16),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 18,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: _slate100,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: s.active ? _navy : _slate400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.subtitle,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primary() {
    final isResubmit = _rejected && !_checking;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _checking
            ? null
            : isResubmit
                ? () => Navigator.of(context).pop('resubmit')
                : _checkStatus,
        icon: _checking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isResubmit ? LucideIcons.filePenLine : LucideIcons.refreshCw,
                size: 18,
              ),
        label: Text(
          _checking
              ? 'Checking status...'
              : isResubmit
              ? 'Resubmit'
              : 'Check approval status',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _blueLight.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _secondary() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop('add_another'),
        icon: const Icon(LucideIcons.userPlus, size: 18, color: _blue),
        label: const Text('Add another student'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(color: _border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _doneLink() {
    return TextButton.icon(
      onPressed: _deleting ? null : _confirmDelete,
      icon: _deleting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _rose),
            )
          : const Icon(LucideIcons.trash2, size: 16, color: _rose),
      label: Text(
        _deleting ? 'Deleting...' : 'Delete',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _rose,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: _rose,
        minimumSize: const Size.fromHeight(40),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await GlobalAlert.showConfirmation(
      title: 'Delete application?',
      message:
          'This will remove ${widget.studentName}’s application. This cannot be undone.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    GlobalAlert.showLoading(message: 'Deleting application...');
    try {
      await _api.delete('/students/${widget.studentId}');
      await StudentDraftStore.clear(widget.studentId);
      GlobalAlert.dismiss();
      if (!mounted) return;
      // Pop the page first — showing another GlobalAlert here would land on
      // top of the navigator stack and the next Navigator.pop would pop the
      // dialog instead of this page, leaving the user stuck on "Deleting...".
      // The caller (choose_students) reloads the list which is enough
      // feedback that the card has been removed.
      Navigator.of(context).pop('deleted');
    } catch (error) {
      GlobalAlert.dismiss();
      if (!mounted) return;
      setState(() => _deleting = false);
      GlobalAlert.showError(
        title: 'Could not delete',
        message: error is Exception ? error.toString() : 'Please try again.',
      );
    }
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool active;
  const _TimelineStep(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.active,
  );
}

class _PendingPulseIcon extends StatefulWidget {
  const _PendingPulseIcon({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  State<_PendingPulseIcon> createState() => _PendingPulseIconState();
}

class _RejectedIcon extends StatelessWidget {
  const _RejectedIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _StudentPendingPageState._roseSurface,
        border: Border.all(color: _StudentPendingPageState._rose, width: 2),
        boxShadow: [
          BoxShadow(
            color: _StudentPendingPageState._rose.withValues(alpha: .18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        LucideIcons.circleX,
        size: 36,
        color: _StudentPendingPageState._rose,
      ),
    );
  }
}

class _PendingPulseIconState extends State<_PendingPulseIcon>
    with TickerProviderStateMixin {
  late final AnimationController _tip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _tip.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Opacity(
                opacity: (1 - t) * .6,
                child: Container(
                  width: 76 + 26 * t,
                  height: 76 + 26 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 2),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(
              scale: .96 + .05 * Curves.easeInOut.transform(_pulse.value),
              child: child,
            ),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.background,
                border: Border.all(color: widget.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .22),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _tip,
            builder: (_, __) {
              final half = (_tip.value * 2) % 1.0;
              final angle =
                  (_tip.value < .5 ? 0 : 3.14159) +
                  Curves.easeInOutCubic.transform(
                        (half * 1.35).clamp(0.0, 1.0),
                      ) *
                      3.14159;
              return Transform.rotate(
                angle: angle,
                child: Icon(
                  LucideIcons.hourglass,
                  size: 36,
                  color: widget.color,
                ),
              );
            },
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, __) => Transform.rotate(
      angle: Curves.easeInOutCubic.transform(_controller.value) * 2 * 3.14159,
      child: Icon(
        LucideIcons.hourglass,
        color: widget.color,
        size: widget.size,
      ),
    ),
  );
}

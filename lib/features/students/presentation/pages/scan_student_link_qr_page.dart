import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/services/session_service.dart';
import '../../data/student_link_request_service.dart';

// ── Palette (matches core/widgets/scanqrcode/scan_qr_code_page.dart) ──────────
const _kNavy = Color(0xFF1E2D5B);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kAmber = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF5F7FA);
const _kBorder = Color(0xFFE8ECF0);
const _kMuted = Color(0xFF9CA3AF);
const _kText = Color(0xFF1F2937);

/// Scans an existing student's profile QR code (see
/// features/home/presentation/pages/profile/profile.dart) and submits a
/// request to link the current parent to that student. The request needs
/// admin approval before it takes effect — this screen only reports whether
/// the request was *submitted*, not whether it was approved.
class ScanStudentLinkQrPage extends StatefulWidget {
  const ScanStudentLinkQrPage({super.key});

  @override
  State<ScanStudentLinkQrPage> createState() => _ScanStudentLinkQrPageState();
}

class _ScanStudentLinkQrPageState extends State<ScanStudentLinkQrPage>
    with SingleTickerProviderStateMixin {
  final _service = StudentLinkRequestService();

  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    torchEnabled: false,
    autoZoom: true,
  );

  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  bool _processing = false;
  _LinkScanResult? _result;

  @override
  void dispose() {
    _scanLine.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);
    _scanner.stop();

    final studentId = _extractStudentId(raw);
    if (!_isValidUuid(studentId)) {
      setState(() {
        _result = _LinkScanResult.error(
          "This doesn't look like a valid student QR code.",
        );
        _processing = false;
      });
      return;
    }

    final session = await SessionService().load();
    final parentId = session?.id.trim() ?? '';
    if (parentId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _result = _LinkScanResult.error(
          'Your session is missing. Please sign in again.',
        );
        _processing = false;
      });
      return;
    }

    try {
      final request = await _service.create(
        studentId: studentId,
        parentId: parentId,
      );
      if (!mounted) return;
      setState(() {
        _result = _LinkScanResult.submitted(request.studentName);
        _processing = false;
      });
    } on StudentLinkRequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _LinkScanResult.conflict(e.message);
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _LinkScanResult.error('Unable to connect. Please try again.');
        _processing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _processing = false;
    });
    _scanner.start();
  }

  String _extractStudentId(String raw) {
    final uuidRe = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );
    final m = uuidRe.firstMatch(raw);
    if (m != null) return m.group(0)!;
    try {
      final j = jsonDecode(raw);
      if (j is Map) return (j['student_id'] ?? j['id'] ?? raw).toString();
    } catch (_) {}
    return raw.trim();
  }

  static bool _isValidUuid(String s) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(s);

  @override
  Widget build(BuildContext context) {
    const scanSize = 272.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Text(
                'Camera error: ${error.errorCode}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC050B14),
                  Color(0x33050B14),
                  Color(0xCC050B14),
                ],
              ),
            ),
          ),
          const CustomPaint(
            painter: _ScannerOverlayPainter(
              scanSize: scanSize,
              radius: 28,
              scrimColor: Color(0x99040A12),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: LucideIcons.arrowLeft,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: LucideIcons.zap,
                        onTap: () => _scanner.toggleTorch(),
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        icon: LucideIcons.switchCamera,
                        onTap: () => _scanner.switchCamera(),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    width: scanSize,
                    height: scanSize,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ScanFramePainter(
                              color: _kBlue,
                              dimColor: Colors.white.withValues(alpha: .28),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _scanLine,
                          builder: (_, __) => Positioned(
                            left: 24,
                            right: 24,
                            top: 22 + (scanSize - 44) * _scanLine.value,
                            child: const _ScanLine(),
                          ),
                        ),
                        Center(
                          child: AnimatedOpacity(
                            opacity: _processing ? 0.0 : 0.35,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .18),
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.userPlus,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_processing)
                          const Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _kBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _processing
                        ? 'Submitting request...'
                        : "Align the student's QR code inside the frame",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF4F8FB),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ask the student\'s other guardian to show their QR code from the Profile page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xB0F4F8FB),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(flex: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60A1320),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.userPlus,
                          size: 16,
                          color: Colors.white.withValues(alpha: .80),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add student • QR link request',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .80),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_result != null)
            _LinkResultOverlay(
              result: _result!,
              onScanAgain: _reset,
              onClose: () =>
                  Navigator.of(context).maybePop(_result!.isSubmitted),
            ).animate().fadeIn(duration: 220.ms).slideY(begin: .04, end: 0),
        ],
      ),
    );
  }
}

// ── Result model ────────────────────────────────────────────────────────────

enum _LinkScanOutcome { submitted, conflict, error }

class _LinkScanResult {
  final _LinkScanOutcome outcome;
  final String message;
  final String studentName;

  const _LinkScanResult._(this.outcome, this.message, this.studentName);

  factory _LinkScanResult.submitted(String studentName) =>
      _LinkScanResult._(_LinkScanOutcome.submitted, '', studentName);

  factory _LinkScanResult.conflict(String message) =>
      _LinkScanResult._(_LinkScanOutcome.conflict, message, '');

  factory _LinkScanResult.error(String message) =>
      _LinkScanResult._(_LinkScanOutcome.error, message, '');

  bool get isSubmitted => outcome == _LinkScanOutcome.submitted;
}

class _LinkResultOverlay extends StatelessWidget {
  final _LinkScanResult result;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;

  const _LinkResultOverlay({
    required this.result,
    required this.onScanAgain,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: .72),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: switch (result.outcome) {
        _LinkScanOutcome.submitted => _SubmittedCard(
          studentName: result.studentName,
          onClose: onClose,
        ),
        _LinkScanOutcome.conflict => _MessageCard(
          icon: LucideIcons.circleAlert,
          color: _kAmber,
          title: "Can't send this request",
          message: result.message,
          buttonLabel: 'Scan Again',
          onTap: onScanAgain,
        ),
        _LinkScanOutcome.error => _MessageCard(
          icon: LucideIcons.circleX,
          color: _kRed,
          title: 'Something went wrong',
          message: result.message,
          buttonLabel: 'Try Again',
          onTap: onScanAgain,
        ),
      },
    );
  }
}

class _SubmittedCard extends StatelessWidget {
  final String studentName;
  final VoidCallback onClose;

  const _SubmittedCard({required this.studentName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGreen.withValues(alpha: .10),
              border: Border.all(
                color: _kGreen.withValues(alpha: .22),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(LucideIcons.circleCheck, color: _kGreen, size: 30),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _kGreen.withValues(alpha: .25)),
            ),
            child: const Text(
              'REQUEST SENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _kGreen,
                letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            studentName.isNotEmpty ? studentName : 'Student',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _kNavy,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: const Text(
              "An admin will review your request. Once approved, this student "
              "will show up in your account.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _kText,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: _CardBtn(label: 'Done', filled: true, onTap: onClose),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .10),
              border: Border.all(
                color: color.withValues(alpha: .22),
                width: 1.5,
              ),
            ),
            child: Center(child: Icon(icon, color: color, size: 30)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _kNavy,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: _kMuted,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          _CardBtn(label: buttonLabel, filled: true, onTap: onTap),
        ],
      ),
    );
  }
}

class _CardBtn extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_CardBtn> createState() => _CardBtnState();
}

class _CardBtnState extends State<_CardBtn> {
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
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? _kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: widget.filled ? Colors.transparent : _kBorder,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: widget.filled ? Colors.white : _kText,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD90A1320),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: const Color(0xFFF4F8FB), size: 22),
        ),
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: const LinearGradient(
          colors: [Color(0x003B82F6), Color(0xFF3B82F6), Color(0x003B82F6)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x883B82F6), blurRadius: 16, spreadRadius: 2),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanSize;
  final double radius;
  final Color scrimColor;

  const _ScannerOverlayPainter({
    required this.scanSize,
    required this.radius,
    required this.scrimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 24),
      width: scanSize,
      height: scanSize,
    );
    final scanRRect = RRect.fromRectAndRadius(
      scanRect,
      Radius.circular(radius),
    );
    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(scanRRect),
    );
    canvas.drawPath(overlay, Paint()..color = scrimColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      scanSize != old.scanSize ||
      radius != old.radius ||
      scrimColor != old.scrimColor;
}

class _ScanFramePainter extends CustomPainter {
  final Color color;
  final Color dimColor;

  const _ScanFramePainter({required this.color, required this.dimColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = dimColor,
    );

    const corner = 56.0;
    const inset = 2.5;
    final path = Path()
      ..moveTo(inset, corner)
      ..lineTo(inset, 28)
      ..quadraticBezierTo(inset, inset, 28, inset)
      ..lineTo(corner, inset)
      ..moveTo(size.width - corner, inset)
      ..lineTo(size.width - 28, inset)
      ..quadraticBezierTo(size.width - inset, inset, size.width - inset, 28)
      ..lineTo(size.width - inset, corner)
      ..moveTo(size.width - inset, size.height - corner)
      ..lineTo(size.width - inset, size.height - 28)
      ..quadraticBezierTo(
        size.width - inset,
        size.height - inset,
        size.width - 28,
        size.height - inset,
      )
      ..lineTo(size.width - corner, size.height - inset)
      ..moveTo(corner, size.height - inset)
      ..lineTo(28, size.height - inset)
      ..quadraticBezierTo(inset, size.height - inset, inset, size.height - 28)
      ..lineTo(inset, size.height - corner);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) =>
      color != old.color || dimColor != old.dimColor;
}

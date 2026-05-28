import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/global_alert_service.dart';

class ScanQrCodePage extends StatefulWidget {
  const ScanQrCodePage({super.key});

  @override
  State<ScanQrCodePage> createState() => _ScanQrCodePageState();
}

class _ScanQrCodePageState extends State<ScanQrCodePage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    torchEnabled: false,
    autoZoom: true,
  );

  late final AnimationController _scanController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  bool _handled = false;

  @override
  void dispose() {
    _scanController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const scanSize = 284.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_handled) return;

              final code = capture.barcodes.first.rawValue;
              if (code == null || code.isEmpty) return;

              _handled = true;
              _showQrResult(code);
            },

            // ✅ FIX: เวอร์ชันที่คุณใช้รับแค่ 2 params
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Camera error: ${error.errorCode}\n${error.toString()}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
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
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.flash_on_rounded,
                        onTap: () => controller.toggleTorch(),
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () => controller.switchCamera(),
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
                              color: const Color(0xFF74F2CE),
                              dimColor: Colors.white.withValues(alpha: .32),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, _) {
                            final y =
                                22 + (scanSize - 44) * _scanController.value;
                            return Positioned(
                              left: 24,
                              right: 24,
                              top: y,
                              child: const _ScanLine(),
                            );
                          },
                        ),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .13),
                              ),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 34,
                              color: Colors.white.withValues(alpha: .42),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Align QR code inside the frame',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFF4F8FB),
                      fontWeight: FontWeight.w800,
                      letterSpacing: .1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep the code steady while the scanner reads it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xB8F4F8FB),
                      fontWeight: FontWeight.w600,
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
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.center_focus_strong_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: .82),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Camera scans automatically',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: .82),
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
        ],
      ),
    );
  }

  Future<void> _showQrResult(String code) async {
    if (!mounted) return;

    GlobalAlert.showLoading(message: 'Validating QR code...');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    GlobalAlert.dismiss();

    if (code.trim().isEmpty) {
      await GlobalAlert.showError(
        title: 'Scan Failed',
        message: 'Unable to read this QR code. Please try again.',
        buttonText: 'Try Again',
        onPressed: _resetScanner,
      );
      return;
    }

    await GlobalAlert.showSuccess(
      title: 'Scan Successful',
      message: 'Your QR code has been scanned successfully.\n\n$code',
      buttonText: 'Scan Again',
      onPressed: _resetScanner,
    );
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() => _handled = false);
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
          colors: [Color(0x0074F2CE), Color(0xFF74F2CE), Color(0x0074F2CE)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xAA74F2CE), blurRadius: 16, spreadRadius: 2),
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

    final fullPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()..addRRect(scanRRect);
    final overlay = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(overlay, Paint()..color = scrimColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return scanSize != oldDelegate.scanSize ||
        radius != oldDelegate.radius ||
        scrimColor != oldDelegate.scrimColor;
  }
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

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;

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

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return color != oldDelegate.color || dimColor != oldDelegate.dimColor;
  }
}

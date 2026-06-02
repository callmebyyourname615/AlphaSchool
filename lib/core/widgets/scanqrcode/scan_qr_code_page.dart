import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../network/api_client.dart';
import '../../network/api_exception.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E2D5B);
const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kBg     = Color(0xFFF5F7FA);
const _kBorder = Color(0xFFE8ECF0);
const _kMuted  = Color(0xFF9CA3AF);
const _kText   = Color(0xFF1F2937);

class ScanQrCodePage extends StatefulWidget {
  const ScanQrCodePage({super.key});

  @override
  State<ScanQrCodePage> createState() => _ScanQrCodePageState();
}

class _ScanQrCodePageState extends State<ScanQrCodePage>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();

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
  _ScanResult? _result;

  @override
  void dispose() {
    _scanLine.dispose();
    _scanner.dispose();
    _api.close();
    super.dispose();
  }

  // ── QR detected ────────────────────────────────────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);
    _scanner.stop();

    final studentId = _extractStudentId(raw);

    // Validate UUID before hitting API
    if (!_isValidUuid(studentId)) {
      setState(() {
        _result = _ScanResult(
          studentId:   raw.length > 20 ? '${raw.substring(0, 20)}...' : raw,
          studentName: '',
          checkIn:     '',
          type:        'ERROR',
          remark:      'This QR code is not a valid student card. Please scan again.',
          isSuccess:   false,
        );
        _processing = false;
      });
      return;
    }

    try {
      final now   = TimeOfDay.now();
      final today = _todayString();
      final timeStr = '${_two(now.hour)}:${_two(now.minute)}';

      final response = await _api.post('/attendances/scan', body: {
        'studentId':      studentId,
        'attendanceDate': today,
        'deviceTime':     timeStr,
      });

      // Try to get student name
      String studentName = studentId.length > 8
          ? '${studentId.substring(0, 8).toUpperCase()}...'
          : studentId;
      try {
        final s = await _api.get('/students/$studentId');
        if (s is Map) {
          final fn = s['first_name']?.toString() ?? '';
          final ln = s['last_name']?.toString()  ?? '';
          final full = '$fn $ln'.trim();
          if (full.isNotEmpty) studentName = full;
        }
      } catch (_) {}

      final type   = (response is Map ? response['type'] : null)?.toString() ?? 'PRESENT';
      final remark = (response is Map ? response['remark'] : null)?.toString() ?? '';
      final checkIn = (response is Map ? response['check_in'] : null)?.toString() ?? timeStr;

      if (!mounted) return;
      setState(() {
        _result = _ScanResult(
          studentId:   studentId,
          studentName: studentName,
          checkIn:     checkIn,
          type:        type,
          remark:      remark,
          isSuccess:   true,
        );
        _processing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 Conflict = already checked in today
      if (e.statusCode == 409) {
        final body = e.body;
        final existingCheckIn = (body is Map ? body['check_in'] : null)?.toString() ?? '';
        final existingType    = (body is Map ? body['type']     : null)?.toString() ?? 'PRESENT';
        final existingRemark  = (body is Map ? body['remark']   : null)?.toString() ?? '';
        setState(() {
          _result = _ScanResult(
            studentId:   studentId,
            studentName: studentName,
            checkIn:     existingCheckIn.length >= 5
                ? existingCheckIn.substring(0, 5)
                : existingCheckIn,
            type:        existingType,
            remark:      existingRemark,
            isSuccess:   false,
            isDuplicate: true,
          );
          _processing = false;
        });
      } else {
        setState(() {
          _result = _ScanResult(
            studentId:   studentId,
            studentName: '',
            checkIn:     '',
            type:        'ERROR',
            remark:      e.message,
            isSuccess:   false,
          );
          _processing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _ScanResult(
          studentId:   studentId,
          studentName: '',
          checkIn:     '',
          type:        'ERROR',
          remark:      'Unable to connect. Please try again.',
          isSuccess:   false,
        );
        _processing = false;
      });
    }
  }

  void _reset() {
    setState(() { _result = null; _processing = false; });
    _scanner.start();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _extractStudentId(String raw) {
    // If raw looks like a UUID, use directly
    final uuidRe = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );
    final m = uuidRe.firstMatch(raw);
    if (m != null) return m.group(0)!;
    // Try JSON
    try {
      final j = jsonDecode(raw);
      if (j is Map) return (j['student_id'] ?? j['id'] ?? raw).toString();
    } catch (_) {}
    return raw.trim();
  }

  static bool _isValidUuid(String s) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(s);

  static String _todayString() {
    final d = DateTime.now();
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const scanSize = 272.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera
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

          // Dark overlay gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC050B14), Color(0x33050B14), Color(0xCC050B14)],
              ),
            ),
          ),

          // Scrim with hole
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
                  // Top bar
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.flash_on_rounded,
                        onTap: () => _scanner.toggleTorch(),
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () => _scanner.switchCamera(),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Scan frame
                  SizedBox(
                    width: scanSize,
                    height: scanSize,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ScanFramePainter(
                              color: const Color(0xFF3B82F6),
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
                                border: Border.all(color: Colors.white.withValues(alpha: .18)),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
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
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Labels
                  Text(
                    _processing ? 'Processing...' : 'Align student QR code inside the frame',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF4F8FB),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The scanner reads automatically on detection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xB0F4F8FB),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Bottom pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xE60A1320),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: .12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.center_focus_strong_rounded,
                            size: 16, color: Colors.white.withValues(alpha: .80)),
                        const SizedBox(width: 8),
                        Text(
                          'Attendance • QR Check-in',
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

          // Result overlay
          if (_result != null)
            _ScanResultOverlay(
              result: _result!,
              onScanAgain: _reset,
              onClose: () => Navigator.of(context).maybePop(_result!.isSuccess),
            ).animate().fadeIn(duration: 220.ms).slideY(begin: .04, end: 0),
        ],
      ),
    );
  }
}

// ── Scan Result Model ──────────────────────────────────────────────────────────

class _ScanResult {
  final String studentId;
  final String studentName;
  final String checkIn;
  final String type;
  final String remark;
  final bool isSuccess;
  final bool isDuplicate;

  const _ScanResult({
    required this.studentId,
    required this.studentName,
    required this.checkIn,
    required this.type,
    required this.remark,
    required this.isSuccess,
    this.isDuplicate = false,
  });
}

// ── Scan Result Overlay ────────────────────────────────────────────────────────

class _ScanResultOverlay extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;

  const _ScanResultOverlay({
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
      child: result.isDuplicate
          ? _DuplicateCard(result: result, onScanAgain: onScanAgain)
          : result.isSuccess
              ? _SuccessCard(result: result, onScanAgain: onScanAgain, onClose: onClose)
              : _ErrorCard(result: result, onScanAgain: onScanAgain),
    );
  }
}

// ── Success Card ───────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;

  const _SuccessCard({
    required this.result,
    required this.onScanAgain,
    required this.onClose,
  });

  Color get _statusColor {
    switch (result.type.toUpperCase()) {
      case 'LATE': return _kOrange;
      default:     return _kGreen;
    }
  }

  String get _statusLabel {
    switch (result.type.toUpperCase()) {
      case 'LATE':    return 'Late';
      case 'PRESENT': return result.remark == 'EARLY' ? 'Early' : 'Present';
      default:        return result.type;
    }
  }

  String get _remarkLabel {
    switch (result.remark.toUpperCase()) {
      case 'EARLY':   return 'Arrived early';
      case 'ON_TIME': return 'On time';
      case 'LATE':    return 'Arrived late';
      default:        return result.remark.isNotEmpty ? result.remark : 'Recorded';
    }
  }

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
          // Icon circle
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor.withValues(alpha: .10),
              border: Border.all(color: _statusColor.withValues(alpha: .22), width: 1.5),
            ),
            child: Center(
              child: FaIcon(
                result.type.toUpperCase() == 'LATE'
                    ? FontAwesomeIcons.clockRotateLeft
                    : FontAwesomeIcons.circleCheck,
                color: _statusColor,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _statusColor.withValues(alpha: .25)),
            ),
            child: Text(
              _statusLabel.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _statusColor,
                letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Student name
          Text(
            result.studentName.isNotEmpty ? result.studentName : 'Student',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _kNavy,
              letterSpacing: -.3,
            ),
          ),

          if (result.studentName.isEmpty || result.studentName.contains('...')) ...[
            const SizedBox(height: 4),
            Text(
              result.studentId.length > 12
                  ? result.studentId.substring(0, 12).toUpperCase()
                  : result.studentId,
              style: const TextStyle(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 18),

          // Info row: check-in time + remark
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    icon: FontAwesomeIcons.clock,
                    label: 'Check-in',
                    value: result.checkIn.length > 5
                        ? result.checkIn.substring(0, 5)
                        : result.checkIn,
                    valueColor: _kNavy,
                  ),
                ),
                Container(width: 1, height: 40, color: _kBorder),
                Expanded(
                  child: _InfoCell(
                    icon: FontAwesomeIcons.tag,
                    label: 'Status',
                    value: _remarkLabel,
                    valueColor: _statusColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Scan method pill
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(FontAwesomeIcons.qrcode, size: 11, color: _kMuted),
              const SizedBox(width: 5),
              const Text(
                'Scanned via QR code',
                style: TextStyle(fontSize: 11.5, color: _kMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Buttons
          Row(
            children: [
              Expanded(
                child: _CardBtn(
                  label: 'Scan Again',
                  filled: false,
                  onTap: onScanAgain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardBtn(
                  label: 'Done',
                  filled: true,
                  onTap: onClose,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Duplicate Card ────────────────────────────────────────────────────────────

class _DuplicateCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onScanAgain;

  const _DuplicateCard({required this.result, required this.onScanAgain});

  String get _remarkLabel {
    switch (result.remark.toUpperCase()) {
      case 'EARLY':   return 'Arrived early';
      case 'ON_TIME': return 'On time';
      case 'LATE':    return 'Arrived late';
      default:        return result.remark.isNotEmpty ? result.remark : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
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
          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: amber.withValues(alpha: .10),
              border: Border.all(color: amber.withValues(alpha: .25), width: 1.5),
            ),
            child: const Center(
              child: FaIcon(FontAwesomeIcons.clockRotateLeft, color: amber, size: 28),
            ),
          ),
          const SizedBox(height: 14),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: amber.withValues(alpha: .25)),
            ),
            child: const Text(
              'ALREADY CHECKED IN',
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                color: amber, letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Student name
          Text(
            result.studentName.isNotEmpty ? result.studentName : 'Student',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: _kNavy, letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 16),

          // Check-in info
          if (result.checkIn.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      icon: FontAwesomeIcons.clock,
                      label: 'Checked in at',
                      value: result.checkIn,
                      valueColor: _kNavy,
                    ),
                  ),
                  if (_remarkLabel.isNotEmpty) ...[
                    Container(width: 1, height: 40, color: _kBorder),
                    Expanded(
                      child: _InfoCell(
                        icon: FontAwesomeIcons.tag,
                        label: 'Status',
                        value: _remarkLabel,
                        valueColor: amber,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          Text(
            'This QR code has already been scanned today.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: _kMuted,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _CardBtn(label: 'Scan Next Student', filled: true, onTap: onScanAgain),
        ],
      ),
    );
  }
}

// ── Error Card ─────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onScanAgain;

  const _ErrorCard({required this.result, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFEF4444);
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
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: red.withValues(alpha: .10),
              border: Border.all(color: red.withValues(alpha: .22), width: 1.5),
            ),
            child: const Center(
              child: FaIcon(FontAwesomeIcons.circleXmark, color: red, size: 30),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Check-in Failed',
            style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900,
              color: _kNavy, letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.remark.isNotEmpty ? result.remark : 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _kMuted, fontWeight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 22),
          _CardBtn(label: 'Try Again', filled: true, onTap: onScanAgain),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FaIcon(icon, size: 14, color: _kMuted),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10.5, color: _kMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: valueColor),
        ),
      ],
    );
  }
}

class _CardBtn extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _CardBtn({required this.label, required this.filled, required this.onTap});

  @override
  State<_CardBtn> createState() => _CardBtnState();
}

class _CardBtnState extends State<_CardBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
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
            border: Border.all(color: widget.filled ? Colors.transparent : _kBorder),
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
          width: 46, height: 46,
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
    final scanRRect = RRect.fromRectAndRadius(scanRect, Radius.circular(radius));
    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(scanRRect),
    );
    canvas.drawPath(overlay, Paint()..color = scrimColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      scanSize != old.scanSize || radius != old.radius || scrimColor != old.scrimColor;
}

class _ScanFramePainter extends CustomPainter {
  final Color color;
  final Color dimColor;

  const _ScanFramePainter({required this.color, required this.dimColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    canvas.drawRRect(rrect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = dimColor);

    const corner = 56.0;
    const inset  = 2.5;
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
      ..quadraticBezierTo(size.width - inset, size.height - inset, size.width - 28, size.height - inset)
      ..lineTo(size.width - corner, size.height - inset)
      ..moveTo(corner, size.height - inset)
      ..lineTo(28, size.height - inset)
      ..quadraticBezierTo(inset, size.height - inset, inset, size.height - 28)
      ..lineTo(inset, size.height - corner);

    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) =>
      color != old.color || dimColor != old.dimColor;
}

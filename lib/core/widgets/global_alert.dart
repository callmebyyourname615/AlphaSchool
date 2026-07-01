import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../constants/app_colors.dart';

enum GlobalAlertType { success, error, warning, info, confirm, loading }

class GlobalAlertDialog extends StatelessWidget {
  final GlobalAlertType type;
  final String? title;
  final String message;
  final String primaryText;
  final String secondaryText;
  final IconData? icon;
  final Color? confirmColor;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  const GlobalAlertDialog({
    super.key,
    required this.type,
    this.title,
    required this.message,
    required this.primaryText,
    required this.secondaryText,
    this.icon,
    this.confirmColor,
    this.onPrimary,
    this.onSecondary,
  });

  bool get _isConfirm => type == GlobalAlertType.confirm;
  bool get _isLoading => type == GlobalAlertType.loading;

  @override
  Widget build(BuildContext context) {
    final spec = _AlertSpec.fromType(type, customIcon: icon);
    final iconColor = (_isConfirm && confirmColor != null)
        ? confirmColor!
        : spec.color;
    final media = MediaQuery.of(context);
    final maxW = media.size.width - 48;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW.clamp(280.0, 360.0)),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: GlobalAlertColors.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: GlobalAlertColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E2D5B).withValues(alpha: .10),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Subtle top glow — much softer than dark version
                    Positioned(
                      top: -20,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.8),
                            radius: 0.9,
                            colors: [
                              spec.color.withValues(alpha: .08),
                              spec.color.withValues(alpha: .02),
                              Colors.transparent,
                            ],
                            stops: const [0, .5, 1],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusIcon(
                            spec: spec,
                            isLoading: _isLoading,
                            colorOverride: iconColor,
                          ),
                          const SizedBox(height: 20),
                          if ((title ?? '').trim().isNotEmpty) ...[
                            Text(
                              title!.trim(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: GlobalAlertColors.textPrimary,
                                fontSize: 19,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GlobalAlertColors.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(height: 24),
                            if (_isConfirm)
                              Row(
                                children: [
                                  Expanded(
                                    child: _AlertButton(
                                      text: secondaryText,
                                      onTap: onSecondary,
                                      outlined: true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _AlertButton(
                                      text: primaryText,
                                      onTap: onPrimary,
                                      color:
                                          confirmColor ??
                                          GlobalAlertColors.primaryAction,
                                    ),
                                  ),
                                ],
                              )
                            else
                              _AlertButton(
                                text: primaryText,
                                onTap: onPrimary,
                                color: spec.buttonColor,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final _AlertSpec spec;
  final bool isLoading;
  final Color? colorOverride;

  const _StatusIcon({
    required this.spec,
    required this.isLoading,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorOverride ?? spec.color;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .20), width: 1.5),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                ),
              )
            : Icon(spec.faIcon, color: color, size: 30),
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final bool outlined;

  const _AlertButton({
    required this.text,
    required this.onTap,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = outlined
        ? GlobalAlertColors.secondaryBg
        : (color ?? GlobalAlertColors.primaryAction);
    final border = outlined ? GlobalAlertColors.border : Colors.transparent;
    final fg = outlined ? GlobalAlertColors.textPrimary : Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertSpec {
  final Color color;
  final Color buttonColor;
  final IconData faIcon;

  const _AlertSpec({
    required this.color,
    required this.buttonColor,
    required this.faIcon,
  });

  factory _AlertSpec.fromType(GlobalAlertType type, {IconData? customIcon}) {
    return switch (type) {
      GlobalAlertType.success => _AlertSpec(
        color: GlobalAlertColors.successGreen,
        buttonColor: GlobalAlertColors.primaryAction,
        faIcon: customIcon ?? LucideIcons.circleCheck,
      ),
      GlobalAlertType.error => _AlertSpec(
        color: GlobalAlertColors.errorPink,
        buttonColor: GlobalAlertColors.errorPink,
        faIcon: customIcon ?? LucideIcons.circleX,
      ),
      GlobalAlertType.warning => _AlertSpec(
        color: GlobalAlertColors.warningAmber,
        buttonColor: GlobalAlertColors.primaryAction,
        faIcon: customIcon ?? LucideIcons.circle,
      ),
      GlobalAlertType.info => _AlertSpec(
        color: GlobalAlertColors.infoBlue,
        buttonColor: GlobalAlertColors.primaryAction,
        faIcon: customIcon ?? LucideIcons.info,
      ),
      GlobalAlertType.confirm => _AlertSpec(
        color: GlobalAlertColors.infoBlue,
        buttonColor: GlobalAlertColors.primaryAction,
        faIcon: customIcon ?? LucideIcons.circleHelp,
      ),
      GlobalAlertType.loading => _AlertSpec(
        color: GlobalAlertColors.infoBlue,
        buttonColor: GlobalAlertColors.primaryAction,
        faIcon: customIcon ?? LucideIcons.hourglass,
      ),
    };
  }
}

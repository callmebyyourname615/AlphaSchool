import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum GlobalAlertType { success, error, warning, info, confirm, loading }

class GlobalAlertDialog extends StatelessWidget {
  final GlobalAlertType type;
  final String? title;
  final String message;
  final String primaryText;
  final String secondaryText;
  final IconData? icon;
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
    this.onPrimary,
    this.onSecondary,
  });

  bool get _isConfirm => type == GlobalAlertType.confirm;
  bool get _isLoading => type == GlobalAlertType.loading;

  @override
  Widget build(BuildContext context) {
    final spec = _AlertSpec.fromType(type, customIcon: icon);
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width - 48;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth.clamp(280.0, 380.0)),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: GlobalAlertColors.darkCard,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 34,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -1.05),
                            radius: .95,
                            colors: [
                              spec.color.withValues(alpha: .36),
                              spec.color.withValues(alpha: .10),
                              Colors.transparent,
                            ],
                            stops: const [0, .42, 1],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusIcon(spec: spec, isLoading: _isLoading),
                          const SizedBox(height: 18),
                          if ((title ?? '').trim().isNotEmpty) ...[
                            Text(
                              title!.trim(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: GlobalAlertColors.textPrimary,
                                fontSize: 21,
                                height: 1.18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GlobalAlertColors.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(height: 22),
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _AlertButton(
                                      text: primaryText,
                                      onTap: onPrimary,
                                      color: GlobalAlertColors.primaryDarkBlue,
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

  const _StatusIcon({required this.spec, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: spec.color,
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: .42),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  color: Colors.white,
                ),
              )
            : Icon(spec.icon, color: Colors.white, size: 42),
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
        ? Colors.transparent
        : (color ?? GlobalAlertColors.darkButton);
    final border = outlined
        ? Colors.white.withValues(alpha: .15)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: outlined
                  ? GlobalAlertColors.textPrimary.withValues(alpha: .88)
                  : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
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
  final IconData icon;

  const _AlertSpec({
    required this.color,
    required this.buttonColor,
    required this.icon,
  });

  factory _AlertSpec.fromType(GlobalAlertType type, {IconData? customIcon}) {
    return switch (type) {
      GlobalAlertType.success => _AlertSpec(
        color: GlobalAlertColors.successGreen,
        buttonColor: GlobalAlertColors.primaryDarkBlue,
        icon: customIcon ?? Icons.check_rounded,
      ),
      GlobalAlertType.error => _AlertSpec(
        color: GlobalAlertColors.errorPink,
        buttonColor: GlobalAlertColors.darkButton,
        icon: customIcon ?? Icons.priority_high_rounded,
      ),
      GlobalAlertType.warning => _AlertSpec(
        color: GlobalAlertColors.warningAmber,
        buttonColor: GlobalAlertColors.primaryDarkBlue,
        icon: customIcon ?? Icons.warning_amber_rounded,
      ),
      GlobalAlertType.info => _AlertSpec(
        color: GlobalAlertColors.infoBlue,
        buttonColor: GlobalAlertColors.primaryDarkBlue,
        icon: customIcon ?? Icons.info_outline_rounded,
      ),
      GlobalAlertType.confirm => _AlertSpec(
        color: GlobalAlertColors.warningAmber,
        buttonColor: GlobalAlertColors.primaryDarkBlue,
        icon: customIcon ?? Icons.help_outline_rounded,
      ),
      GlobalAlertType.loading => _AlertSpec(
        color: GlobalAlertColors.infoBlue,
        buttonColor: GlobalAlertColors.primaryDarkBlue,
        icon: customIcon ?? Icons.hourglass_empty_rounded,
      ),
    };
  }
}

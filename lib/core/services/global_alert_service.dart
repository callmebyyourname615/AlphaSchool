import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../widgets/global_alert.dart';

class GlobalAlert {
  GlobalAlert._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _loadingVisible = false;

  static BuildContext? get _context => navigatorKey.currentContext;

  static Future<void> showError({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    bool dismissible = true,
    IconData? icon,
  }) {
    return _show(
      type: GlobalAlertType.error,
      title: title,
      message: message,
      primaryText: buttonText,
      onPrimary: onPressed,
      dismissible: dismissible,
      icon: icon,
    );
  }

  static Future<void> showSuccess({
    required String title,
    required String message,
    String buttonText = 'Continue',
    VoidCallback? onPressed,
    bool dismissible = true,
    IconData? icon,
  }) {
    return _show(
      type: GlobalAlertType.success,
      title: title,
      message: message,
      primaryText: buttonText,
      onPrimary: onPressed,
      dismissible: dismissible,
      icon: icon,
    );
  }

  static Future<void> showWarning({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    bool dismissible = true,
    IconData? icon,
  }) {
    return _show(
      type: GlobalAlertType.warning,
      title: title,
      message: message,
      primaryText: buttonText,
      onPrimary: onPressed,
      dismissible: dismissible,
      icon: icon,
    );
  }

  static Future<void> showInfo({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    bool dismissible = true,
    IconData? icon,
  }) {
    return _show(
      type: GlobalAlertType.info,
      title: title,
      message: message,
      primaryText: buttonText,
      onPrimary: onPressed,
      dismissible: dismissible,
      icon: icon,
    );
  }

  static Future<bool?> showConfirmation({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool dismissible = true,
    IconData? icon,
  }) {
    return _show<bool>(
      type: GlobalAlertType.confirm,
      title: title,
      message: message,
      primaryText: confirmText,
      secondaryText: cancelText,
      onPrimary: () {
        onConfirm?.call();
      },
      onSecondary: () {
        onCancel?.call();
      },
      dismissible: dismissible,
      icon: icon,
      primaryResult: true,
      secondaryResult: false,
    );
  }

  static Future<void> showLoading({String message = 'Please wait...'}) async {
    if (_loadingVisible) return;
    final context = _context;
    if (context == null) return;

    _loadingVisible = true;
    unawaited(
      _show(
        type: GlobalAlertType.loading,
        title: null,
        message: message,
        primaryText: '',
        dismissible: false,
      ).whenComplete(() => _loadingVisible = false),
    );
  }

  static void dismiss() {
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return;
    navigator.pop();
  }

  static Future<T?> _show<T>({
    required GlobalAlertType type,
    required String? title,
    required String message,
    required String primaryText,
    String secondaryText = 'Cancel',
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
    bool dismissible = true,
    IconData? icon,
    T? primaryResult,
    T? secondaryResult,
  }) async {
    final context = _context;
    if (context == null) return null;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: 'Global alert',
      barrierColor: GlobalAlertColors.overlay,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return GlobalAlertDialog(
          type: type,
          title: title,
          message: message,
          primaryText: primaryText,
          secondaryText: secondaryText,
          icon: icon,
          onPrimary: () {
            Navigator.of(context).pop(primaryResult);
            onPrimary?.call();
          },
          onSecondary: () {
            Navigator.of(context).pop(secondaryResult);
            onSecondary?.call();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final fade = Tween<double>(begin: 0, end: 1).animate(curved);
        final scale = Tween<double>(begin: .94, end: 1).animate(curved);
        final slide = Tween<Offset>(
          begin: const Offset(0, .035),
          end: Offset.zero,
        ).animate(curved);

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

void unawaited(Future<void> future) {}

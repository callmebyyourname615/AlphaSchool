import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppPageTemplate extends StatelessWidget {
  final String title;
  final Widget child;
  final String backgroundAsset;

  /// ถ้าส่งมา จะใช้ action นี้แทน pop
  final VoidCallback? onBack;

  final bool scrollable;
  final EdgeInsets contentPadding;
  final bool animate;
  final bool showBack;

  final bool premiumDark;
  final Gradient? premiumDarkGradient;

  /// ✅ ถ้าส่งมา จะกด back แล้วไป route นี้แบบ removeUntil
  final String? backToRouteName;

  const AppPageTemplate({
    super.key,
    required this.title,
    required this.child,
    required this.backgroundAsset,
    this.onBack,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.animate = true,
    this.showBack = true,
    this.premiumDark = true,
    this.premiumDarkGradient,
    this.backToRouteName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ===== Background (image only) =====
    Widget bg = Positioned.fill(
      child: Image.asset(
        backgroundAsset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
      ),
    );

    if (animate) {
      bg = bg
          .animate()
          .fadeIn(duration: 420.ms)
          .scale(
            begin: const Offset(1.02, 1.02),
            end: const Offset(1, 1),
            duration: 650.ms,
            curve: Curves.easeOutCubic,
          );
    }

    // ✅ back behavior (ใช้กับปุ่มใน AppBar)
    VoidCallback backAction() {
      if (onBack != null) return onBack!;
      if (backToRouteName != null) {
        return () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(backToRouteName!, (r) => false);
      }
      return () => Navigator.maybePop(context);
    }

    // ✅ system back/gesture behavior (ให้เหมือน backAction)
    Future<bool> onWillPop() async {
      if (onBack != null) {
        onBack!.call();
        return false;
      }
      if (backToRouteName != null) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(backToRouteName!, (r) => false);
        return false;
      }
      return true;
    }

    // ===== TopBar =====
    Widget topBar = AppTemplateTopBar(
      title: title,
      showBack: showBack,
      onBack: backAction(),
    );

    if (animate) {
      topBar = topBar
          .animate()
          .fadeIn(duration: 260.ms)
          .slideY(
            begin: -0.25,
            end: 0,
            duration: 520.ms,
            curve: Curves.easeOutCubic,
          );
    }

    // ===== Big Container Decoration =====
    final Gradient darkGrad =
        premiumDarkGradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2B5B), Color(0xFF071A33), Color(0xFF060B16)],
        );

    final BoxDecoration bigDeco = (isDark && premiumDark)
        ? BoxDecoration(
            gradient: darkGrad,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 34,
                offset: const Offset(0, 18),
                color: Colors.black.withOpacity(.45),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                offset: const Offset(0, 18),
                color: Colors.black.withOpacity(.10),
              ),
            ],
          );

    Widget bigContainer = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        width: double.infinity,
        decoration: bigDeco,
        child: scrollable
            ? SingleChildScrollView(padding: contentPadding, child: child)
            : Padding(padding: contentPadding, child: child),
      ),
    );

    if (animate) {
      bigContainer = bigContainer
          .animate()
          .fadeIn(duration: 320.ms, delay: 120.ms)
          .slideY(
            begin: 0.10,
            end: 0,
            duration: 650.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF070B12)
            : const Color(0xFFF4F6FF),
        body: Stack(
          children: [
            bg,
            SafeArea(
              // ✅ ไม่เว้นขอบล่าง เพื่อให้ card ลงไปเต็มล่าง
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: topBar,
                  ),
                  const SizedBox(height: 14),

                  // ✅ Expanded ให้กินพื้นที่ถึงล่างสุด (ไม่มีช่องว่างท้าย)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: bigContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppTemplateTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final bool showBack;

  const AppTemplateTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (showBack)
            InkResponse(
              onTap: onBack,
              radius: 26,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.12)),
                ),
                child: const Icon(
                  LucideIcons.chevronLeft,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            )
          else
            const SizedBox(width: 40),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

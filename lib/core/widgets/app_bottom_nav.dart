import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';

class AppBottomNavItem {
  final IconData icon;
  final String label;

  const AppBottomNavItem({required this.icon, required this.label});
}

class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<AppBottomNavItem> items;

  /// NOTE: แบบรูปตัวอย่าง “ไม่มีปุ่มกลาง”
  /// เลยจะไม่ใช้ 2 ตัวนี้แล้ว (ยังคงไว้กันโค้ดเดิมพัง)
  final VoidCallback? onPlusPressed;
  final IconData plusIcon;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.items,
    this.onPlusPressed,
    this.plusIcon = LucideIcons.qrCode,
  }) : assert(items.length >= 2, "Need at least 2 menus.");

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final count = widget.items.length;

    // ===== Look like reference image =====
    const barH = 74.0;

    // ✅ ถ้ามี 5 เมนู ลดขนาดลงนิดนึงให้พอดี
    final iconSize = count >= 5 ? 22.0 : 24.0;
    final labelSize = count >= 5 ? 10.5 : 11.0;

    final bg = isDark ? AppColors.dark.withOpacity(.92) : Colors.white;

    final topStroke = isDark
        ? Colors.white.withOpacity(.14)
        : Colors.black.withOpacity(.10);

    final activeIcon = isDark ? Colors.white : const Color(0xFF111827);
    final inactiveIcon = isDark
        ? Colors.white.withOpacity(.55)
        : Colors.black.withOpacity(.45);

    final activeLabel = isDark ? Colors.white : const Color(0xFF111827);
    final inactiveLabel = isDark
        ? Colors.white.withOpacity(.55)
        : Colors.black.withOpacity(.50);

    final shadowColor = Colors.black.withOpacity(isDark ? .20 : .08);

    return SafeArea(
      top: false,
      child: Container(
        height: barH,
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: topStroke, width: 1)),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, -6),
              color: shadowColor,
            ),
          ],
        ),
        child: Row(
          children: List.generate(count, (i) {
            final item = widget.items[i];
            return Expanded(
              child: _NavItem(
                active: widget.currentIndex == i,
                icon: item.icon,
                label: item.label,
                iconSize: iconSize,
                labelSize: labelSize,
                activeIcon: activeIcon,
                inactiveIcon: inactiveIcon,
                activeLabel: activeLabel,
                inactiveLabel: inactiveLabel,
                onTap: () => _tap(i),
              ),
            );
          }),
        ),
      ).animate().fadeIn(duration: 200.ms).slideY(begin: .20, end: 0),
    );
  }

  void _tap(int i) {
    if (i == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onChanged(i);
  }
}

class _NavItem extends StatefulWidget {
  final bool active;
  final IconData icon;
  final String label;

  final double iconSize;
  final double labelSize;

  final Color activeIcon;
  final Color inactiveIcon;
  final Color activeLabel;
  final Color inactiveLabel;

  final VoidCallback onTap;

  const _NavItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.labelSize,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconC = widget.active ? widget.activeIcon : widget.inactiveIcon;
    final labelC = widget.active ? widget.activeLabel : widget.inactiveLabel;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: 120.ms,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: widget.iconSize, color: iconC)
                      .animate(target: widget.active ? 1 : 0)
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.06, 1.06),
                        duration: 160.ms,
                        curve: Curves.easeOut,
                      ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.labelSize,
                      height: 1.0,
                      color: labelC,
                      fontWeight: widget.active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

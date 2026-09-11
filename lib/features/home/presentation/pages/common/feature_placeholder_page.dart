import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../core/theme/app_colors.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final cs = t.colorScheme;

    final titleColor = isDark ? Colors.white : AppColors.blue500;
    final muted = isDark
        ? AppColors.grayUltraLight.withValues(alpha: .80)
        : AppColors.blue500.withValues(alpha: .62);

    final cardBg = isDark
        ? AppColors.blue500.withValues(alpha: .10)
        : cs.surface;
    final border = isDark
        ? Colors.white.withValues(alpha: .10)
        : AppColors.slate.withValues(alpha: .12);

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
      body: Center(
        child:
            Container(
                  width: 340,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 52, color: titleColor),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: t.textTheme.titleLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: t.textTheme.bodyMedium?.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 220.ms)
                .slideY(begin: .08, end: 0, duration: 220.ms),
      ),
    );
  }
}

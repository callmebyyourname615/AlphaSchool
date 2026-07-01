import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/login_page.dart';

class YearPickerPage extends StatefulWidget {
  const YearPickerPage({super.key});

  @override
  State<YearPickerPage> createState() => _YearPickerPageState();
}

class _YearPickerPageState extends State<YearPickerPage> {
  static const _years = ['2024-2025', '2025-2026', '2026-2027'];
  int? _selectedIndex;
  bool _navigating = false;

  Future<void> _selectAndGo(int index) async {
    if (_navigating) return;
    setState(() {
      _navigating = true;
      _selectedIndex = index;
    });
    HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(_route(LoginPage(academicYear: _years[index])));
    if (!mounted) return;
    setState(() {
      _navigating = false;
      _selectedIndex = null;
    });
  }

  PageRouteBuilder<void> _route(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.blue300,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(LucideIcons.school, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Choose academic year',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.dark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select the school year you want to access.',
                    style: TextStyle(
                      color: AppColors.gray,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _years.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _YearOption(
                          year: _years[index],
                          selected: _selectedIndex == index,
                          disabled: _navigating,
                          onTap: () => _selectAndGo(index),
                        );
                      },
                    ),
                  ),
                  if (_navigating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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

class _YearOption extends StatelessWidget {
  final String year;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _YearOption({
    required this.year,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.blue300 : const Color(0xFFE3E9F2);

    return Material(
      color: selected ? const Color(0xFFF1F6FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.calendarDays,
                size: 21,
                color: selected ? AppColors.blue300 : AppColors.gray,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  year,
                  style: TextStyle(
                    color: selected ? AppColors.blue300 : AppColors.dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.arrowRight,
                size: selected ? 22 : 16,
                color: selected ? AppColors.blue300 : AppColors.grayLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

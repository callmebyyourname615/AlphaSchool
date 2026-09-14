import 'package:flutter/material.dart';
import '../../../../core/theme/app_icons.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/login_page.dart';

class YearPickerPage extends StatefulWidget {
  const YearPickerPage({super.key});

  @override
  State<YearPickerPage> createState() => _YearPickerPageState();
}

class _YearPickerPageState extends State<YearPickerPage> {
  static const _years = ['2026-2027'];
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
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.blue300,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          LucideIcons.school,
                          color: Colors.white,
                        ),
                      ),
                      _LanguageSwitcher(
                        selectedLanguageCode: languageCode,
                        disabled: _navigating,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.t('chooseAcademicYearTitle'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.dark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('chooseAcademicYearSubtitle'),
                    style: const TextStyle(
                      color: AppColors.gray,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Expanded(
                    child: ListView(
                      children: [
                        for (var index = 0; index < _years.length; index++) ...[
                          if (index > 0) const SizedBox(height: 12),
                          _YearOption(
                            year: _years[index],
                            selected: _selectedIndex == index,
                            disabled: _navigating,
                            onTap: () => _selectAndGo(index),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const _TemporaryPlatformNotice(),
                      ],
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

class _LanguageSwitcher extends StatelessWidget {
  final String selectedLanguageCode;
  final bool disabled;

  const _LanguageSwitcher({
    required this.selectedLanguageCode,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = _LanguageOption.fromCode(selectedLanguageCode);

    return PopupMenuButton<String>(
      enabled: !disabled,
      tooltip: l10n.t('language'),
      color: Colors.white,
      elevation: 8,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE3E9F2)),
      ),
      onSelected: (code) => AppLocaleController.setLocale(Locale(code)),
      itemBuilder: (context) {
        return _LanguageOption.options.map((option) {
          final selected = option.code == selectedLanguageCode;
          return PopupMenuItem<String>(
            value: option.code,
            child: Row(
              children: [
                _FlagImage(asset: option.asset, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.t(option.labelKey),
                    style: TextStyle(
                      color: AppColors.dark,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    LucideIcons.check,
                    size: 18,
                    color: AppColors.blue300,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 8, right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.dark, width: 1.4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlagImage(asset: current.asset, size: 34),
            const SizedBox(width: 10),
            Text(
              l10n.t(current.labelKey),
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronDown,
              size: 19,
              color: AppColors.dark,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption {
  final String code;
  final String labelKey;
  final String asset;

  const _LanguageOption({
    required this.code,
    required this.labelKey,
    required this.asset,
  });

  static const options = <_LanguageOption>[
    _LanguageOption(
      code: 'lo',
      labelKey: 'lao',
      asset: 'assets/images/flags/laos.png',
    ),
    _LanguageOption(
      code: 'en',
      labelKey: 'english',
      asset: 'assets/images/flags/english.png',
    ),
  ];

  static _LanguageOption fromCode(String code) {
    for (final option in options) {
      if (option.code == code) return option;
    }
    return options.last;
  }
}

class _FlagImage extends StatelessWidget {
  final String asset;
  final double size;

  const _FlagImage({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class _TemporaryPlatformNotice extends StatefulWidget {
  const _TemporaryPlatformNotice();

  @override
  State<_TemporaryPlatformNotice> createState() =>
      _TemporaryPlatformNoticeState();
}

class _TemporaryPlatformNoticeState extends State<_TemporaryPlatformNotice>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final borderColor = AppColors.slate.withValues(alpha: .12);
    final iconSurface = AppColors.blue300.withValues(alpha: .08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.grayUltraLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.info,
                        color: AppColors.blue300,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.t('temporaryPlatformNoticeButton'),
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.dark,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        LucideIcons.chevronDown,
                        color: AppColors.gray,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 14),
                      Text(
                        l10n.t('temporaryPlatformNoticeTitle'),
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.dark,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('temporaryPlatformNoticeBody'),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.gray,
                          height: 1.58,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.t('temporaryPlatformNoticeStoreLabel'),
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.dark,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Image.asset(
                          'assets/images/app_download_badges.png',
                          width: 284,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
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

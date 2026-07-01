import 'package:alpha_school/features/home/presentation/pages/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ✅ same AppTheme.mode as Year Picker
import '../../../../../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.title = 'Settings'});

  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ✅ Light palette (MUST remain exactly as your original)
  static const _bg = Colors.white;
  static const _titleColor = Color(0xFF111827);
  static const _textColor = Color(0xFF6B7280);
  static const _iconColor = Color(0xFF111827);
  static const _chevColor = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFF1F5F9);

  /// 'lo' or 'en'
  String _lang = 'lo';

  void _back() => Navigator.of(context).maybePop();

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
  }

  void _setTheme(bool isDark) {
    AppTheme.mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final isDarkMode = mode == ThemeMode.dark;
        final p = _SettingsPalette.from(isDarkMode);

        final tiles = <Widget>[
          _SettingsTile(
            icon: LucideIcons.user,
            label: 'Account',
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 26,
              color: p.chevColor,
            ),
            onTap: _openProfile,
            iconColor: p.iconColor.withOpacity(.75),
            textColor: p.textColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(height: 1, color: p.divider),
          ),

          // ✅ toggle: updates AppTheme.mode, and THIS PAGE also turns dark
          _SettingsSwitchTile(
            icon: LucideIcons.moon,
            label: isDarkMode ? 'Dark mode' : 'Light mode',
            value: isDarkMode,
            onChanged: _setTheme,
            iconColor: p.iconColor.withOpacity(.75),
            textColor: p.textColor,
          ),

          const SizedBox(height: 14),

          _SettingsTile(
            icon: LucideIcons.globe,
            label: 'Language',
            valueText: _lang == 'lo' ? 'Laos' : 'English',
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 26,
              color: p.chevColor,
            ),
            onTap: _openLanguageSheet,
            iconColor: p.iconColor.withOpacity(.75),
            textColor: p.textColor,
          ),

          const SizedBox(height: 18),

          _LogoutButton(
            onTap: () {
              // TODO: your logout logic
            },
            bgColor: p.logoutBg,
            borderColor: p.logoutBorder,
          ),
        ];

        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                      child: _TopBar(
                        title: widget.title,
                        onBack: _back,
                        titleColor: p.titleColor,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 260.ms)
                    .slideY(begin: -0.10, end: 0, duration: 320.ms),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    children: [
                      _SectionCard(
                        bgColor: p.cardBg,
                        borderColor: p.cardBorder,
                        shadowColor: p.cardShadow,
                        child: Column(
                          children: [
                            for (int i = 0; i < tiles.length; i++)
                              tiles[i]
                                  .animate()
                                  .fadeIn(
                                    delay: (80 + (i * 55)).ms,
                                    duration: 240.ms,
                                  )
                                  .slideY(
                                    begin: 0.10,
                                    end: 0,
                                    delay: (80 + (i * 55)).ms,
                                    duration: 300.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 120.ms, duration: 280.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openLanguageSheet() {
    final isDarkMode = AppTheme.mode.value == ThemeMode.dark;
    final p = _SettingsPalette.from(isDarkMode);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        final items = [
          _LangItem(
            code: 'lo',
            title: 'Laos',
            flag: const Text('🇱🇦', style: TextStyle(fontSize: 22)),
          ),
          _LangItem(
            code: 'en',
            title: 'English',
            flag: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
          ),
        ];

        return _BottomSheetShell(
          title: 'Select language',
          bgColor: p.sheetBg,
          borderColor: p.sheetBorder,
          titleColor: p.sheetTitle,
          closeColor: p.sheetClose,
          dragColor: p.sheetDrag,
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++)
                _LanguageRow(
                      item: items[i],
                      selected: _lang == items[i].code,
                      onTap: () {
                        setState(() => _lang = items[i].code);
                        Navigator.of(context).pop();
                      },
                      selectedBorder: p.langSelectedBorder,
                      border: p.langBorder,
                      selectedBg: p.langSelectedBg,
                      bg: p.langBg,
                      textColor: p.langText,
                      checkColor: p.langCheck,
                    )
                    .animate()
                    .fadeIn(delay: (60 + i * 70).ms, duration: 220.ms)
                    .slideY(
                      begin: 0.12,
                      end: 0,
                      delay: (60 + i * 70).ms,
                      duration: 280.ms,
                      curve: Curves.easeOutCubic,
                    ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

// =====================
// Palette (light = original, dark = only colors to look dark)
// =====================

class _SettingsPalette {
  const _SettingsPalette({
    required this.bg,
    required this.titleColor,
    required this.textColor,
    required this.iconColor,
    required this.chevColor,
    required this.divider,
    required this.cardBg,
    required this.cardBorder,
    required this.cardShadow,
    required this.sheetBg,
    required this.sheetBorder,
    required this.sheetTitle,
    required this.sheetClose,
    required this.sheetDrag,
    required this.langSelectedBorder,
    required this.langBorder,
    required this.langSelectedBg,
    required this.langBg,
    required this.langText,
    required this.langCheck,
    required this.logoutBg,
    required this.logoutBorder,
  });

  final Color bg;
  final Color titleColor;
  final Color textColor;
  final Color iconColor;
  final Color chevColor;
  final Color divider;

  final Color cardBg;
  final Color cardBorder;
  final Color cardShadow;

  final Color sheetBg;
  final Color sheetBorder;
  final Color sheetTitle;
  final Color sheetClose;
  final Color sheetDrag;

  final Color langSelectedBorder;
  final Color langBorder;
  final Color langSelectedBg;
  final Color langBg;
  final Color langText;
  final Color langCheck;

  final Color logoutBg;
  final Color logoutBorder;

  factory _SettingsPalette.from(bool isDark) {
    if (!isDark) {
      // ✅ EXACTLY your original light style
      return const _SettingsPalette(
        bg: _SettingsPageState._bg,
        titleColor: _SettingsPageState._titleColor,
        textColor: _SettingsPageState._textColor,
        iconColor: _SettingsPageState._iconColor,
        chevColor: _SettingsPageState._chevColor,
        divider: _SettingsPageState._divider,
        cardBg: Colors.white,
        cardBorder: Color(0xFFF1F5F9),
        cardShadow: Color(0x0A111827),
        sheetBg: Colors.white,
        sheetBorder: Color(0xFFF1F5F9),
        sheetTitle: Color(0xFF111827),
        sheetClose: Color(0xFF9CA3AF),
        sheetDrag: Color(0xFFE5E7EB),
        langSelectedBorder: Color(0xFF111827),
        langBorder: Color(0xFFF1F5F9),
        langSelectedBg: Color(0xFFF9FAFB),
        langBg: Colors.white,
        langText: Color(0xFF111827),
        langCheck: Color(0xFF111827),
        logoutBg: Color(0xFFFEF2F2),
        logoutBorder: Color(0xFFFEE2E2),
      );
    }

    // ✅ Dark colors only (layout remains identical)
    return _SettingsPalette(
      bg: const Color(0xFF0B1220),
      titleColor: Colors.white.withOpacity(.95),
      textColor: Colors.white.withOpacity(.75),
      iconColor: Colors.white.withOpacity(.90),
      chevColor: Colors.white.withOpacity(.55),
      divider: Colors.white.withOpacity(.10),
      cardBg: const Color(0xFF0F172A),
      cardBorder: Colors.white.withOpacity(.10),
      cardShadow: Colors.black.withOpacity(.35),
      sheetBg: const Color(0xFF0F172A),
      sheetBorder: Colors.white.withOpacity(.12),
      sheetTitle: Colors.white.withOpacity(.92),
      sheetClose: Colors.white.withOpacity(.60),
      sheetDrag: Colors.white.withOpacity(.18),
      langSelectedBorder: Colors.white.withOpacity(.85),
      langBorder: Colors.white.withOpacity(.12),
      langSelectedBg: Colors.white.withOpacity(.06),
      langBg: const Color(0xFF0F172A),
      langText: Colors.white.withOpacity(.92),
      langCheck: Colors.white.withOpacity(.90),
      logoutBg: const Color(0xFF2A0F14),
      logoutBorder: const Color(0xFF5B1B25),
    );
  }
}

// =====================
// UI widgets (layout unchanged)
// =====================

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.titleColor,
  });

  final String title;
  final VoidCallback onBack;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.arrowLeft),
              color: titleColor,
              splashRadius: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    required this.bgColor,
    required this.borderColor,
    required this.shadowColor,
  });

  final Widget child;
  final Color bgColor;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 8),
            color: shadowColor,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
    required this.iconColor,
    required this.textColor,
    this.valueText,
  });

  final IconData icon;
  final String label;
  final String? valueText;
  final Widget trailing;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Center(child: Icon(icon, size: 20, color: iconColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (valueText != null) ...[
                Text(
                  valueText!,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Center(child: Icon(icon, size: 20, color: iconColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.95,
                child: Switch.adaptive(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.onTap,
    required this.bgColor,
    required this.borderColor,
  });

  final VoidCallback onTap;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: bgColor,
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.logOut, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 220.ms, duration: 260.ms)
        .slideY(
          begin: 0.10,
          end: 0,
          delay: 220.ms,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({
    required this.title,
    required this.child,
    required this.bgColor,
    required this.borderColor,
    required this.titleColor,
    required this.closeColor,
    required this.dragColor,
  });

  final String title;
  final Widget child;

  final Color bgColor;
  final Color borderColor;
  final Color titleColor;
  final Color closeColor;
  final Color dragColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 12),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: dragColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                  splashRadius: 20,
                  color: closeColor,
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.selectedBorder,
    required this.border,
    required this.selectedBg,
    required this.bg,
    required this.textColor,
    required this.checkColor,
  });

  final _LangItem item;
  final bool selected;
  final VoidCallback onTap;

  final Color selectedBorder;
  final Color border;
  final Color selectedBg;
  final Color bg;
  final Color textColor;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    final b = selected ? selectedBorder : border;
    final c = selected ? selectedBg : bg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: b),
            color: c,
          ),
          child: Row(
            children: [
              item.flag,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected) Icon(LucideIcons.check, color: checkColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangItem {
  const _LangItem({
    required this.code,
    required this.title,
    required this.flag,
  });

  final String code;
  final String title;
  final Widget flag;
}

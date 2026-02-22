// profile_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ---- Helpers (avoid withOpacity deprecated) ----
int _alpha(double o) => (o * 255).round().clamp(0, 255);
Color _o(Color c, double opacity) => c.withAlpha(_alpha(opacity));

// =======================================================
// ✅ SavingPage vibe tokens (dark)
// =======================================================
const Color _kSavingDarkBg = Color(0xFF0B1220);
const Color _kSavingBtnColor = Color(0xFF3B5FD9);
const Color _kSavingBtnGlow = Color(0xFF284A9D);

const Gradient _kSavingPremiumGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B2B5B), Color(0xFF071A33), Color(0xFF060B16)],
);

const Color _kLightPageBg = Color(0xFFF3F5F9);

Color _accent(BuildContext context, bool isDark) =>
    isDark ? _kSavingBtnColor : Theme.of(context).colorScheme.primary;

Color _accentStrong(BuildContext context, bool isDark) =>
    isDark ? _kSavingBtnGlow : Theme.of(context).colorScheme.tertiary;

/// Profile page UI (auto follow Dark/Light mode)
/// - Dark: Saving vibe (glass + premium gradient overlay)
/// - Light: clean white cards
/// - Verified check stays GREEN
/// - flutter_animate animations
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    this.title = 'Profile',
    this.name = 'Your Name',
    this.email = 'you@email.com',
    this.verified = true,
    this.avatarImage = const AssetImage('assets/images/profile/me.jpg'),
    this.headerImage = const AssetImage(
      'assets/images/homepagewall/mainbg.jpeg',
    ),
    this.onEdit,
    this.items,
  });

  final String title;
  final String name;
  final String email;
  final bool verified;
  final ImageProvider avatarImage;
  final ImageProvider headerImage;

  final VoidCallback? onEdit;
  final List<ProfileMenuItem>? items;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    // ✅ Follow current theme mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final menu =
        items ??
        const [
          ProfileMenuItem(
            icon: FontAwesomeIcons.gear,
            title: 'Profile Settings',
            subtitle: 'Update and modify your profile',
          ),
          ProfileMenuItem(
            icon: FontAwesomeIcons.shieldHalved,
            title: 'Privacy',
            subtitle: 'Change your password',
          ),
          ProfileMenuItem(
            icon: FontAwesomeIcons.bell,
            title: 'Notifications',
            subtitle: 'Change your notification settings',
          ),
        ];

    void goBack() {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }

    final pageBg = isDark ? _kSavingDarkBg : _kLightPageBg;

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          // Header background image + overlay (dark/light adaptive)
          SizedBox(
            height: 330 + safeTop,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      Image(
                            image: headerImage,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark
                                  ? _kSavingDarkBg
                                  : const Color(0xFF0B5FE0),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 260.ms)
                          .scale(
                            begin: const Offset(1.02, 1.02),
                            end: const Offset(1, 1),
                            duration: 520.ms,
                            curve: Curves.easeOutCubic,
                          ),
                ),

                // readability overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _o(Colors.black, .28),
                                  _o(Colors.black, .48),
                                  _o(_kSavingDarkBg, .96),
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _o(Colors.black, .12),
                                  _o(Colors.black, .20),
                                  _o(Colors.black, .06),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                // premium tint in dark (Saving vibe)
                if (isDark)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _o(const Color(0xFF0B2B5B), .40),
                              _o(const Color(0xFF071A33), .38),
                              _o(const Color(0xFF060B16), .20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CenteredTopBar(title: title, onBack: goBack, onEdit: onEdit)
                      .animate()
                      .fadeIn(duration: 280.ms)
                      .slideY(begin: -0.06, end: 0, duration: 320.ms),

                  const SizedBox(height: 18),

                  _ProfileCard(
                        avatarImage: avatarImage,
                        name: name,
                        email: email,
                        verified: verified,
                      )
                      .animate()
                      .fadeIn(duration: 320.ms, delay: 80.ms)
                      .slideY(begin: 0.08, end: 0, duration: 380.ms)
                      .scale(
                        begin: const Offset(0.98, 0.98),
                        end: const Offset(1, 1),
                        duration: 380.ms,
                        curve: Curves.easeOutBack,
                        delay: 80.ms,
                      ),

                  const SizedBox(height: 26),

                  Builder(
                        builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final fg = isDark
                              ? _o(Colors.white, .62)
                              : Colors.black.withAlpha(120);
                          return Text(
                            'GENERAL',
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          );
                        },
                      )
                      .animate()
                      .fadeIn(duration: 260.ms, delay: 140.ms)
                      .slideY(begin: 0.10, end: 0, duration: 320.ms),

                  const SizedBox(height: 12),

                  ...List.generate(menu.length, (i) {
                    final it = menu[i];
                    return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _MenuTile(item: it),
                        )
                        .animate()
                        .fadeIn(duration: 260.ms, delay: (160 + i * 70).ms)
                        .slideX(begin: 0.06, end: 0, duration: 340.ms);
                  }),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredTopBar extends StatelessWidget {
  const _CenteredTopBar({
    required this.title,
    required this.onBack,
    required this.onEdit,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox.expand(),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
              isDark: isDark,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _PillIconButton(
              icon: Icons.edit_rounded,
              onTap: onEdit,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _o(Colors.white, isDark ? .10 : .16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _o(Colors.white, isDark ? .18 : .22)),
              ),
              child: Center(child: Icon(icon, color: Colors.white)),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 260.ms, delay: 90.ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 280.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.avatarImage,
    required this.name,
    required this.email,
    required this.verified,
  });

  final ImageProvider avatarImage;
  final String name;
  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final acc = _accent(context, isDark);

    final shadow = _o(Colors.black, isDark ? .35 : .10);

    final cardBg = isDark
        ? _o(Colors.white, .075)
        : Colors.white.withAlpha(245);
    final border = isDark ? _o(Colors.white, .14) : Colors.white.withAlpha(160);

    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark
        ? _o(Colors.white, .64)
        : Colors.black.withAlpha(120);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar
              Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: _o(Colors.white, isDark ? .06 : .08),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: _o(Colors.white, isDark ? .14 : .10),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _o(Colors.black, isDark ? .30 : .08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: Image(
                        image: avatarImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: _o(textMain, .85),
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 280.ms)
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                    duration: 360.ms,
                  ),

              const SizedBox(height: 14),

              // Name + verified
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 8),
                    Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 240.ms, delay: 120.ms)
                        .scale(curve: Curves.easeOutBack, duration: 320.ms),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              Text(
                email,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textSub,
                ),
              ).animate().fadeIn(duration: 240.ms, delay: 120.ms),

              const SizedBox(height: 16),

              // Badges row (dark/light adaptive)
              Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? _o(Colors.white, .06)
                          : const Color(0xFFF6F8FC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? _o(Colors.white, .10)
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Badge(
                          icon: FontAwesomeIcons.medal,
                          bg: isDark
                              ? _o(const Color(0xFF10B981), .18)
                              : const Color(0xFFD1FAE5),
                          fg: const Color(0xFF10B981),
                        ),
                        _Badge(
                          icon: FontAwesomeIcons.award,
                          bg: isDark
                              ? _o(const Color(0xFF7C3AED), .18)
                              : const Color(0xFFEDE9FE),
                          fg: const Color(0xFF7C3AED),
                        ),
                        _Badge(
                          icon: FontAwesomeIcons.shield,
                          bg: isDark ? _o(acc, .18) : _o(acc, .14),
                          fg: isDark ? Colors.white : acc,
                        ),
                        _Badge(
                          icon: FontAwesomeIcons.sackDollar,
                          bg: isDark
                              ? _o(const Color(0xFFF97316), .18)
                              : const Color(0xFFFFEDD5),
                          fg: const Color(0xFFF97316),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 260.ms, delay: 160.ms)
                  .slideY(begin: 0.12, end: 0, duration: 360.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.bg, required this.fg});

  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? _o(Colors.white, .10) : Colors.black.withAlpha(10),
        ),
      ),
      child: Center(child: FaIcon(icon, size: 22, color: fg)),
    ).animate().scale(
      begin: const Offset(0.96, 0.96),
      end: const Offset(1, 1),
      duration: 280.ms,
      curve: Curves.easeOutBack,
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final ProfileMenuItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final acc = _accent(context, isDark);
    final accStrong = _accentStrong(context, isDark);

    final cardBg = isDark ? _o(Colors.white, .075) : Colors.white;
    final border = isDark ? _o(Colors.white, .14) : Colors.black.withAlpha(14);
    final shadow = isDark ? _o(Colors.black, .28) : Colors.black.withAlpha(14);

    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark
        ? _o(Colors.white, .62)
        : Colors.black.withAlpha(120);

    final iconBg = isDark ? _o(acc, .18) : _o(acc, .12);
    final iconFg = isDark ? Colors.white : acc;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? _o(Colors.white, .10)
                        : Colors.black.withAlpha(10),
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: _o(accStrong, .12),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: FaIcon(item.icon, size: 20, color: iconFg),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: _o(textMain, .55)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMenuItem {
  const ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

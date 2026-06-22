import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/student_card_item.dart'; // ✅ ใช้ตัวนี้ตัวเดียว

import '../../../auth/presentation/pages/login_page.dart';
import '../../../home/presentation/pages/home_shell_page.dart';

class StudentsCardListPage extends StatefulWidget {
  final List<StudentCardItem>? students;
  final ValueChanged<StudentCardItem>? onSelect;

  const StudentsCardListPage({super.key, this.students, this.onSelect});

  @override
  State<StudentsCardListPage> createState() => _StudentsCardListPageState();
}

class _StudentsCardListPageState extends State<StudentsCardListPage>
    with SingleTickerProviderStateMixin {
  static const double _maxWidth = 720;
  static const double _pageHPad = 16;
  static const double _topPad = 72;
  static const double _heroRadius = 24;
  static const double _s12 = 12;
  static const double _s16 = 16;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, .03),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  List<StudentCardItem> get _items => widget.students ?? _demoStudents;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ThemeData _effectiveTheme(Locale locale, bool dark) {
    return dark ? AppTheme.darkTheme(locale) : AppTheme.lightTheme(locale);
  }

  PageRouteBuilder _smoothRoute(Widget page) {
    return PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        final fade = Tween<double>(begin: 0, end: 1).animate(curved);
        final slide = Tween<Offset>(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(curved);
        final scale = Tween<double>(begin: .985, end: 1).animate(curved);

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

  void _goLogin() {
    Navigator.of(context).pushReplacement(_smoothRoute(const LoginPage()));
  }

  void _goHome(StudentCardItem student) {
    Navigator.of(
      context,
    ).pushReplacement(_smoothRoute(HomeShellPage(selectedStudent: student)));
  }

  Future<void> _confirmLogout() async {
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(isDarkNow ? .55 : .35),
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text("Logout"),
          content: const Text("Do you want to logout and go to Login page?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) _goLogin();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        return AnimatedTheme(
          data: _effectiveTheme(locale, mode == ThemeMode.dark),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final cs = Theme.of(context).colorScheme;

              final bgA = isDark
                  ? AppColors.blue500
                  : AppColors.blue200.withOpacity(.16);
              final bgB = isDark
                  ? AppColors.blue400.withOpacity(.34)
                  : AppColors.blue100.withOpacity(.08);
              final bgC = isDark ? AppColors.dark : Colors.white;

              final glowA = (isDark ? AppColors.blue100 : AppColors.blue200)
                  .withOpacity(isDark ? .26 : .11);
              final glowB = (isDark ? AppColors.blue200 : AppColors.blue300)
                  .withOpacity(isDark ? .22 : .09);

              final titleColor = isDark ? Colors.white : AppColors.blue500;
              final muted = isDark
                  ? AppColors.grayUltraLight.withOpacity(.84)
                  : AppColors.gray;

              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [bgA, bgB, bgC],
                    ),
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Positioned(
                          top: -110,
                          left: -95,
                          child: _Glow(size: 320, color: glowA),
                        ),
                        Positioned(
                          bottom: -170,
                          right: -140,
                          child: _Glow(size: 420, color: glowB),
                        ),

                        Positioned(
                          top: 10,
                          left: 12,
                          right: 12,
                          child: FadeTransition(
                            opacity: _fade,
                            child: Row(
                              children: [
                                _LogoutButton(
                                  isDark: isDark,
                                  onTap: _confirmLogout,
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),

                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxWidth,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                _pageHPad,
                                _topPad,
                                _pageHPad,
                                _pageHPad,
                              ),
                              child: FadeTransition(
                                opacity: _fade,
                                child: SlideTransition(
                                  position: _slide,
                                  child: Column(
                                    children: [
                                      _Hero(
                                        isDark: isDark,
                                        titleColor: titleColor,
                                        muted: muted,
                                        count: _items.length,
                                      ),
                                      const SizedBox(height: _s16),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            _heroRadius,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 14,
                                              sigmaY: 14,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.blue500
                                                          .withOpacity(.50)
                                                    : Colors.white.withOpacity(
                                                        .88,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      _heroRadius,
                                                    ),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.white
                                                            .withOpacity(.10)
                                                      : AppColors.slate
                                                            .withOpacity(.12),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    blurRadius: 34,
                                                    offset: const Offset(0, 18),
                                                    color: Colors.black
                                                        .withOpacity(
                                                          isDark ? .38 : .10,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              child: ListView.separated(
                                                padding: const EdgeInsets.all(
                                                  _s16,
                                                ),
                                                physics:
                                                    const BouncingScrollPhysics(),
                                                itemCount: _items.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(
                                                      height: _s12,
                                                    ),
                                                itemBuilder: (context, index) {
                                                  final item = _items[index];
                                                  final d = 280 + (index * 70);

                                                  return TweenAnimationBuilder<
                                                    double
                                                  >(
                                                    tween: Tween<double>(
                                                      begin: 0,
                                                      end: 1,
                                                    ),
                                                    duration: Duration(
                                                      milliseconds: d.clamp(
                                                        280,
                                                        900,
                                                      ),
                                                    ),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, t, child) {
                                                      return Opacity(
                                                        opacity: t,
                                                        child:
                                                            Transform.translate(
                                                              offset: Offset(
                                                                0,
                                                                (1 - t) * 10,
                                                              ),
                                                              child: child,
                                                            ),
                                                      );
                                                    },
                                                    child: _StudentCard(
                                                      isDark: isDark,
                                                      titleColor: titleColor,
                                                      muted: muted,
                                                      cs: cs,
                                                      item: item,
                                                      onTap: item.isApproved
                                                          ? () {
                                                              widget.onSelect?.call(item);
                                                              _goHome(item);
                                                            }
                                                          : () {
                                                              ScaffoldMessenger.of(context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'This student is pending admin approval. You can open the profile once it is approved.',
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// ✅ Demo list (ใช้ shared StudentCardItem)
const _demoStudents = <StudentCardItem>[
  StudentCardItem(
    studentId: "STU-2024-001",
    name: "Anouphong",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?schoolkid,student&sig=11",
  ),
  StudentCardItem(
    studentId: "STU-2024-014",
    name: "Timothy F.",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?boy,student,portrait&sig=12",
  ),
  StudentCardItem(
    studentId: "STU-2024-027",
    name: "Nok P.",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?girl,student,portrait&sig=13",
  ),
  StudentCardItem(
    studentId: "STU-2024-033",
    name: "Mina K.",
    photoUrl:
        "https://source.unsplash.com/featured/256x256?teen,student,school&sig=14",
  ),
];

/// ===== UI widgets เดิมของคุณ (คงไว้ได้เลย) =====
class _Hero extends StatelessWidget {
  final bool isDark;
  final Color titleColor;
  final Color muted;
  final int count;

  const _Hero({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? AppColors.blue500.withOpacity(.44)
        : Colors.white.withOpacity(.78);
    final stroke = isDark
        ? Colors.white.withOpacity(.10)
        : AppColors.slate.withOpacity(.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.blue100, AppColors.blue300],
                  ),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Students",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Card view • $count students",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  static const double _radius = 24;

  final bool isDark;
  final Color titleColor;
  final Color muted;
  final ColorScheme cs;
  final StudentCardItem item;
  final VoidCallback onTap;

  const _StudentCard({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.cs,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.94);
    final bd = isDark
        ? Colors.white.withOpacity(.14)
        : AppColors.slate.withOpacity(.12);
    final accent = isDark ? AppColors.blue100 : AppColors.blue500;

    return Opacity(
      opacity: item.isApproved ? 1.0 : 0.78,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: bd),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(isDark ? .58 : .10),
                      accent.withOpacity(isDark ? .28 : .06),
                    ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(.12)
                        : AppColors.slate.withOpacity(.10),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: item.photoUrl == null
                      ? Center(
                          child: FaIcon(
                            FontAwesomeIcons.userGraduate,
                            size: 22,
                            color: accent.withOpacity(isDark ? .92 : .70),
                          ),
                        )
                      : Image.network(
                          item.photoUrl!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          frameBuilder: (context, child, frame, wasSyncLoaded) {
                            if (wasSyncLoaded) return child;
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: child,
                            );
                          },
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accent.withOpacity(.9),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Center(
                            child: FaIcon(
                              FontAwesomeIcons.userGraduate,
                              size: 22,
                              color: accent.withOpacity(isDark ? .92 : .70),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        FaIcon(FontAwesomeIcons.idCard, size: 12, color: muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.studentId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (!item.isApproved) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(.45)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(FontAwesomeIcons.hourglassHalf, size: 9, color: Color(0xFFB45309)),
                            SizedBox(width: 5),
                            Text(
                              'Pending Approval',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                                letterSpacing: .4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: item.isApproved
                      ? (isDark
                          ? Colors.white.withOpacity(.08)
                          : cs.primary.withOpacity(.08))
                      : const Color(0xFFFFF7E6),
                  border: Border.all(
                    color: item.isApproved
                        ? (isDark
                            ? Colors.white.withOpacity(.10)
                            : cs.primary.withOpacity(.14))
                        : const Color(0xFFF59E0B).withOpacity(.40),
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    item.isApproved
                        ? FontAwesomeIcons.chevronRight
                        : FontAwesomeIcons.hourglassHalf,
                    size: 14,
                    color: item.isApproved
                        ? (isDark
                            ? Colors.white.withOpacity(.82)
                            : AppColors.blue500)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _LogoutButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.86);
    final bd = isDark
        ? Colors.white.withOpacity(.14)
        : AppColors.slate.withOpacity(.12);

    final fg = isDark ? Colors.white : const Color(0xFFE11D48);
    final glow = (isDark ? fg : const Color(0xFFE11D48)).withOpacity(.14);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
          boxShadow: [
            BoxShadow(blurRadius: 22, offset: const Offset(0, 12), color: glow),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.rightFromBracket, size: 15, color: fg),
            const SizedBox(width: 8),
            Text(
              "Logout",
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                letterSpacing: -.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

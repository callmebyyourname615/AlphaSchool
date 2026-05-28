// ✅ ของคุณเดิม + เพิ่ม global theme wrapper
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/widgets/scanqrcode/scan_qr_code_page.dart';
import '../../data/auth_service.dart';

// ✅ ปรับ path ให้ตรงกับโปรเจกต์คุณ
import '../../../home/presentation/pages/year_picker_page.dart'
    show YearPickerPage;

// ✅ ไฟล์นี้ต้องมี class: StudentsCardListPage
import '../../../students/presentation/pages/choose_students.dart'
    show StudentsCardListPage;

class LoginPage extends StatefulWidget {
  final String? academicYear;

  const LoginPage({super.key, this.academicYear});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // ===================== UI SCALE (modern / comfy) =====================
  static const double _maxWidth = 540;

  static const double _pageHPad = 16;
  static const double _topPad = 86;

  static const double _cardRadius = 26;
  static const double _innerPad = 24;

  static const double _fieldRadius = 18;
  static const double _fieldIconBox = 48;

  static const double _s10 = 10;
  static const double _s12 = 12;
  static const double _s16 = 16;
  static const double _s18 = 18;
  static const double _s20 = 20;
  static const double _s24 = 24;
  static const String _savedEmailKey = 'login_saved_email';
  static const String _savedPassKey = 'login_saved_pass';

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  bool _driver = false;
  bool _obscure = true;
  bool _loading = false;

  bool _navLock = false;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slideUp = Tween<Offset>(
    begin: const Offset(0, .06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  Animation<double> _itemFade(double t0, double t1) => CurvedAnimation(
    parent: _ctrl,
    curve: Interval(t0, t1, curve: Curves.easeOutCubic),
  );

  Animation<Offset> _itemSlide(double t0, double t1) =>
      Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(t0, t1, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_savedEmailKey) ?? '';
    final savedPass = prefs.getString(_savedPassKey) ?? '';
    if (!mounted) return;
    setState(() {
      if (savedEmail.isNotEmpty) _emailCtrl.text = savedEmail;
      if (savedPass.isNotEmpty) _passCtrl.text = savedPass;
    });
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, email);
    await prefs.setString(_savedPassKey, password);
  }

  Future<void> _submit() async {
    if (_loading || _navLock) return;
    final login = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (login.isEmpty || password.isEmpty) {
      _showLoginError('Please enter your username/email and password');
      return;
    }

    setState(() => _loading = true);

    try {
      final admin = await _authService.login(login: login, password: password);
      if (!mounted) return;

      await _saveCredentials(login, password);
      await SessionService().save(admin.json);
      if (!mounted) return;
      final nextPage = admin.isParent
          ? StudentsCardListPage()
          : const ScanQrCodePage();
      _navLock = true;
      await Navigator.of(context).pushReplacement(_smoothRoute(nextPage));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showLoginError(error.message);
    } catch (e) {
      if (!mounted) return;
      _showLoginError('Unable to sign in: $e');
    } finally {
      if (mounted && !_navLock) {
        setState(() => _loading = false);
      }
    }
  }

  void _showLoginError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ✅ Back จากหน้า login ต้องไป YearPickerPage เสมอ
  void _goYearPicker() {
    if (_navLock) return;
    _navLock = true;

    Navigator.of(
      context,
    ).pushAndRemoveUntil(_smoothRoute(YearPickerPage()), (route) => false);
  }

  PageRouteBuilder _smoothRoute(Widget page) {
    return PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(curved);
        final slide = Tween<Offset>(
          begin: const Offset(0, .02),
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

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final base = (mode == ThemeMode.dark)
            ? AppTheme.darkTheme(locale)
            : AppTheme.lightTheme(locale);
        return AnimatedTheme(
          data: base,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final cs = Theme.of(context).colorScheme;

              final bgA = isDark
                  ? AppColors.blue500
                  : AppColors.blue200.withOpacity(.18);
              final bgB = isDark
                  ? AppColors.blue400.withOpacity(.26)
                  : AppColors.blue100.withOpacity(.08);
              final bgC = isDark ? AppColors.dark : Colors.white;

              final glowA = (isDark ? AppColors.blue100 : AppColors.blue200)
                  .withOpacity(isDark ? .20 : .11);
              final glowB = (isDark ? AppColors.blue200 : AppColors.blue300)
                  .withOpacity(isDark ? .16 : .09);

              final cardSurface = isDark
                  ? AppColors.blue400.withOpacity(.58)
                  : Colors.white.withOpacity(.90);

              final stroke = isDark
                  ? Colors.white.withOpacity(.10)
                  : AppColors.slate.withOpacity(.12);

              final titleColor = isDark ? Colors.white : AppColors.blue500;
              final muted = isDark
                  ? AppColors.grayUltraLight.withOpacity(.84)
                  : AppColors.gray;

              final btnG1 = isDark ? AppColors.blue200 : AppColors.blue500;
              final btnG2 = isDark ? AppColors.blue100 : AppColors.blue300;

              return PopScope(
                canPop: false,
                onPopInvoked: (didPop) {
                  if (!didPop) _goYearPicker();
                },
                child: Scaffold(
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
                            child: _Glow(size: 300, color: glowA),
                          ),
                          Positioned(
                            bottom: -170,
                            right: -140,
                            child: _Glow(size: 380, color: glowB),
                          ),

                          Positioned(
                            top: 8,
                            left: 12,
                            right: 12,
                            child: FadeTransition(
                              opacity: _itemFade(0.00, 0.50),
                              child: Row(
                                children: [
                                  _BackPill(
                                    isDark: isDark,
                                    onTap: _goYearPicker,
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
                                  18,
                                ),
                                child: FadeTransition(
                                  opacity: _fade,
                                  child: SlideTransition(
                                    position: _slideUp,
                                    child: Column(
                                      children: [
                                        FadeTransition(
                                          opacity: _itemFade(0.10, 0.64),
                                          child: SlideTransition(
                                            position: _itemSlide(0.10, 0.70),
                                            child: _HeroHeader(
                                              isDark: isDark,
                                              titleColor: titleColor,
                                              muted: muted,
                                              year: widget.academicYear,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: _s20),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              _cardRadius,
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                sigmaX: 14,
                                                sigmaY: 14,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: cardSurface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        _cardRadius,
                                                      ),
                                                  border: Border.all(
                                                    color: stroke,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      blurRadius: 34,
                                                      offset: const Offset(
                                                        0,
                                                        18,
                                                      ),
                                                      color: Colors.black
                                                          .withOpacity(
                                                            isDark ? .34 : .10,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                child: SingleChildScrollView(
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        _innerPad,
                                                        _innerPad,
                                                        _innerPad,
                                                        _innerPad,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      FadeTransition(
                                                        opacity: _itemFade(
                                                          0.18,
                                                          0.74,
                                                        ),
                                                        child: SlideTransition(
                                                          position: _itemSlide(
                                                            0.18,
                                                            0.78,
                                                          ),
                                                          child: Text(
                                                            "Welcome Back",
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .headlineSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color:
                                                                      titleColor,
                                                                  letterSpacing:
                                                                      -.25,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s10,
                                                      ),
                                                      FadeTransition(
                                                        opacity: _itemFade(
                                                          0.22,
                                                          0.78,
                                                        ),
                                                        child: SlideTransition(
                                                          position: _itemSlide(
                                                            0.22,
                                                            0.82,
                                                          ),
                                                          child: Text(
                                                            "Sign in to continue",
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: muted,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s24,
                                                      ),
                                                      FadeTransition(
                                                        opacity: _itemFade(
                                                          0.30,
                                                          0.88,
                                                        ),
                                                        child: SlideTransition(
                                                          position: _itemSlide(
                                                            0.30,
                                                            0.92,
                                                          ),
                                                          child: _Field(
                                                            radius:
                                                                _fieldRadius,
                                                            iconBox:
                                                                _fieldIconBox,
                                                            label: "Email",
                                                            hint:
                                                                "Enter your email",
                                                            controller:
                                                                _emailCtrl,
                                                            keyboardType:
                                                                TextInputType
                                                                    .emailAddress,
                                                            prefixFa:
                                                                FontAwesomeIcons
                                                                    .envelope,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s16,
                                                      ),
                                                      FadeTransition(
                                                        opacity: _itemFade(
                                                          0.36,
                                                          0.92,
                                                        ),
                                                        child: SlideTransition(
                                                          position: _itemSlide(
                                                            0.36,
                                                            0.96,
                                                          ),
                                                          child: _Field(
                                                            radius:
                                                                _fieldRadius,
                                                            iconBox:
                                                                _fieldIconBox,
                                                            label: "Password",
                                                            hint:
                                                                "Enter your password",
                                                            controller:
                                                                _passCtrl,
                                                            obscureText:
                                                                _obscure,
                                                            prefixFa:
                                                                FontAwesomeIcons
                                                                    .lock,
                                                            suffix: IconButton(
                                                              onPressed: () =>
                                                                  setState(
                                                                    () => _obscure =
                                                                        !_obscure,
                                                                  ),
                                                              icon: FaIcon(
                                                                _obscure
                                                                    ? FontAwesomeIcons
                                                                          .eye
                                                                    : FontAwesomeIcons
                                                                          .eyeSlash,
                                                                size: 18,
                                                                color: cs
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      .70,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s18,
                                                      ),
                                                      FadeTransition(
                                                        opacity: _itemFade(
                                                          0.44,
                                                          1.0,
                                                        ),
                                                        child: SlideTransition(
                                                          position: _itemSlide(
                                                            0.44,
                                                            1.0,
                                                          ),
                                                          child: _CheckPill(
                                                            isDark: isDark,
                                                            value: _driver,
                                                            onChanged: (v) =>
                                                                setState(
                                                                  () => _driver = v,
                                                                ),
                                                            icon: FontAwesomeIcons
                                                                .carSide,
                                                            label: "Driver",
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s20,
                                                      ),
                                                      FadeTransition(
                                                        opacity: _itemFade(0.52, 1.0),
                                                        child: SlideTransition(
                                                          position: _itemSlide(0.52, 1.0),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 3,
                                                                child: _GradientButton(
                                                                  height: 58,
                                                                  radius: 18,
                                                                  gradient: LinearGradient(
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                    colors: [btnG1, btnG2],
                                                                  ),
                                                                  borderColor: isDark
                                                                      ? Colors.white.withOpacity(.14)
                                                                      : Colors.white.withOpacity(.85),
                                                                  shadowColor: Colors.black.withOpacity(isDark ? .32 : .12),
                                                                  loading: _loading,
                                                                  onTap: _loading ? null : _submit,
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: const [
                                                                      FaIcon(
                                                                        FontAwesomeIcons.rightToBracket,
                                                                        size: 17,
                                                                        color: Colors.white,
                                                                      ),
                                                                      SizedBox(width: 10),
                                                                      Text(
                                                                        "Sign in",
                                                                        style: TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.w900,
                                                                          fontSize: 17,
                                                                          letterSpacing: .2,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                flex: 2,
                                                                child: _GradientButton(
                                                                  height: 58,
                                                                  radius: 18,
                                                                  gradient: LinearGradient(
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                    colors: isDark
                                                                        ? [AppColors.blue400.withOpacity(.6), AppColors.blue500.withOpacity(.4)]
                                                                        : [AppColors.blue300.withOpacity(.18), AppColors.blue200.withOpacity(.12)],
                                                                  ),
                                                                  borderColor: isDark
                                                                      ? Colors.white.withOpacity(.18)
                                                                      : AppColors.blue400.withOpacity(.30),
                                                                  shadowColor: Colors.black.withOpacity(isDark ? .20 : .06),
                                                                  loading: false,
                                                                  onTap: _loading ? null : () {},
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                      FaIcon(
                                                                        FontAwesomeIcons.fingerprint,
                                                                        size: 17,
                                                                        color: isDark ? Colors.white : AppColors.blue500,
                                                                      ),
                                                                      const SizedBox(width: 8),
                                                                      Text(
                                                                        "Scan Login",
                                                                        style: TextStyle(
                                                                          color: isDark ? Colors.white : AppColors.blue500,
                                                                          fontWeight: FontWeight.w900,
                                                                          fontSize: 13,
                                                                          letterSpacing: .2,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s20,
                                                      ),
                                                      Center(
                                                        child: TextButton(
                                                          onPressed: () {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  "Sign up (todo)",
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          child: Text(
                                                            "Don’t have an account? Sign up",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: titleColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: _s12,
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
                              ),
                            ),
                          ),
                        ],
                      ),
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

// ======================= LOGIN WIDGETS =======================
// ... (ส่วน widgets เดิมของคุณทั้งหมด คงไว้เหมือนเดิม) ...
// ✅ ผมไม่ได้แตะ logic widget ย่อย นอกจากส่ง isDark ที่คำนวณจาก Theme ให้ตรง global

class _HeroHeader extends StatelessWidget {
  final bool isDark;
  final Color titleColor;
  final Color muted;
  final String? year;

  const _HeroHeader({
    required this.isDark,
    required this.titleColor,
    required this.muted,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? AppColors.blue500.withOpacity(.40)
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
                child: const Icon(Icons.hub_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "C-Connect",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      year == null ? "Sign in" : "Academic Year • $year",
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

// (ที่เหลือ: _BackPill, _Field, _CheckPill, _GradientButton, _Glow คงเดิมได้เลย)
// ======================= LOGIN WIDGETS (ADD BACK) =======================

class _BackPill extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _BackPill({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? AppColors.blue500.withOpacity(.55)
        : Colors.white.withOpacity(.80);
    final bd = isDark
        ? Colors.white.withOpacity(.10)
        : AppColors.slate.withOpacity(.12);
    final fg = isDark ? Colors.white : AppColors.blue500;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(isDark ? .26 : .08),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_left_rounded, size: 20, color: fg),
            const SizedBox(width: 6),
            Text(
              "Back",
              style: TextStyle(color: fg, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final double radius;
  final double iconBox;

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixFa;
  final Widget? suffix;

  const _Field({
    required this.radius,
    required this.iconBox,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixFa,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final fill = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.92);
    final borderColor = isDark
        ? Colors.white.withOpacity(.14)
        : AppColors.slate.withOpacity(.14);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 12.5,
      color: cs.onSurface.withOpacity(.72),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: cs.onSurface.withOpacity(.45),
              fontWeight: FontWeight.w600,
            ),
            isDense: true,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            prefixIcon: prefixFa == null
                ? null
                : SizedBox(
                    width: iconBox,
                    child: Center(
                      child: FaIcon(
                        prefixFa,
                        size: 18,
                        color: cs.onSurface.withOpacity(.70),
                      ),
                    ),
                  ),
            prefixIconConstraints: BoxConstraints(
              minWidth: iconBox,
              minHeight: iconBox,
            ),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(.42)
                    : AppColors.blue400.withOpacity(.55),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckPill extends StatelessWidget {
  final bool isDark;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final String label;

  const _CheckPill({
    required this.isDark,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(.10)
        : Colors.white.withOpacity(.86);
    final bd = isDark
        ? Colors.white.withOpacity(.14)
        : AppColors.slate.withOpacity(.12);
    final fg = isDark ? Colors.white : AppColors.blue500;

    // ✅ Checkbox colors (fix dark mode visibility)
    final fillColor = MaterialStateProperty.resolveWith<Color>((states) {
      if (states.contains(MaterialState.selected)) {
        // ✅ checked box background = WHITE in darkmode
        return isDark ? Colors.white : AppColors.blue500;
      }
      // ✅ unchecked background transparent
      return Colors.transparent;
    });

    final checkColor = isDark
        ? AppColors
              .blue500 // ✅ check mark = dark blue on white box
        : Colors.white;

    final side = BorderSide(
      color: isDark
          ? Colors.white.withOpacity(.55) // ✅ clearer outline in dark mode
          : AppColors.blue500.withOpacity(.35),
      width: 1.2,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),

              // ✅ IMPORTANT: make it clear in dark mode
              fillColor: fillColor,
              checkColor: checkColor,
              side: side,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),

              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            ),
            const SizedBox(width: 2),
            FaIcon(icon, size: 14, color: fg.withOpacity(.92)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg.withOpacity(.92),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final double height;
  final double radius;
  final LinearGradient gradient;
  final Color borderColor;
  final Color shadowColor;
  final bool loading;
  final VoidCallback? onTap;
  final Widget child;

  const _GradientButton({
    required this.height,
    required this.radius,
    required this.gradient,
    required this.borderColor,
    required this.shadowColor,
    required this.loading,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? .62 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                  color: shadowColor,
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? const SizedBox(
                        key: ValueKey("loading"),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : SizedBox(key: const ValueKey("child"), child: child),
              ),
            ),
          ),
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

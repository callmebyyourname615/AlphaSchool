import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_icons.dart';

import 'parent_info_form_page.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  static const _blue = Color(0xFF0756D1);
  static const _navy = Color(0xFF071B55);
  static const _muted = Color(0xFF64739B);
  static const _surface = Color(0xFFF7F9FE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.arrowLeft, size: 18),
                        color: _navy,
                        tooltip: 'Back',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(
                    height: 360,
                    width: double.infinity,
                    child: _RegisterAnimation(),
                  ),
                  const SizedBox(height: 24),
                  const _BenefitRow(
                    icon: LucideIcons.refreshCw,
                    title: 'Fast & Easy',
                    description: 'Fill in your information online 24/7',
                  ),
                  const _BenefitDivider(),
                  const _BenefitRow(
                    icon: LucideIcons.lock,
                    title: 'Secure',
                    description:
                        'Your data is protected\nwith highest security',
                  ),
                  const _BenefitDivider(),
                  const _BenefitRow(
                    icon: LucideIcons.history,
                    title: 'Track Your Status',
                    description: 'Check your application status\nat any time',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ParentInfoFormPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
                        backgroundColor: _blue,
                        shadowColor: _blue.withValues(alpha: .28),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Start Application',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

class _RegisterAnimation extends StatefulWidget {
  const _RegisterAnimation();

  @override
  State<_RegisterAnimation> createState() => _RegisterAnimationState();
}

class _RegisterAnimationState extends State<_RegisterAnimation> {
  static const _animations = [
    'assets/lottie/exams_preparation.json',
    'assets/lottie/kids_studying_from_home.json',
    'assets/lottie/student.json',
  ];
  static const _animationScales = [1.0, 1.0, .86];

  Timer? _autoTimer;
  int _animationIndex = 0;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _animationIndex = (_animationIndex + 1) % _animations.length;
      });
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Widget _fallback() =>
      Image.asset('assets/images/register/register.png', fit: BoxFit.contain);

  Widget _lottie(String path) {
    if (kIsWeb) {
      return Lottie.network(
        path,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return Lottie.asset(
      path,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = _animations[_animationIndex];
    final scale = _animationScales[_animationIndex];
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 620),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Padding(
            key: ValueKey(path),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Transform.scale(scale: scale, child: _lottie(path)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _animations.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: _animationIndex == i ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _animationIndex == i
                        ? RegisterPage._blue
                        : const Color(0xFFD9E2F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: RegisterPage._blue, size: 23),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RegisterPage._navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: RegisterPage._muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 64),
      child: Divider(height: 1, color: Color(0xFFE7ECF6)),
    );
  }
}

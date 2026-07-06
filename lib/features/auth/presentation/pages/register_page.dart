import 'package:flutter/material.dart';
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
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: Image.asset(
                      'assets/images/register/register.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Apply to Our School',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _navy,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please fill in the application form\neasily in just a few steps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
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

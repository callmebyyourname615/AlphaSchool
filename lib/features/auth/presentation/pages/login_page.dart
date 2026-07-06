import 'package:flutter/material.dart';
import '../../../../core/theme/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanqrcode/scan_qr_code_page.dart';
import '../../../../shared/models/student_card_item.dart';
import '../../../home/presentation/pages/year_picker_page.dart';
import '../../../students/data/student_service.dart';
import '../../../students/presentation/pages/choose_students.dart';
import '../../data/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final String? academicYear;

  const LoginPage({super.key, this.academicYear});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _savedEmailKey = 'login_saved_email';
  static const _savedPassKey = 'login_saved_pass';

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();
  final _studentService = StudentService();

  bool _rememberMe = true;
  bool _obscure = true;
  bool _loading = false;
  bool _navLock = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _emailCtrl.text = prefs.getString(_savedEmailKey) ?? '';
      _passCtrl.text = prefs.getString(_savedPassKey) ?? '';
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
      _showError('Please enter your username/email and password');
      return;
    }

    setState(() => _loading = true);
    try {
      final account = await _authService.login(
        login: login,
        password: password,
      );
      if (!mounted) return;
      await _saveCredentials(login, password);
      await SessionService().save(account.json);
      if (!mounted) return;

      Widget nextPage;
      if (account.isParent) {
        final students = await _fetchParentStudents(account);
        if (!mounted) return;
        nextPage = StudentsCardListPage(students: students);
      } else {
        nextPage = const ScanQrCodePage();
      }

      _navLock = true;
      await Navigator.of(context).pushReplacement(_route(nextPage));
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('Unable to sign in: $error');
    } finally {
      if (mounted && !_navLock) setState(() => _loading = false);
    }
  }

  /// Looks up the students linked to this parent account via `GET /students`
  /// (there's no dedicated "students by parent" endpoint — `StudentService`
  /// matches client-side against each student's `parents[].id`). Fetch
  /// failures are swallowed so a flaky secondary call can't block an
  /// otherwise-successful login; the picker just shows no students then.
  Future<List<StudentCardItem>> _fetchParentStudents(
    AuthenticatedUser account,
  ) async {
    final parentId = account.json['id']?.toString().trim() ?? '';
    if (parentId.isEmpty) return const [];

    try {
      return await _studentService.fetchStudentsForParent(parentId);
    } catch (_) {
      return const [];
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _goYearPicker() {
    if (_navLock) return;
    _navLock = true;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(_route(const YearPickerPage()), (_) => false);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goYearPicker();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leading: IconButton(
            onPressed: _loading ? null : _goYearPicker,
            icon: const Icon(LucideIcons.arrowLeft),
            color: AppColors.dark,
            tooltip: 'Back',
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 150,
                          height: 100,
                          child: Image.asset(
                            'assets/images/logo/Alpha.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.7,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please sign in to your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.gray, fontSize: 15),
                      ),
                      if (widget.academicYear != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Academic year ${widget.academicYear}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.blue300,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      _LoginField(
                        hint: 'Email',
                        controller: _emailCtrl,
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                      ),
                      const SizedBox(height: 18),
                      _LoginField(
                        hint: 'Password',
                        controller: _passCtrl,
                        icon: LucideIcons.lock,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                            size: 21,
                          ),
                          color: AppColors.gray,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _loading
                                ? null
                                : (value) => setState(
                                    () => _rememberMe = value ?? false,
                                  ),
                            activeColor: AppColors.blue300,
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text(
                            'Remember me',
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _loading ? null : () {},
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.blue400, AppColors.blue100],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFE3E9F2))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: AppColors.grayLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE3E9F2))),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () {},
                          icon: const Icon(LucideIcons.scanQrCode, size: 17),
                          label: const Text('Scan to login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.blue300,
                            side: const BorderSide(color: AppColors.blue100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'New to C-Connect? ',
                            style: TextStyle(color: AppColors.gray),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(
                                    context,
                                  ).push(_route(const RegisterPage())),
                            child: const Text(
                              'Create account',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  const _LoginField({
    required this.hint,
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.grayLight,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(icon, size: 17, color: AppColors.gray),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E9F2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E9F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue300, width: 1.5),
        ),
      ),
    );
  }
}

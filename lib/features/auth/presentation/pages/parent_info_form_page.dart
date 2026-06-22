import 'package:flutter/material.dart';

import '../../../../core/services/global_alert_service.dart';
import '../../data/parent_registration_service.dart';
import 'student_info_form_page.dart';

class ParentInfoFormPage extends StatefulWidget {
  const ParentInfoFormPage({super.key});

  @override
  State<ParentInfoFormPage> createState() => _ParentInfoFormPageState();
}

class _ParentInfoFormPageState extends State<ParentInfoFormPage> {
  static const _blue = Color(0xFF0756D1);
  static const _blueSoft = Color(0xFFEAF1FF);
  static const _blueSofter = Color(0xFFF7F9FE);
  static const _navy = Color(0xFF071B55);
  static const _muted = Color(0xFF64739B);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate100 = Color(0xFFEFF2F8);
  static const _rose500 = Color(0xFFE11D48);

  static const List<_StepMeta> _steps = [
    _StepMeta(1, 'Personal', Icons.person_outline),
    _StepMeta(2, 'Contact', Icons.work_outline),
    _StepMeta(3, 'Identity', Icons.badge_outlined),
    _StepMeta(4, 'Address', Icons.place_outlined),
  ];

  static const Map<int, List<String>> _required = {
    1: [
      'Firstname_Lao', 'Firstname_Eng',
      'Midlename_Lao', 'Midlename_Eng',
      'Lastname_Lao', 'Lastname_Eng',
      'Nickname', 'DateofBirth', 'Gender',
    ],
    2: ['Educatio_Level', 'Job', 'Workplace', 'Email', 'Phone_No1', 'Phone_No2'],
    3: [
      'IDCard_no', 'Passport_no', 'FamillyBook_no',
      'Nationality', 'Ethnicty', 'Religion',
    ],
    4: ['Home_no', 'Home_unit', 'Village', 'District', 'Province'],
  };

  static const _education = ['Primary School', 'Secondary School', 'High School', "Bachelor's Degree", "Master's Degree", 'Doctorate'];
  static const _genders = ['male', 'female', 'other'];
  static const _districts = ['Chanthabouly', 'Sikhottabong', 'Xaysetha', 'Sisattanak', 'Hadxaifong'];
  static const _provinces = ['Vientiane Capital', 'Luang Prabang', 'Savannakhet', 'Champasak', 'Xieng Khouang'];

  int _step = 1;
  final Map<String, String> _data = {};
  final Map<String, String> _errors = {};
  bool _submitted = false;
  bool _submitting = false;
  bool _bootstrapping = true;
  bool _checkingStatus = false;
  String? _referenceId;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingFullName;
  bool _passwordVisible = false;
  final PageController _pageController = PageController();
  final ParentRegistrationService _service = ParentRegistrationService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final pending = await _service.loadPending();
    if (!mounted) return;
    if (pending != null) {
      setState(() {
        _submitted = true;
        _referenceId = pending.id;
        _pendingEmail = pending.email;
        _pendingPassword = pending.password;
        _pendingFullName = pending.fullName;
        _bootstrapping = false;
      });
      _refreshStatus(silent: true);
    } else {
      setState(() => _bootstrapping = false);
    }
  }

  Future<void> _onAddStudent() async {
    final id = _referenceId;
    if (id == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StudentInfoFormPage.addOnly(parentId: id),
      ),
    );
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (_referenceId == null) return;
    if (!silent) setState(() => _checkingStatus = true);
    final status = await _service.checkStatus(_referenceId!);
    if (!mounted) return;
    if (status == 'approved') {
      await _service.clearPending();
      if (!mounted) return;
      setState(() {
        _submitted = false;
        _referenceId = null;
        _pendingEmail = null;
        _pendingPassword = null;
        _pendingFullName = null;
        _passwordVisible = false;
        _data.clear();
        _errors.clear();
        _step = 1;
        _checkingStatus = false;
      });
      _pageController.jumpToPage(0);
      GlobalAlert.showSuccess(
        title: 'Application approved',
        message: 'Your application has been approved. You can now create your account.',
      );
    } else {
      if (!silent) setState(() => _checkingStatus = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToStep(int step) {
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _set(String k, String v) {
    setState(() {
      _data[k] = v;
      if (_errors.containsKey(k)) _errors.remove(k);
    });
  }

  bool _validate() {
    final next = <String, String>{};
    for (final f in _required[_step] ?? const <String>[]) {
      if ((_data[f] ?? '').trim().isEmpty) next[f] = 'This field is required';
    }
    if (_step == 2) {
      final email = _data['Email'] ?? '';
      if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        next['Email'] = 'Enter a valid email';
      }
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(next);
    });
    return next.isEmpty;
  }

  void _onNext() {
    if (_validate() && _step < 4) {
      setState(() => _step++);
      _animateToStep(_step);
    }
  }

  void _onBack() {
    if (_step > 1) {
      setState(() => _step--);
      _animateToStep(_step);
    }
  }

  Future<void> _onSubmit() async {
    if (!_validate() || _submitting) return;
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StudentInfoFormPage(
          parentData: Map<String, String>.from(_data),
          parentService: _service,
        ),
      ),
    );
    if (!mounted) return;
    if (result is PendingApplication) {
      // Apply pending state directly — avoids any timing/storage race.
      setState(() {
        _submitted = true;
        _referenceId = result.id;
        _pendingEmail = result.email;
        _pendingPassword = result.password;
        _pendingFullName = result.fullName;
        _passwordVisible = false;
      });
      _refreshStatus(silent: true);
    } else if (result == true) {
      setState(() => _bootstrapping = true);
      await _bootstrap();
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_submitted) _buildStepper(),
            Expanded(
              child: _submitted
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: _buildSuccess(),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      onPageChanged: (i) {
                        if (_step != i + 1) setState(() => _step = i + 1);
                      },
                      itemBuilder: (_, i) => SingleChildScrollView(
                        key: PageStorageKey('step_${i + 1}'),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: _buildStepBodyFor(i + 1),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _submitted ? null : _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _navy),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: _blue.withValues(alpha: .22), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy, height: 1.1),
                ),
                SizedBox(height: 2),
                Text(
                  'Please fill in all required parent information',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _slate100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                _stepBubble(_steps[i]),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: _slate100,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(
                          begin: 0,
                          end: _step > _steps[i].id ? 1.0 : 0.0,
                        ),
                        builder: (_, value, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP $_step OF 4',
                    style: const TextStyle(
                      fontSize: 11, color: _blue, fontWeight: FontWeight.w700, letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_steps[_step - 1].title} Information',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy),
                  ),
                ],
              ),
              Text(
                '${((_step / 4) * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: _slate400, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBubble(_StepMeta s) {
    final completed = _step > s.id;
    final active = _step == s.id;
    final filled = completed || active;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: active ? 44 : 40,
      width: active ? 44 : 40,
      decoration: BoxDecoration(
        color: filled ? _blue : _slate100,
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: _blue.withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 4))]
            : null,
        border: active ? Border.all(color: _blueSoft, width: 3) : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          completed ? Icons.check_rounded : s.icon,
          key: ValueKey('${s.id}_${completed ? 'done' : 'pending'}'),
          color: filled ? Colors.white : _slate400,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildStepBodyFor(int step) {
    switch (step) {
      case 1:
        return _sectionCard(1, 'Personal Information', [
          _input('First Name (Lao)', 'Firstname_Lao', required: true, placeholder: 'Enter (Lao)'),
          _input('First Name (English)', 'Firstname_Eng', required: true, placeholder: 'Enter (English)'),
          _input('Middle Name (Lao)', 'Midlename_Lao', required: true, placeholder: 'Enter (Lao)'),
          _input('Middle Name (English)', 'Midlename_Eng', required: true, placeholder: 'Enter (English)'),
          _input('Last Name (Lao)', 'Lastname_Lao', required: true, placeholder: 'Enter (Lao)'),
          _input('Last Name (English)', 'Lastname_Eng', required: true, placeholder: 'Enter (English)'),
          _input('Nickname', 'Nickname', required: true, placeholder: 'Enter nickname'),
          _dateInput('Date of Birth', 'DateofBirth', required: true),
          _select('Gender', 'Gender', _genders, required: true, placeholder: 'Select gender'),
        ]);
      case 2:
        return _sectionCard(2, 'Education & Contact', [
          _select('Education Level', 'Educatio_Level', _education, required: true, placeholder: 'Select education level'),
          _input('Job', 'Job', required: true, placeholder: 'Enter job'),
          _input('Workplace', 'Workplace', required: true, placeholder: 'Enter workplace'),
          _input('Email', 'Email', required: true, placeholder: 'Enter email', keyboard: TextInputType.emailAddress),
          _input('Phone No. 1', 'Phone_No1', required: true, placeholder: 'Enter phone number', keyboard: TextInputType.phone),
          _input('Phone No. 2', 'Phone_No2', required: true, placeholder: 'Enter phone number', keyboard: TextInputType.phone),
        ]);
      case 3:
        return _sectionCard(3, 'Identification', [
          _input('ID Card No.', 'IDCard_no', required: true, placeholder: 'Enter ID card number'),
          _input('Passport No.', 'Passport_no', required: true, placeholder: 'Enter passport number'),
          _input('Family Book No.', 'FamillyBook_no', required: true, placeholder: 'Enter family book number'),
          _input('Nationality', 'Nationality', required: true, placeholder: 'Enter nationality'),
          _input('Ethnicity', 'Ethnicty', required: true, placeholder: 'Enter ethnicity'),
          _input('Religion', 'Religion', required: true, placeholder: 'Enter religion'),
        ]);
      case 4:
      default:
        return Column(
          children: [
            _sectionCard(4, 'Address Information', [
              _input('Home No.', 'Home_no', required: true, placeholder: 'Enter home number'),
              _input('Home Unit', 'Home_unit', required: true, placeholder: 'Enter unit / room'),
              _input('Village', 'Village', required: true, placeholder: 'Enter village'),
              _select('District', 'District', _districts, required: true, placeholder: 'Select district'),
              _select('Province', 'Province', _provinces, required: true, placeholder: 'Select province'),
            ]),
            const SizedBox(height: 16),
            _buildNote(),
          ],
        );
    }
  }

  Widget _sectionCard(int num, String label, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _blueSofter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  height: 28,
                  width: 28,
                  decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('$num',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _blue, letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _slate100),
          const SizedBox(height: 16),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _label(String text, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
          children: [
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: _rose500)),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String? placeholder, String? error) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: const TextStyle(color: _slate400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error != null ? _rose500 : _slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error != null ? _rose500 : _blue, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    );
  }

  Widget _input(
    String label,
    String name, {
    String? placeholder,
    bool required = false,
    TextInputType? keyboard,
  }) {
    final err = _errors[name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required),
        TextFormField(
          key: ValueKey('input_$name'),
          initialValue: _data[name],
          onChanged: (v) => _set(name, v),
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 14, color: _navy),
          decoration: _decoration(placeholder, err),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(err, style: const TextStyle(fontSize: 11, color: _rose500)),
          ),
      ],
    );
  }

  Widget _select(
    String label,
    String name,
    List<String> options, {
    String? placeholder,
    bool required = false,
  }) {
    final err = _errors[name];
    final value = _data[name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required),
        DropdownButtonFormField<String>(
          initialValue: (value != null && options.contains(value)) ? value : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          hint: Text(placeholder ?? 'Select...', style: const TextStyle(color: _slate400, fontSize: 14)),
          style: const TextStyle(fontSize: 14, color: _navy),
          decoration: _decoration(null, err),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) {
            if (v != null) _set(name, v);
          },
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(err, style: const TextStyle(fontSize: 11, color: _rose500)),
          ),
      ],
    );
  }

  Widget _dateInput(String label, String name, {bool required = false}) {
    final err = _errors[name];
    final value = _data[name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            DateTime initial = now;
            if (value != null && value.isNotEmpty) {
              try { initial = DateTime.parse(value); } catch (_) {}
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: now,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: _blue, onPrimary: Colors.white),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              _set(name, '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _decoration(null, err).copyWith(
              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: _muted),
            ),
            child: Text(
              value ?? 'YYYY-MM-DD',
              style: TextStyle(fontSize: 14, color: value == null ? _slate400 : _navy),
            ),
          ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(err, style: const TextStyle(fontSize: 11, color: _rose500)),
          ),
      ],
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blueSoft.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blueSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36, width: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _blue, width: 2),
            ),
            child: const Icon(Icons.shield_outlined, color: _blue, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOTE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _blue, letterSpacing: 1)),
                SizedBox(height: 4),
                Text(
                  'All information provided will be kept confidential and used for educational purposes only.',
                  style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _slate100)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 1) ...[
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _onBack,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _slate200, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : (_step < 4 ? _onNext : _onSubmit),
                  style: ElevatedButton.styleFrom(
                    elevation: 2,
                    backgroundColor: _blue,
                    shadowColor: _blue.withValues(alpha: .3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: _step < 4
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('Next'), SizedBox(width: 6), Icon(Icons.chevron_right_rounded, size: 18)],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue · Add Student'),
                            SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final fromForm = [_data['Firstname_Eng'], _data['Midlename_Eng'], _data['Lastname_Eng']]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final fullName = fromForm.isNotEmpty ? fromForm : (_pendingFullName ?? '');
    const amber = Color(0xFFF59E0B);
    const amberSoft = Color(0xFFFFF7E6);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _blueSofter,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _blueSoft),
          ),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.6, end: 1.0),
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  height: 76, width: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: amberSoft,
                    border: Border.all(color: amber, width: 2),
                    boxShadow: [
                      BoxShadow(color: amber.withValues(alpha: .2), blurRadius: 22, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: amber, size: 36),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: amberSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: amber.withValues(alpha: .4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: amber, size: 8),
                    SizedBox(width: 6),
                    Text('PENDING APPROVAL',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Application Submitted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Thank you',
                  style: const TextStyle(fontSize: 14, color: _muted, height: 1.5),
                  children: [
                    if (fullName.isNotEmpty) ...[
                      const TextSpan(text: ', '),
                      TextSpan(
                        text: fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
                      ),
                    ],
                    const TextSpan(text: '. Your application has been received and is now waiting for admin approval.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              _credentialsCard(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _statusTimeline(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _referenceId == null ? null : _onAddStudent,
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: const Text('Add another student'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _checkingStatus ? null : () => _refreshStatus(),
            icon: _checkingStatus
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_checkingStatus ? 'Checking status...' : 'Check approval status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: _slate200, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('Back to Sign In'),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            final ok = await GlobalAlert.showConfirmation(
              title: 'Cancel application?',
              message: 'Your local pending status will be cleared. The backend record remains until admin removes it.',
            );
            if (ok != true) return;
            await _service.clearPending();
            if (!mounted) return;
            setState(() {
              _submitted = false;
              _referenceId = null;
              _pendingEmail = null;
              _pendingPassword = null;
              _pendingFullName = null;
              _passwordVisible = false;
              _data.clear();
              _errors.clear();
              _step = 1;
            });
            _pageController.jumpToPage(0);
          },
          style: TextButton.styleFrom(foregroundColor: _muted),
          child: const Text('Cancel application',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _credentialsCard() {
    final pwd = _pendingPassword ?? '';
    final masked = pwd.isEmpty ? '••••••••' : '•' * pwd.length.clamp(6, 16);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR LOGIN',
              style: TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 10),
          if (_pendingEmail != null) ...[
            _credRow(
              label: 'Email',
              value: _pendingEmail!,
              icon: Icons.mail_outline_rounded,
            ),
          ],
          if (_pendingEmail != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: _slate100),
            ),
          _credRow(
            label: 'Password',
            value: pwd.isEmpty
                ? 'Not available'
                : (_passwordVisible ? pwd : masked),
            icon: Icons.lock_outline_rounded,
            monospace: pwd.isNotEmpty,
            muted: pwd.isEmpty,
            trailing: IconButton(
              onPressed: () {
                if (pwd.isEmpty) {
                  GlobalAlert.showInfo(
                    title: 'Password unavailable',
                    message:
                        'This application was submitted before the password was stored locally. Cancel the application and re-submit to see your login password.',
                  );
                  return;
                }
                setState(() => _passwordVisible = !_passwordVisible);
              },
              icon: Icon(
                _passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20, color: _blue,
              ),
              tooltip: _passwordVisible ? 'Hide' : 'Show',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _blueSofter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _blue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Save this password. You can change it after admin approves your account.',
                    style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credRow({
    required String label,
    required String value,
    required IconData icon,
    bool monospace = false,
    bool muted = false,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          height: 32, width: 32,
          decoration: BoxDecoration(color: _blueSoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _blue, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: muted ? _muted : _navy,
                  fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                  fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  fontFamily: monospace ? 'monospace' : null,
                  letterSpacing: monospace ? 1.2 : null,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _statusTimeline() {
    const amber = Color(0xFFF59E0B);
    final steps = [
      ('Submitted', 'Application received', Icons.check_circle_rounded, _blue, true),
      ('Pending Review', 'Waiting for admin approval', Icons.hourglass_top_rounded, amber, true),
      ('Approved', "You'll be notified once approved", Icons.verified_rounded, _slate400, false),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      height: 28, width: 28,
                      decoration: BoxDecoration(
                        color: steps[i].$5 ? steps[i].$4.withValues(alpha: .12) : _slate100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(steps[i].$3, color: steps[i].$4, size: 16),
                    ),
                    if (i < steps.length - 1)
                      Container(width: 2, height: 22, margin: const EdgeInsets.symmetric(vertical: 4), color: _slate100),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: steps[i].$5 ? _navy : _slate400,
                            )),
                        const SizedBox(height: 2),
                        Text(steps[i].$2,
                            style: const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepMeta {
  final int id;
  final String title;
  final IconData icon;
  const _StepMeta(this.id, this.title, this.icon);
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../../../core/theme/app_icons.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/global_alert_service.dart';
import '../../data/parent_registration_service.dart';
import 'login_page.dart';

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
    _StepMeta(1, 'Personal', LucideIcons.user),
    _StepMeta(2, 'Contact', LucideIcons.briefcaseBusiness),
    _StepMeta(3, 'Identity', LucideIcons.badge),
    _StepMeta(4, 'Address', LucideIcons.mapPin),
  ];

  static const Map<int, List<String>> _required = {
    1: [
      'Email',
      'Password',
      'ConfirmPassword',
      'Firstname_Lao',
      'Firstname_Eng',
      'Midlename_Lao',
      'Midlename_Eng',
      'Lastname_Lao',
      'Lastname_Eng',
      'Nickname',
      'DateofBirth',
      'Gender',
    ],
    2: ['Educatio_Level', 'Job', 'Workplace', 'Phone_No1', 'Phone_No2'],
    3: [
      'IDCard_no',
      'Passport_no',
      'FamillyBook_no',
      'Nationality',
      'Ethnicty',
      'Religion',
    ],
    4: ['Home_no', 'Home_unit', 'Village', 'District', 'Province'],
  };

  static const _education = [
    'Primary School',
    'Secondary School',
    'High School',
    "Bachelor's Degree",
    "Master's Degree",
    'Doctorate',
  ];
  static const _genders = ['Male', 'Female', 'Other'];

  int _step = 1;
  final Map<String, String> _data = {};
  final Map<String, String> _errors = {};
  final Map<String, _ParentAttachmentDraft> _attachments = {};
  final List<_FamilyBookImageDraft> _familyBookImages = [];
  bool _processingFamilyBook = false;
  bool _submitted = false;
  bool _submitting = false;
  bool _bootstrapping = true;
  bool _checkingStatus = false;
  String? _referenceId;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingFullName;
  bool _passwordVisible = false;
  bool _formPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _rejected = false;
  bool _approved = false;
  String? _rejectReason;
  final PageController _pageController = PageController();
  final ParentRegistrationService _service = ParentRegistrationService();
  List<_ParentProvinceOption> _provinces = const [];
  bool _provincesLoading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _loadProvinces();
    final pending = await _service.loadPending();
    if (!mounted) return;
    if (pending != null) {
      setState(() {
        _submitted = true;
        _referenceId = pending.id;
        _pendingEmail = pending.email;
        _pendingPassword = pending.password;
        _pendingFullName = pending.fullName;
        _data
          ..clear()
          ..addAll(pending.formData);
        _bootstrapping = false;
      });
      _refreshStatus(silent: true);
    } else {
      setState(() => _bootstrapping = false);
    }
  }

  Future<void> _loadProvinces() async {
    if (_provincesLoading) return;
    setState(() => _provincesLoading = true);
    try {
      final res = await ApiClient().get('/locations/province');
      final raw = res is List
          ? res
          : (res is Map && res['data'] is List
                ? res['data'] as List
                : const []);
      final list = raw
          .whereType<Map>()
          .map(
            (m) => _ParentProvinceOption.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _provinces = list;
        _provincesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _provincesLoading = false);
    }
  }

  _ParentProvinceOption? _provinceByLabel(String label) {
    if (label.trim().isEmpty) return null;
    final lc = label.trim().toLowerCase();
    for (final p in _provinces) {
      if (p.label.toLowerCase() == lc) return p;
    }
    return null;
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (_referenceId == null) return;
    if (!silent) setState(() => _checkingStatus = true);
    final result = await _service.checkStatus(_referenceId!);
    if (!mounted) return;
    if (result.status == 'approved') {
      final wasApproved = _approved;
      setState(() {
        _approved = true;
        _rejected = false;
        _rejectReason = null;
        _checkingStatus = false;
      });
      if (!wasApproved && !silent) {
        GlobalAlert.showSuccess(
          title: 'Application approved',
          message:
              'Your application has been approved. You can now sign in with your email and password.',
        );
      }
    } else if (result.status == 'rejected') {
      final wasRejected = _rejected;
      final reason = result.rejectReason?.trim() ?? '';
      setState(() {
        _rejected = true;
        _approved = false;
        _rejectReason = reason;
        _checkingStatus = false;
      });
      if (!wasRejected || !silent) {
        GlobalAlert.showError(
          title: 'Application rejected',
          message: reason.isEmpty
              ? 'Admin rejected your parent application. Please review your information and submit again.'
              : reason,
        );
      }
    } else {
      if (!silent) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _resubmitApplication() async {
    if (!mounted) return;
    setState(() {
      _submitted = false;
      _passwordVisible = false;
      _formPasswordVisible = false;
      _confirmPasswordVisible = false;
      _approved = false;
      _errors.clear();
      _step = 1;
    });
    _pageController.jumpToPage(0);
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
    if (_step == 1 || _step == 2) {
      final email = _data['Email'] ?? '';
      if (email.isNotEmpty &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        next['Email'] = 'Enter a valid email';
      }
    }
    if (_step == 1) {
      final password = _data['Password'] ?? '';
      final confirmPassword = _data['ConfirmPassword'] ?? '';
      if (password.isNotEmpty && password.length < 6) {
        next['Password'] = 'Password must be at least 6 characters';
      }
      if (password.isNotEmpty &&
          confirmPassword.isNotEmpty &&
          password != confirmPassword) {
        next['ConfirmPassword'] = 'Passwords do not match';
      }
    }
    if (_step == 3) {
      for (final field in ['id_card', 'family_book', 'passport_image']) {
        if (!_attachments.containsKey(field)) {
          next[field] = 'Please upload this document';
        }
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
    setState(() => _submitting = true);
    GlobalAlert.showLoading(message: 'Submitting your application...');
    try {
      if (_familyBookImages.isNotEmpty) {
        GlobalAlert.showLoading(
          message: _familyBookImages.length == 1
              ? 'Converting Family Book image to PDF...'
              : 'Converting ${_familyBookImages.length} Family Book images to PDF...',
        );
      }
      final attachments = await _buildSubmitAttachments();
      GlobalAlert.showLoading(message: 'Submitting your application...');
      final isResubmission = _rejected && _referenceId != null;
      final result = isResubmission
          ? await _service.resubmit(
              _referenceId!,
              _data,
              attachments: attachments,
            )
          : await _service.register(_data, attachments: attachments);
      final parent = result.data;
      final parentData = parent['data'] is Map
          ? Map<String, dynamic>.from(parent['data'] as Map)
          : parent;
      final id = (parentData['id'] ?? parentData['_id'])?.toString();
      if (id == null || id.isEmpty) {
        throw const ApiException('Could not resolve your application ID.');
      }
      final fullName = [
        _data['Firstname_Eng'],
        _data['Midlename_Eng'],
        _data['Lastname_Eng'],
      ].where((value) => value != null && value.isNotEmpty).join(' ');
      final submittedPassword = isResubmission
          ? ((_data['Password'] ?? '').trim().isNotEmpty
                ? _data['Password']!.trim()
                : _pendingPassword)
          : result.password;
      await _service.savePending(
        id: id,
        email: _data['Email'] ?? '',
        fullName: fullName.isEmpty ? null : fullName,
        password: submittedPassword,
        formData: _data,
      );
      GlobalAlert.dismiss();
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _referenceId = id;
        _pendingEmail = _data['Email'];
        _pendingPassword = submittedPassword;
        _pendingFullName = fullName.isEmpty ? null : fullName;
        _passwordVisible = false;
        _rejected = false;
        _approved = false;
        _rejectReason = null;
        _submitting = false;
      });
      GlobalAlert.showSuccess(
        title: 'Application submitted',
        message:
            'Your parent information has been submitted. Please wait for admin approval before signing in.',
      );
      _refreshStatus(silent: true);
    } catch (error) {
      GlobalAlert.dismiss();
      if (!mounted) return;
      setState(() => _submitting = false);
      GlobalAlert.showError(
        title: 'Submission failed',
        message: error is ApiException ? error.message : error.toString(),
      );
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
      backgroundColor: _blueSofter,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_submitted) _buildStepper(),
            Expanded(
              child: _submitted
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
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
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft, size: 18, color: _navy),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1.08,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Tell us about yourself. Fields marked * are required.',
                  style: TextStyle(fontSize: 13, color: _muted, height: 1.35),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP $_step OF 4',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_steps[_step - 1].title} Information',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              Text(
                '${((_step / 4) * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: _slate400,
                  fontWeight: FontWeight.w700,
                ),
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
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: .25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
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
          completed ? LucideIcons.check : s.icon,
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
        return Column(
          children: [
            _sectionCard(1, 'Create Login Account', [
              _input(
                'Email',
                'Email',
                required: true,
                placeholder: 'Enter email',
                keyboard: TextInputType.emailAddress,
              ),
              _input(
                'Password',
                'Password',
                required: true,
                placeholder: 'Create password',
                obscureText: !_formPasswordVisible,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(
                      () => _formPasswordVisible = !_formPasswordVisible,
                    );
                  },
                  icon: Icon(
                    _formPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18,
                    color: _muted,
                  ),
                  tooltip: _formPasswordVisible ? 'Hide' : 'Show',
                ),
              ),
              _input(
                'Confirm Password',
                'ConfirmPassword',
                required: true,
                placeholder: 'Confirm password',
                obscureText: !_confirmPasswordVisible,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(
                      () => _confirmPasswordVisible = !_confirmPasswordVisible,
                    );
                  },
                  icon: Icon(
                    _confirmPasswordVisible
                        ? LucideIcons.eyeOff
                        : LucideIcons.eye,
                    size: 18,
                    color: _muted,
                  ),
                  tooltip: _confirmPasswordVisible ? 'Hide' : 'Show',
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _sectionCard(1, 'Personal Information', [
              _input(
                'First Name (Lao)',
                'Firstname_Lao',
                required: true,
                placeholder: 'Enter (Lao)',
              ),
              _input(
                'First Name (English)',
                'Firstname_Eng',
                required: true,
                placeholder: 'Enter (English)',
              ),
              _input(
                'Middle Name (Lao)',
                'Midlename_Lao',
                required: true,
                placeholder: 'Enter (Lao)',
              ),
              _input(
                'Middle Name (English)',
                'Midlename_Eng',
                required: true,
                placeholder: 'Enter (English)',
              ),
              _input(
                'Last Name (Lao)',
                'Lastname_Lao',
                required: true,
                placeholder: 'Enter (Lao)',
              ),
              _input(
                'Last Name (English)',
                'Lastname_Eng',
                required: true,
                placeholder: 'Enter (English)',
              ),
              _input(
                'Nickname',
                'Nickname',
                required: true,
                placeholder: 'Enter nickname',
              ),
              _dateInput('Date of Birth', 'DateofBirth', required: true),
              _select(
                'Gender',
                'Gender',
                _genders,
                required: true,
                placeholder: 'Select gender',
              ),
            ]),
          ],
        );
      case 2:
        return _sectionCard(2, 'Education & Contact', [
          _select(
            'Education Level',
            'Educatio_Level',
            _education,
            required: true,
            placeholder: 'Select education level',
          ),
          _input('Job', 'Job', required: true, placeholder: 'Enter job'),
          _input(
            'Workplace',
            'Workplace',
            required: true,
            placeholder: 'Enter workplace',
          ),
          _input(
            'Email',
            'Email',
            required: true,
            placeholder: 'Enter email',
            keyboard: TextInputType.emailAddress,
          ),
          _input(
            'Phone No. 1',
            'Phone_No1',
            required: true,
            placeholder: 'Enter phone number',
            keyboard: TextInputType.phone,
          ),
          _input(
            'Phone No. 2',
            'Phone_No2',
            required: true,
            placeholder: 'Enter phone number',
            keyboard: TextInputType.phone,
          ),
        ]);
      case 3:
        return _sectionCard(3, 'Identification', [
          _input(
            'ID Card No.',
            'IDCard_no',
            required: true,
            placeholder: 'Enter ID card number',
          ),
          _input(
            'Passport No.',
            'Passport_no',
            required: true,
            placeholder: 'Enter passport number',
          ),
          _input(
            'Family Book No.',
            'FamillyBook_no',
            required: true,
            placeholder: 'Enter family book number',
          ),
          _fileUpload(
            'Identity card',
            'id_card',
            required: true,
            pdfOnly: false,
          ),
          _fileUpload(
            'Home picture (Optional)',
            'home_picture',
            pdfOnly: false,
          ),
          _fileUpload(
            'Family Book (Upload PDF or Image)',
            'family_book',
            required: true,
            pdfOnly: true,
          ),
          _fileUpload(
            'Passport image',
            'passport_image',
            required: true,
            pdfOnly: false,
          ),
          _input(
            'Nationality',
            'Nationality',
            required: true,
            placeholder: 'Enter nationality',
          ),
          _input(
            'Ethnicity',
            'Ethnicty',
            required: true,
            placeholder: 'Enter ethnicity',
          ),
          _input(
            'Religion',
            'Religion',
            required: true,
            placeholder: 'Enter religion',
          ),
        ]);
      case 4:
      default:
        return Column(
          children: [
            _sectionCard(4, 'Address Information', [
              _input(
                'Home No.',
                'Home_no',
                required: true,
                placeholder: 'Enter home number',
              ),
              _input(
                'Home Unit',
                'Home_unit',
                required: true,
                placeholder: 'Enter unit / room',
              ),
              _input(
                'Village',
                'Village',
                required: true,
                placeholder: 'Enter village',
              ),
              _locationProvinceSelect(),
              _locationDistrictSelect(),
            ]),
            const SizedBox(height: 16),
            _buildNote(),
          ],
        );
    }
  }

  Widget _fileUpload(
    String label,
    String field, {
    bool required = false,
    required bool pdfOnly,
  }) {
    final selected = _attachments[field];
    final error = _errors[field];
    final isFamilyBook = field == 'family_book';
    final isProcessing = isFamilyBook && _processingFamilyBook;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
              children: required
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: _rose500),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 7),
          OutlinedButton.icon(
            onPressed: isProcessing
                ? null
                : () async {
                    if (isFamilyBook) {
                      setState(() => _processingFamilyBook = true);
                    }
                    try {
                      final attachment = isFamilyBook
                          ? await _pickFamilyBookAttachment()
                          : await _pickSingleAttachment(
                              field,
                              pdfOnly: pdfOnly,
                            );
                      if (attachment == null || !mounted) return;
                      setState(() {
                        _attachments[field] = attachment;
                        _errors.remove(field);
                      });
                    } catch (error) {
                      if (!mounted) return;
                      setState(() {
                        _errors[field] = error is Exception
                            ? error.toString().replaceFirst('Exception: ', '')
                            : 'Could not read this file';
                      });
                    } finally {
                      if (mounted && isFamilyBook) {
                        setState(() => _processingFamilyBook = false);
                      }
                    }
                  },
            icon: Icon(
              selected == null ? LucideIcons.upload : LucideIcons.circleCheck,
              size: 18,
            ),
            label: Text(
              selected == null
                  ? 'Choose ${isFamilyBook ? 'PDF or images' : (pdfOnly ? 'PDF' : 'image')}'
                  : (isFamilyBook && _familyBookImages.isNotEmpty
                        ? '${selected.displayName} (tap to add more)'
                        : selected.displayName),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
              foregroundColor: selected == null
                  ? _navy
                  : const Color(0xFF059669),
              side: BorderSide(color: error == null ? _slate200 : _rose500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                error,
                style: const TextStyle(fontSize: 12, color: _rose500),
              ),
            ),
        ],
      ),
    );
  }

  Future<_ParentAttachmentDraft?> _pickSingleAttachment(
    String field, {
    required bool pdfOnly,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: pdfOnly ? 'PDF' : 'Image',
          extensions: pdfOnly
              ? const ['pdf']
              : const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        ),
      ],
    );
    if (file == null) return null;
    return _prepareAttachment(field, file);
  }

  Future<List<ParentAttachment>> _buildSubmitAttachments() async {
    final attachments = <ParentAttachment>[];
    for (final entry in _attachments.entries) {
      final draft = entry.value;
      if (entry.key == 'family_book' &&
          draft.deferUntilSubmit &&
          _familyBookImages.isNotEmpty) {
        final pdfBytes = await _imagesToPdf(
          _familyBookImages.map((image) => image.bytes).toList(),
        );
        attachments.add(
          ParentAttachment(
            field: entry.key,
            bytes: pdfBytes,
            filename: draft.filename,
          ),
        );
        continue;
      }
      attachments.add(
        ParentAttachment(
          field: entry.key,
          bytes: draft.bytes,
          filename: draft.filename,
        ),
      );
    }
    return attachments;
  }

  Future<_ParentAttachmentDraft?> _pickFamilyBookAttachment() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF or images',
          extensions: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    );
    if (files.isEmpty) return null;

    final pdfFiles = files
        .where((file) => _extensionOf(file.name) == 'pdf')
        .toList();
    final imageFiles = files
        .where((file) => _imageExtensions.contains(_extensionOf(file.name)))
        .toList();

    if (pdfFiles.isNotEmpty && imageFiles.isNotEmpty) {
      throw Exception('Please choose either PDF or images, not both.');
    }
    if (pdfFiles.length > 1) {
      throw Exception('Please choose only one PDF file.');
    }
    if (pdfFiles.length == 1) {
      final pdf = pdfFiles.first;
      _familyBookImages.clear();
      return _ParentAttachmentDraft(
        bytes: await pdf.readAsBytes(),
        filename: pdf.name,
        displayName: pdf.name,
      );
    }
    if (imageFiles.isEmpty) {
      throw Exception('Please choose PDF, JPG, JPEG, or PNG files.');
    }

    for (final file in imageFiles) {
      _familyBookImages.add(
        _FamilyBookImageDraft(name: file.name, bytes: await file.readAsBytes()),
      );
    }
    final imageCount = _familyBookImages.length;
    final baseName = imageCount == 1
        ? _basenameWithoutExtension(_familyBookImages.first.name)
        : 'family_book_${imageCount}_images';
    return _ParentAttachmentDraft(
      bytes: Uint8List(0),
      filename: '$baseName.pdf',
      displayName: imageCount == 1
          ? '${_familyBookImages.first.name} -> PDF'
          : '$imageCount images -> PDF',
      deferUntilSubmit: true,
    );
  }

  Future<_ParentAttachmentDraft> _prepareAttachment(
    String field,
    XFile file,
  ) async {
    final bytes = await file.readAsBytes();
    final extension = _extensionOf(file.name);
    if (field == 'family_book' && _imageExtensions.contains(extension)) {
      final pdfBytes = await _imagesToPdf([bytes]);
      return _ParentAttachmentDraft(
        bytes: pdfBytes,
        filename: '${_basenameWithoutExtension(file.name)}.pdf',
        displayName: '${file.name} -> PDF',
      );
    }
    return _ParentAttachmentDraft(
      bytes: bytes,
      filename: file.name,
      displayName: file.name,
    );
  }

  Future<Uint8List> _imagesToPdf(List<Uint8List> imageBytesList) async {
    final doc = pw.Document();
    for (final imageBytes in imageBytesList) {
      final image = pw.MemoryImage(imageBytes);
      doc.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(24),
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }

  static const _imageExtensions = {'jpg', 'jpeg', 'png'};

  String _extensionOf(String filename) {
    final index = filename.lastIndexOf('.');
    if (index < 0 || index == filename.length - 1) return '';
    return filename.substring(index + 1).toLowerCase();
  }

  String _basenameWithoutExtension(String filename) {
    final index = filename.lastIndexOf('.');
    if (index <= 0) return filename.isEmpty ? 'family_book' : filename;
    return filename.substring(0, index);
  }

  Widget _sectionCard(int num, String label, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Container(
                  height: 28,
                  width: 28,
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$num',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _slate100),
          const SizedBox(height: 20),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _label(String text, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _navy,
            height: 1.2,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: _rose500),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String? placeholder, String? error) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: const TextStyle(
        color: _slate400,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: error != null ? _rose500 : _slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: error != null ? _rose500 : _blue,
          width: 2,
        ),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      isDense: true,
    );
  }

  Widget _input(
    String label,
    String name, {
    String? placeholder,
    bool required = false,
    TextInputType? keyboard,
    bool obscureText = false,
    Widget? suffixIcon,
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
          obscureText: obscureText,
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(
            placeholder,
            err,
          ).copyWith(suffixIcon: suffixIcon),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: const TextStyle(
                fontSize: 13,
                color: _rose500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _locationProvinceSelect() {
    const name = 'Province';
    final err = _errors[name];
    final current = _data[name] ?? '';
    final selected = _provinceByLabel(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Province', true),
        DropdownButtonFormField<String>(
          initialValue: selected?.id,
          isExpanded: true,
          icon: _provincesLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _muted,
                  ),
                )
              : const Icon(LucideIcons.chevronDown, color: _muted),
          hint: Text(
            _provincesLoading ? 'Loading provinces...' : 'Select province',
            style: const TextStyle(color: _slate400, fontSize: 14),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(null, err),
          items: _provinces
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
              .toList(),
          onChanged: _provinces.isEmpty
              ? null
              : (v) {
                  if (v == null) return;
                  final picked = _provinces.firstWhere((p) => p.id == v);
                  setState(() {
                    _data[name] = picked.label;
                    _data['District'] = '';
                    _errors.remove(name);
                    _errors.remove('District');
                  });
                },
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: const TextStyle(
                fontSize: 13,
                color: _rose500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _locationDistrictSelect() {
    const name = 'District';
    final err = _errors[name];
    final current = _data[name] ?? '';
    final province = _provinceByLabel(_data['Province'] ?? '');
    final districts = province?.districts ?? const [];
    final lc = current.trim().toLowerCase();
    final selected = districts.firstWhere(
      (d) => d.label.toLowerCase() == lc,
      orElse: () => const _ParentDistrictOption(id: '', label: ''),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('District', true),
        DropdownButtonFormField<String>(
          initialValue: selected.id.isEmpty ? null : selected.id,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, color: _muted),
          hint: Text(
            province == null ? 'Select province first' : 'Select district',
            style: const TextStyle(color: _slate400, fontSize: 14),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(null, err),
          items: districts
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.label)))
              .toList(),
          onChanged: districts.isEmpty
              ? null
              : (v) {
                  if (v == null) return;
                  final picked = districts.firstWhere((d) => d.id == v);
                  setState(() {
                    _data[name] = picked.label;
                    _errors.remove(name);
                  });
                },
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: const TextStyle(
                fontSize: 13,
                color: _rose500,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          initialValue: (value != null && options.contains(value))
              ? value
              : null,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, color: _muted),
          hint: Text(
            placeholder ?? 'Select...',
            style: const TextStyle(color: _slate400, fontSize: 14),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(null, err),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) _set(name, v);
          },
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: const TextStyle(
                fontSize: 13,
                color: _rose500,
                fontWeight: FontWeight.w600,
              ),
            ),
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
              try {
                initial = DateTime.parse(value);
              } catch (_) {}
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: now,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: _blue,
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              _set(
                name,
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: _decoration(null, err).copyWith(
              suffixIcon: const Icon(
                LucideIcons.calendarDays,
                size: 16,
                color: _muted,
              ),
            ),
            child: Text(
              value ?? 'YYYY-MM-DD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: value == null ? _slate400 : _navy,
              ),
            ),
          ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: const TextStyle(
                fontSize: 13,
                color: _rose500,
                fontWeight: FontWeight.w600,
              ),
            ),
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
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _blue, width: 2),
            ),
            child: const Icon(LucideIcons.shield, color: _blue, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                    letterSpacing: 1,
                  ),
                ),
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
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _slate200, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
                  onPressed: _submitting
                      ? null
                      : (_step < 4 ? _onNext : _onSubmit),
                  style: ElevatedButton.styleFrom(
                    elevation: 2,
                    backgroundColor: _blue,
                    shadowColor: _blue.withValues(alpha: .3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _step < 4
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Next'),
                            SizedBox(width: 6),
                            Icon(LucideIcons.chevronRight, size: 18),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Submit parent information'),
                            SizedBox(width: 6),
                            Icon(LucideIcons.chevronRight, size: 18),
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
    if (_rejected) return _buildRejected();
    if (_approved) return _buildApproved();
    final fromForm = [
      _data['Firstname_Eng'],
      _data['Midlename_Eng'],
      _data['Lastname_Eng'],
    ].where((e) => e != null && e.isNotEmpty).join(' ');
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
              const _PendingPulseIcon(color: amber, background: amberSoft),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: amberSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: amber.withValues(alpha: .4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circle, color: amber, size: 8),
                    SizedBox(width: 6),
                    Text(
                      'PENDING APPROVAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Application Submitted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Thank you',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    height: 1.5,
                  ),
                  children: [
                    if (fullName.isNotEmpty) ...[
                      const TextSpan(text: ', '),
                      TextSpan(
                        text: fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ],
                    const TextSpan(
                      text:
                          '. Your application has been received and is now waiting for admin approval.',
                    ),
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
          child: ElevatedButton.icon(
            onPressed: _checkingStatus ? null : () => _refreshStatus(),
            icon: _checkingStatus
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.refreshCw, size: 18),
            label: Text(
              _checkingStatus ? 'Checking status...' : 'Check approval status',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Back to Sign In'),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            final ok = await GlobalAlert.showConfirmation(
              title: 'Cancel application?',
              message:
                  'Your local pending status will be cleared. The backend record remains until admin removes it.',
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
              _formPasswordVisible = false;
              _confirmPasswordVisible = false;
              _data.clear();
              _errors.clear();
              _attachments.clear();
              _familyBookImages.clear();
              _step = 1;
            });
            _pageController.jumpToPage(0);
          },
          style: TextButton.styleFrom(foregroundColor: _muted),
          child: const Text(
            'Cancel application',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildApproved() {
    const green = Color(0xFF059669);
    const greenSoft = Color(0xFFECFDF5);
    const greenBorder = Color(0xFFA7F3D0);
    final fromForm = [
      _data['Firstname_Eng'],
      _data['Midlename_Eng'],
      _data['Lastname_Eng'],
    ].where((e) => e != null && e.isNotEmpty).join(' ');
    final fullName = fromForm.isNotEmpty ? fromForm : (_pendingFullName ?? '');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: greenSoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: greenBorder),
          ),
          child: Column(
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: green, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: green.withValues(alpha: .22),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.circleCheck,
                  color: green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: greenBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circle, color: green, size: 8),
                    SizedBox(width: 6),
                    Text(
                      'ACCOUNT APPROVED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: green,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'You\'re approved!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Welcome',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    height: 1.5,
                  ),
                  children: [
                    if (fullName.isNotEmpty) ...[
                      const TextSpan(text: ', '),
                      TextSpan(
                        text: fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ],
                    const TextSpan(
                      text:
                          '. Your account is now active. You can sign in any time using the email and password you submitted.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              _credentialsCard(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _service.clearPending();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            icon: const Icon(LucideIcons.logIn, size: 18),
            label: const Text('Go to sign in'),
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: green.withValues(alpha: .35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejected() {
    const roseSoft = Color(0xFFFFF1F2);
    const rose = Color(0xFFE11D48);
    final reason = (_rejectReason?.trim().isNotEmpty == true)
        ? _rejectReason!.trim()
        : 'Please review your parent information and submit again.';
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
              const _RejectedIcon(),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: roseSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: rose.withValues(alpha: .35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circleX, color: rose, size: 12),
                    SizedBox(width: 6),
                    Text(
                      'REJECTED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9F1239),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Application Rejected',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text.rich(
                TextSpan(
                  text:
                      'Admin reviewed this application and requested changes.',
                ),
                style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _rejectionReasonCard(reason),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _statusTimeline(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _checkingStatus ? null : () => _refreshStatus(),
            icon: _checkingStatus
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.refreshCw, size: 18),
            label: Text(_checkingStatus ? 'Checking status...' : 'Check again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _resubmitApplication,
            icon: const Icon(LucideIcons.filePenLine, size: 18),
            label: const Text('Edit and resubmit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _slate200, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Back to Sign In'),
          ),
        ),
      ],
    );
  }

  Widget _rejectionReasonCard(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.messageCircleWarning,
            color: Color(0xFFE11D48),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason from admin',
                  style: TextStyle(
                    color: Color(0xFF9F1239),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          const Text(
            'YOUR LOGIN',
            style: TextStyle(
              fontSize: 11,
              color: _blue,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          if (_pendingEmail != null) ...[
            _credRow(
              label: 'Email',
              value: _pendingEmail!,
              icon: LucideIcons.mail,
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
            icon: LucideIcons.lock,
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
                _passwordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 20,
                color: _blue,
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
                Icon(LucideIcons.info, size: 14, color: _blue),
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
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: _blueSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _blue, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    const rose = Color(0xFFE11D48);
    final steps = [
      (
        'Submitted',
        'Application received',
        LucideIcons.circleCheck,
        _blue,
        true,
      ),
      (
        _rejected ? 'Rejected' : 'Pending Review',
        _rejected ? 'Admin requested changes' : 'Waiting for admin approval',
        _rejected ? LucideIcons.circleX : LucideIcons.hourglass,
        _rejected ? rose : amber,
        true,
      ),
      (
        _rejected ? 'Resubmit' : 'Approved',
        _rejected
            ? 'Update details and send again'
            : "You'll be notified once approved",
        _rejected ? LucideIcons.filePenLine : LucideIcons.badgeCheck,
        _slate400,
        false,
      ),
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
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        color: steps[i].$5
                            ? steps[i].$4.withValues(alpha: .12)
                            : _slate100,
                        shape: BoxShape.circle,
                      ),
                      child: steps[i].$3 == LucideIcons.hourglass
                          ? _SpinningHourglass(color: steps[i].$4, size: 16)
                          : Icon(steps[i].$3, color: steps[i].$4, size: 16),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 22,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: _slate100,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: steps[i].$5 ? _navy : _slate400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$2,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
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

/// Animated hero pending icon: breathing badge with expanding ripple
/// and an hourglass that tips end-over-end like sand falling.
class _PendingPulseIcon extends StatefulWidget {
  const _PendingPulseIcon({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  State<_PendingPulseIcon> createState() => _PendingPulseIconState();
}

class _PendingPulseIconState extends State<_PendingPulseIcon>
    with TickerProviderStateMixin {
  late final AnimationController _tip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _tip.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Expanding ripple ring
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_pulse.value);
              final extra = 26.0 * t;
              return Opacity(
                opacity: (1 - t) * 0.6,
                child: Container(
                  width: 76 + extra,
                  height: 76 + extra,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 2),
                  ),
                ),
              );
            },
          ),
          // Breathing badge
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_pulse.value);
              final scale = 0.96 + 0.05 * t;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.background,
                border: Border.all(color: widget.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .22),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          // Tipping hourglass (180° flip per half-cycle with rest)
          AnimatedBuilder(
            animation: _tip,
            builder: (_, __) {
              final t = _tip.value;
              // Two flips per cycle, with a small pause between flips
              final half = (t * 2) % 1.0;
              final eased = Curves.easeInOutCubic.transform(
                (half * 1.35).clamp(0.0, 1.0),
              );
              final angle = (t < 0.5 ? 0 : 3.14159) + eased * 3.14159;
              return Transform.rotate(
                angle: angle,
                child: Icon(
                  LucideIcons.hourglass,
                  size: 36,
                  color: widget.color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RejectedIcon extends StatelessWidget {
  const _RejectedIcon();

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFE11D48);
    const roseSurface = Color(0xFFFFF1F2);
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: roseSurface,
        border: Border.all(color: rose, width: 2),
        boxShadow: [
          BoxShadow(
            color: rose.withValues(alpha: .18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(LucideIcons.circleX, size: 36, color: rose),
    );
  }
}

/// Compact rotating hourglass used inside the status timeline.
class _SpinningHourglass extends StatefulWidget {
  const _SpinningHourglass({required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  State<_SpinningHourglass> createState() => _SpinningHourglassState();
}

class _SpinningHourglassState extends State<_SpinningHourglass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final eased = Curves.easeInOutCubic.transform(_c.value);
        return Transform.rotate(
          angle: eased * 2 * 3.14159,
          child: Icon(
            LucideIcons.hourglass,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

class _ParentProvinceOption {
  final String id;
  final String label;
  final List<_ParentDistrictOption> districts;

  const _ParentProvinceOption({
    required this.id,
    required this.label,
    required this.districts,
  });

  factory _ParentProvinceOption.fromJson(Map<String, dynamic> j) {
    final raw = (j['districts'] as List?) ?? const [];
    return _ParentProvinceOption(
      id: (j['id'] ?? '').toString(),
      label: (j['nameEn'] ?? j['nameLa'] ?? j['name'] ?? '').toString(),
      districts: raw
          .whereType<Map>()
          .map(
            (d) => _ParentDistrictOption.fromJson(Map<String, dynamic>.from(d)),
          )
          .toList(),
    );
  }
}

class _ParentAttachmentDraft {
  const _ParentAttachmentDraft({
    required this.bytes,
    required this.filename,
    required this.displayName,
    this.deferUntilSubmit = false,
  });

  final Uint8List bytes;
  final String filename;
  final String displayName;
  final bool deferUntilSubmit;
}

class _FamilyBookImageDraft {
  const _FamilyBookImageDraft({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _ParentDistrictOption {
  final String id;
  final String label;
  const _ParentDistrictOption({required this.id, required this.label});

  factory _ParentDistrictOption.fromJson(Map<String, dynamic> j) =>
      _ParentDistrictOption(
        id: (j['id'] ?? '').toString(),
        label: (j['nameEn'] ?? j['nameLa'] ?? j['name'] ?? '').toString(),
      );
}

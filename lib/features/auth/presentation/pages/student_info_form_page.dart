import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/services/global_alert_service.dart';
import '../../data/parent_registration_service.dart';
import '../../data/student_registration_service.dart';

class StudentInfoFormPage extends StatefulWidget {
  /// Combined-registration mode: include parent data + service so we POST
  /// /parents first, then /students.
  const StudentInfoFormPage({
    super.key,
    required this.parentData,
    required this.parentService,
  }) : parentId = null,
       addOnly = false;

  /// Add-student-only mode (from the Pending screen). Skips parent POST,
  /// only calls POST /students with [parentId].
  const StudentInfoFormPage.addOnly({super.key, required this.parentId})
    : parentData = const {},
      parentService = null,
      addOnly = true;

  final Map<String, String> parentData;
  final ParentRegistrationService? parentService;
  final String? parentId;
  final bool addOnly;

  @override
  State<StudentInfoFormPage> createState() => _StudentInfoFormPageState();
}

class _StudentInfoFormPageState extends State<StudentInfoFormPage> {
  static const _blue = Color(0xFF0756D1);
  static const _blueSoft = Color(0xFFEAF1FF);
  static const _blueSofter = Color(0xFFF7F9FE);
  static const _navy = Color(0xFF071B55);
  static const _muted = Color(0xFF64739B);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate100 = Color(0xFFEFF2F8);
  static const _rose500 = Color(0xFFE11D48);

  static const _steps = [
    _StepMeta(1, 'Student', Icons.person_outline),
    _StepMeta(2, 'Address', Icons.place_outlined),
    _StepMeta(3, 'Education', Icons.school_outlined),
    _StepMeta(4, 'Sibling', Icons.group_outlined),
    _StepMeta(5, 'Live With', Icons.home_outlined),
    _StepMeta(6, 'Emergency', Icons.warning_amber_rounded),
  ];

  static const _genders = ['male', 'female', 'other'];
  static const _yearLevels = [
    'K1',
    'K2',
    'K3',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
  ];
  static const _educationLevels = [
    'Primary',
    'Secondary',
    'High School',
    'Bachelor',
    'Master',
    'PhD',
    'Other',
  ];

  final StudentRegistrationService _studentService =
      StudentRegistrationService();
  final StudentSubmission _s = StudentSubmission();
  final PageController _pageController = PageController();
  final Map<String, String> _errors = {};

  int _step = 1;
  bool _submitting = false;
  final Set<int> _livingExpanded = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _err(String key, String? msg) {
    if (msg == null || msg.isEmpty) {
      _errors.remove(key);
    } else {
      _errors[key] = msg;
    }
  }

  bool _validate() {
    _errors.clear();
    switch (_step) {
      case 1:
        if (_s.firstNameLao.trim().isEmpty) _err('Firstname_Lao', 'Required');
        if (_s.firstNameEng.trim().isEmpty) _err('Firstname_Eng', 'Required');
        if (_s.middleNameLao.trim().isEmpty) _err('Midlename_Lao', 'Required');
        if (_s.middleNameEng.trim().isEmpty) _err('Midlename_Eng', 'Required');
        if (_s.lastNameLao.trim().isEmpty) _err('Lastname_Lao', 'Required');
        if (_s.lastNameEng.trim().isEmpty) _err('Lastname_Eng', 'Required');
        if (_s.nickname.trim().isEmpty) _err('Nickname', 'Required');
        if (_s.dob.trim().isEmpty) _err('DateofBirth', 'Required');
        if (_s.gender.trim().isEmpty) _err('Gender', 'Required');
        if (_s.nationality.trim().isEmpty) _err('Nationality', 'Required');
        if (_s.ethnicity.trim().isEmpty) _err('Ethnicity', 'Required');
        if (_s.religion.trim().isEmpty) _err('Religion', 'Required');
        if (_s.passportNo.trim().isEmpty) _err('Passport_no', 'Required');
        break;
      case 2:
        if (_s.villageBirth.trim().isEmpty) _err('Village_Birth', 'Required');
        if (_s.districtBirth.trim().isEmpty) _err('District_Birth', 'Required');
        if (_s.provinceBirth.trim().isEmpty) _err('Province_Birth', 'Required');
        if (_s.village.trim().isEmpty) _err('Village', 'Required');
        if (_s.district.trim().isEmpty) _err('District', 'Required');
        if (_s.province.trim().isEmpty) _err('Province', 'Required');
        break;
      case 3:
        if (_s.kindergarten.academicYear.trim().isEmpty)
          _err('Academic_Year1', 'Required');
        if (_s.kindergarten.yearLevel.trim().isEmpty)
          _err('Year_Level1', 'Required');
        if (_s.kindergarten.school.trim().isEmpty) _err('School1', 'Required');
        if (_s.primary.academicYear.trim().isEmpty)
          _err('Academic_Year2', 'Required');
        if (_s.primary.yearLevel.trim().isEmpty)
          _err('Year_Level2', 'Required');
        if (_s.primary.school.trim().isEmpty) _err('School2', 'Required');
        break;
      case 4:
        if (_s.siblings.isEmpty) {
          _err('Bos_Required', 'Add at least one sibling before continuing');
        } else {
          for (var i = 0; i < _s.siblings.length; i++) {
            final sib = _s.siblings[i];
            if (sib.fullname.trim().isEmpty) _err('S${i}_Fullname', 'Required');
            if (sib.nickname.trim().isEmpty) _err('S${i}_Nickname', 'Required');
            if (sib.dob.trim().isEmpty) _err('S${i}_DateofBirth', 'Required');
            if (sib.currentSchool.trim().isEmpty)
              _err('S${i}_School', 'Required');
            if (sib.phone1.trim().isEmpty) _err('S${i}_Phone1', 'Required');
            if (sib.phone2.trim().isEmpty) _err('S${i}_Phone2', 'Required');
            if (sib.village.trim().isEmpty) _err('S${i}_Village', 'Required');
          }
        }
        break;
      case 5:
        if (_s.livingWith.isEmpty) {
          _err(
            'LiveWith_Required',
            'Add at least one person before continuing',
          );
        }
        for (var i = 0; i < _s.livingWith.length; i++) {
          final l = _s.livingWith[i];
          if (l.firstNameLao.trim().isEmpty)
            _err('L${i}_Firstname_Lao', 'Required');
          if (l.firstNameEng.trim().isEmpty)
            _err('L${i}_Firstname_Eng', 'Required');
          if (l.middleNameLao.trim().isEmpty)
            _err('L${i}_Midlename_Lao', 'Required');
          if (l.middleNameEng.trim().isEmpty)
            _err('L${i}_Midlename_Eng', 'Required');
          if (l.lastNameLao.trim().isEmpty)
            _err('L${i}_Lastname_Lao', 'Required');
          if (l.lastNameEng.trim().isEmpty)
            _err('L${i}_Lastname_Eng', 'Required');
          if (l.nickname.trim().isEmpty) _err('L${i}_Nickname', 'Required');
          if (l.educationLevel.trim().isEmpty)
            _err('L${i}_Educatio_Level', 'Required');
          if (l.occupation.trim().isEmpty) _err('L${i}_Job', 'Required');
          if (l.workplace.trim().isEmpty) _err('L${i}_Workplace', 'Required');
          if (l.email.trim().isEmpty) {
            _err('L${i}_Email', 'Required');
          } else if (!RegExp(
            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
          ).hasMatch(l.email.trim())) {
            _err('L${i}_Email', 'Enter a valid email');
          }
          if (l.phone1.trim().isEmpty) _err('L${i}_Phone1', 'Required');
          if (l.phone2.trim().isEmpty) _err('L${i}_Phone2', 'Required');
          if (l.dob.trim().isEmpty) _err('L${i}_DateofBirth', 'Required');
          if (l.idCardNo.trim().isEmpty) _err('L${i}_IDCard_no', 'Required');
          if (l.passportNo.trim().isEmpty)
            _err('L${i}_Passport_no', 'Required');
          if (l.familyBookNo.trim().isEmpty)
            _err('L${i}_FamillyBook_no', 'Required');
          if (l.nationality.trim().isEmpty)
            _err('L${i}_Nationality', 'Required');
          if (l.ethnicity.trim().isEmpty) _err('L${i}_Ethnicty', 'Required');
          if (l.religion.trim().isEmpty) _err('L${i}_Religion', 'Required');
          if (l.homeNo.trim().isEmpty) _err('L${i}_Home_no', 'Required');
          if (l.homeUnit.trim().isEmpty) _err('L${i}_Home_unit', 'Required');
          if (l.village.trim().isEmpty) _err('L${i}_Village', 'Required');
          if (l.district.trim().isEmpty) _err('L${i}_District', 'Required');
          if (l.province.trim().isEmpty) _err('L${i}_Province', 'Required');
        }
        break;
      case 6:
        if (_s.emergencyContacts.isEmpty) {
          _err(
            'Emergency_Required',
            'Add at least one emergency contact before continuing',
          );
        } else {
          for (var i = 0; i < _s.emergencyContacts.length; i++) {
            final e = _s.emergencyContacts[i];
            if (e.fullname.trim().isEmpty) _err('E${i}_Fullname', 'Required');
            if (e.occupation.trim().isEmpty) _err('E${i}_Job', 'Required');
            if (e.workplace.trim().isEmpty)
              _err('E${i}_Working_place', 'Required');
            if (e.phone1.trim().isEmpty) _err('E${i}_Phone1', 'Required');
            if (e.phone2.trim().isEmpty) _err('E${i}_Phone2', 'Required');
            if (e.hospital.trim().isEmpty) _err('E${i}_Hospital', 'Required');
            if (e.docName.trim().isEmpty) _err('E${i}_Doc_name', 'Required');
            if (e.docContact.trim().isEmpty)
              _err('E${i}_Doc_contract', 'Required');
          }
        }
        break;
    }
    setState(() {});
    return _errors.isEmpty;
  }

  void _onNext() {
    if (!_validate() || _step >= 6) return;
    setState(() => _step++);
    _pageController.animateToPage(
      _step - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _onBack() {
    if (_step <= 1) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onSubmit() async {
    if (!_validate() || _submitting) return;
    setState(() => _submitting = true);
    GlobalAlert.showLoading(
      message: widget.addOnly
          ? 'Adding student...'
          : 'Submitting application...',
    );
    try {
      String parentId;
      if (widget.addOnly) {
        parentId = widget.parentId!;
      } else {
        final parentResult = await widget.parentService!.register(
          widget.parentData,
        );
        final parentMap = parentResult.data;
        final id =
            (parentMap['id'] ??
                    parentMap['_id'] ??
                    (parentMap['data'] is Map
                        ? (parentMap['data']['id'] ?? parentMap['data']['_id'])
                        : null))
                ?.toString();
        if (id == null || id.isEmpty) {
          throw ApiException('Could not resolve parent ID from response.');
        }
        parentId = id;
        final fullName = [
          widget.parentData['Firstname_Eng'],
          widget.parentData['Midlename_Eng'],
          widget.parentData['Lastname_Eng'],
        ].where((e) => e != null && e.isNotEmpty).join(' ');
        await widget.parentService!.savePending(
          id: parentId,
          email: widget.parentData['Email'] ?? '',
          fullName: fullName.isEmpty ? null : fullName,
          password: parentResult.password,
        );
      }

      await _studentService.register(s: _s, parentId: parentId);

      GlobalAlert.dismiss();
      if (!mounted) return;
      if (widget.addOnly) {
        GlobalAlert.showSuccess(
          title: 'Student added',
          message:
              'The student has been added to your application. Admin will review all students together.',
        );
        Navigator.of(context).pop(true);
        return;
      }
      // Reload the pending we just saved and return it to the parent page,
      // so it can show the Pending screen without re-reading from disk.
      final pending = await widget.parentService!.loadPending();
      if (!mounted) return;
      Navigator.of(context).pop<Object>(pending ?? true);
    } catch (e) {
      GlobalAlert.dismiss();
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e is ApiException ? e.message : e.toString();
      GlobalAlert.showError(title: 'Submission failed', message: msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blueSofter,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepper(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                onPageChanged: (i) {
                  if (_step != i + 1) setState(() => _step = i + 1);
                },
                itemBuilder: (_, i) => SingleChildScrollView(
                  key: PageStorageKey('s_step_${i + 1}'),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: _buildStep(i + 1),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Header / Stepper
  // ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _navy,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Information',
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
                  'Tell us about your child. Fields marked * are required.',
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
                      margin: const EdgeInsets.symmetric(horizontal: 4),
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
                        builder: (_, v, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
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
                    'STEP $_step OF 6',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _steps[_step - 1].title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              Text(
                '${((_step / 6) * 100).round()}%',
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
      child: Icon(
        completed ? Icons.check_rounded : s.icon,
        color: filled ? Colors.white : _slate400,
        size: 18,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Bottom navigation
  // ──────────────────────────────────────────────────────────────────

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
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _onBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
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
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : (_step < 6 ? _onNext : _onSubmit),
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
                  child: _step < 6
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Next'),
                            SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        )
                      : const Text('Submit application'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Steps
  // ──────────────────────────────────────────────────────────────────

  Widget _buildStep(int step) {
    switch (step) {
      case 1:
        return _stepStudent();
      case 2:
        return _stepAddress();
      case 3:
        return _stepEducation();
      case 4:
        return _stepSiblings();
      case 5:
        return _stepLivingWith();
      case 6:
      default:
        return _stepEmergency();
    }
  }

  Widget _stepStudent() {
    return _section(
      1,
      'Student Information',
      children: [
        _input(
          'First Name (Lao)',
          'Firstname_Lao',
          _s.firstNameLao,
          (v) => _s.firstNameLao = v,
          required: true,
          placeholder: 'Enter (Lao)',
        ),
        _input(
          'First Name (English)',
          'Firstname_Eng',
          _s.firstNameEng,
          (v) => _s.firstNameEng = v,
          required: true,
          placeholder: 'Enter (English)',
        ),
        _input(
          'Middle Name (Lao)',
          'Midlename_Lao',
          _s.middleNameLao,
          (v) => _s.middleNameLao = v,
          required: true,
          placeholder: 'Enter (Lao)',
        ),
        _input(
          'Middle Name (English)',
          'Midlename_Eng',
          _s.middleNameEng,
          (v) => _s.middleNameEng = v,
          required: true,
          placeholder: 'Enter (English)',
        ),
        _input(
          'Last Name (Lao)',
          'Lastname_Lao',
          _s.lastNameLao,
          (v) => _s.lastNameLao = v,
          required: true,
          placeholder: 'Enter (Lao)',
        ),
        _input(
          'Last Name (English)',
          'Lastname_Eng',
          _s.lastNameEng,
          (v) => _s.lastNameEng = v,
          required: true,
          placeholder: 'Enter (English)',
        ),
        _input(
          'Nickname',
          'Nickname',
          _s.nickname,
          (v) => _s.nickname = v,
          required: true,
          placeholder: 'Enter nickname',
        ),
        _dateInput(
          'Date of Birth',
          'DateofBirth',
          _s.dob,
          (v) => _s.dob = v,
          required: true,
        ),
        _select(
          'Gender',
          'Gender',
          _s.gender,
          _genders,
          (v) => _s.gender = v,
          required: true,
          placeholder: 'Select gender',
        ),
        _input(
          'Nationality',
          'Nationality',
          _s.nationality,
          (v) => _s.nationality = v,
          required: true,
          placeholder: 'Enter nationality',
        ),
        _input(
          'Ethnicity',
          'Ethnicity',
          _s.ethnicity,
          (v) => _s.ethnicity = v,
          required: true,
          placeholder: 'Enter ethnicity',
        ),
        _input(
          'Religion',
          'Religion',
          _s.religion,
          (v) => _s.religion = v,
          required: true,
          placeholder: 'Enter religion',
        ),
        _input(
          'Passport No.',
          'Passport_no',
          _s.passportNo,
          (v) => _s.passportNo = v,
          required: true,
          placeholder: 'Enter passport number',
        ),
      ],
    );
  }

  Widget _stepAddress() {
    return Column(
      children: [
        _section(
          1,
          'Place of Birth',
          children: [
            _input(
              'Village of Birth',
              'Village_Birth',
              _s.villageBirth,
              (v) => _s.villageBirth = v,
              required: true,
              placeholder: 'Enter village',
            ),
            _input(
              'District of Birth',
              'District_Birth',
              _s.districtBirth,
              (v) => _s.districtBirth = v,
              required: true,
              placeholder: 'Enter district',
            ),
            _input(
              'Province of Birth',
              'Province_Birth',
              _s.provinceBirth,
              (v) => _s.provinceBirth = v,
              required: true,
              placeholder: 'Enter province',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          2,
          'Current Address',
          children: [
            _input(
              'Village',
              'Village',
              _s.village,
              (v) => _s.village = v,
              required: true,
              placeholder: 'Enter village',
            ),
            _input(
              'District',
              'District',
              _s.district,
              (v) => _s.district = v,
              required: true,
              placeholder: 'Enter district',
            ),
            _input(
              'Province',
              'Province',
              _s.province,
              (v) => _s.province = v,
              required: true,
              placeholder: 'Enter province',
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepEducation() {
    return Column(
      children: [
        _section(
          1,
          'Education History — Kindergarten',
          children: [
            _input(
              'Academic Year',
              'Academic_Year1',
              _s.kindergarten.academicYear,
              (v) => _s.kindergarten.academicYear = v,
              required: true,
              placeholder: 'e.g. 2019-2020',
            ),
            _select(
              'Year / Level',
              'Year_Level1',
              _s.kindergarten.yearLevel,
              _yearLevels,
              (v) => _s.kindergarten.yearLevel = v,
              required: true,
              placeholder: 'Select level',
            ),
            _input(
              'School',
              'School1',
              _s.kindergarten.school,
              (v) => _s.kindergarten.school = v,
              required: true,
              placeholder: 'Enter school name',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          2,
          'Education History — Primary School',
          children: [
            _input(
              'Academic Year',
              'Academic_Year2',
              _s.primary.academicYear,
              (v) => _s.primary.academicYear = v,
              required: true,
              placeholder: 'e.g. 2022-2023',
            ),
            _select(
              'Year / Level',
              'Year_Level2',
              _s.primary.yearLevel,
              _yearLevels,
              (v) => _s.primary.yearLevel = v,
              required: true,
              placeholder: 'Select level',
            ),
            _input(
              'School',
              'School2',
              _s.primary.school,
              (v) => _s.primary.school = v,
              required: true,
              placeholder: 'Enter school name',
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepSiblings() {
    final missing = _errors.containsKey('Bos_Required');
    return Column(
      children: [
        for (var i = 0; i < _s.siblings.length; i++) ...[
          _siblingCard(i),
          const SizedBox(height: 14),
        ],
        _addCardButton(
          label: _s.siblings.isEmpty ? 'Add a sibling' : 'Add another sibling',
          onTap: () {
            setState(() {
              _s.siblings.add(SiblingEntry());
              _errors.remove('Bos_Required');
            });
          },
        ),
        if (_s.siblings.isEmpty) ...[
          const SizedBox(height: 14),
          _emptyHint(
            icon: Icons.group_outlined,
            title: missing
                ? 'At least one sibling is required'
                : 'No siblings added yet',
            body:
                'Add brothers or sisters who are direct relatives of the student.',
            error: missing,
          ),
        ],
      ],
    );
  }

  Widget _siblingCard(int i) {
    final sib = _s.siblings[i];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: const BoxDecoration(
                  color: _blue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'SIBLING',
                  style: TextStyle(
                    fontSize: 12,
                    color: _blue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => setState(() => _s.siblings.removeAt(i)),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: _rose500,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(color: _slate100, height: 20),
          _input(
            'Full Name',
            'S${i}_Fullname',
            sib.fullname,
            (v) => sib.fullname = v,
            required: true,
            placeholder: 'Enter full name',
          ),
          const SizedBox(height: 12),
          _input(
            'Nickname',
            'S${i}_Nickname',
            sib.nickname,
            (v) => sib.nickname = v,
            required: true,
            placeholder: 'Enter nickname',
          ),
          const SizedBox(height: 12),
          _dateInput(
            'Date of Birth',
            'S${i}_DateofBirth',
            sib.dob,
            (v) => sib.dob = v,
            required: true,
          ),
          const SizedBox(height: 12),
          _input(
            'Current School Name',
            'S${i}_School',
            sib.currentSchool,
            (v) => sib.currentSchool = v,
            required: true,
            placeholder: 'Enter current school',
          ),
          const SizedBox(height: 12),
          _input(
            'Phone No. 1',
            'S${i}_Phone1',
            sib.phone1,
            (v) => sib.phone1 = v,
            required: true,
            placeholder: 'Enter phone 1',
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _input(
            'Phone No. 2',
            'S${i}_Phone2',
            sib.phone2,
            (v) => sib.phone2 = v,
            required: true,
            placeholder: 'Enter phone 2',
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _input(
            'Village',
            'S${i}_Village',
            sib.village,
            (v) => sib.village = v,
            required: true,
            placeholder: 'Enter village',
          ),
        ],
      ),
    );
  }

  Widget _stepLivingWith() {
    final missing = _errors.containsKey('LiveWith_Required');
    return Column(
      children: [
        for (var i = 0; i < _s.livingWith.length; i++) ...[
          _livingCard(i),
          const SizedBox(height: 14),
        ],
        _addCardButton(
          label: _s.livingWith.isEmpty
              ? 'Add a person living with student'
              : 'Add another person',
          onTap: () {
            setState(() {
              _s.livingWith.add(LiveWithEntry());
              _livingExpanded.add(_s.livingWith.length - 1);
              _errors.remove('LiveWith_Required');
            });
          },
        ),
        if (_s.livingWith.isEmpty) ...[
          const SizedBox(height: 14),
          _emptyHint(
            icon: Icons.home_outlined,
            title: missing
                ? 'At least one person is required'
                : 'No one added yet',
            body: 'Add at least one person who lives with the student.',
            error: missing,
          ),
        ],
      ],
    );
  }

  Widget _livingCard(int i) {
    final p = _s.livingWith[i];
    final expanded = _livingExpanded.contains(i);
    final summary = [
      p.firstNameEng,
      p.lastNameEng,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                if (expanded) {
                  _livingExpanded.remove(i);
                } else {
                  _livingExpanded.add(i);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 26,
                    width: 26,
                    decoration: const BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PERSON LIVING WITH STUDENT',
                          style: TextStyle(
                            fontSize: 11,
                            color: _blue,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary.isEmpty ? 'Tap to expand' : summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: summary.isEmpty ? _muted : _navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => setState(() {
                      _s.livingWith.removeAt(i);
                      _livingExpanded.remove(i);
                    }),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: _rose500,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(color: _slate100, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _input(
                    'First Name (Lao)',
                    'L${i}_Firstname_Lao',
                    p.firstNameLao,
                    (v) => p.firstNameLao = v,
                    required: true,
                    placeholder: 'Enter (Lao)',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'First Name (English)',
                    'L${i}_Firstname_Eng',
                    p.firstNameEng,
                    (v) => p.firstNameEng = v,
                    required: true,
                    placeholder: 'Enter (English)',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Middle Name (Lao)',
                    'L${i}_Midlename_Lao',
                    p.middleNameLao,
                    (v) => p.middleNameLao = v,
                    required: true,
                    placeholder: 'Enter (Lao)',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Middle Name (English)',
                    'L${i}_Midlename_Eng',
                    p.middleNameEng,
                    (v) => p.middleNameEng = v,
                    required: true,
                    placeholder: 'Enter (English)',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Last Name (Lao)',
                    'L${i}_Lastname_Lao',
                    p.lastNameLao,
                    (v) => p.lastNameLao = v,
                    required: true,
                    placeholder: 'Enter (Lao)',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Last Name (English)',
                    'L${i}_Lastname_Eng',
                    p.lastNameEng,
                    (v) => p.lastNameEng = v,
                    required: true,
                    placeholder: 'Enter (English)',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Nickname',
                    'L${i}_Nickname',
                    p.nickname,
                    (v) => p.nickname = v,
                    required: true,
                    placeholder: 'Enter nickname',
                  ),
                  const SizedBox(height: 12),
                  _select(
                    'Education Level',
                    'L${i}_Educatio_Level',
                    p.educationLevel,
                    _educationLevels,
                    (v) => p.educationLevel = v,
                    required: true,
                    placeholder: 'Select level',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Occupation',
                    'L${i}_Job',
                    p.occupation,
                    (v) => p.occupation = v,
                    required: true,
                    placeholder: 'Enter occupation',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Workplace',
                    'L${i}_Workplace',
                    p.workplace,
                    (v) => p.workplace = v,
                    required: true,
                    placeholder: 'Enter workplace',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Email',
                    'L${i}_Email',
                    p.email,
                    (v) => p.email = v,
                    required: true,
                    placeholder: 'Enter email',
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Phone No. 1',
                    'L${i}_Phone1',
                    p.phone1,
                    (v) => p.phone1 = v,
                    required: true,
                    placeholder: 'Enter phone 1',
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Phone No. 2',
                    'L${i}_Phone2',
                    p.phone2,
                    (v) => p.phone2 = v,
                    required: true,
                    placeholder: 'Enter phone 2',
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _dateInput(
                    'Date of Birth',
                    'L${i}_DateofBirth',
                    p.dob,
                    (v) => p.dob = v,
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'ID Card No.',
                    'L${i}_IDCard_no',
                    p.idCardNo,
                    (v) => p.idCardNo = v,
                    required: true,
                    placeholder: 'Enter ID card no.',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Passport No.',
                    'L${i}_Passport_no',
                    p.passportNo,
                    (v) => p.passportNo = v,
                    required: true,
                    placeholder: 'Enter passport no.',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Family Book No.',
                    'L${i}_FamillyBook_no',
                    p.familyBookNo,
                    (v) => p.familyBookNo = v,
                    required: true,
                    placeholder: 'Enter family book no.',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Nationality',
                    'L${i}_Nationality',
                    p.nationality,
                    (v) => p.nationality = v,
                    required: true,
                    placeholder: 'Enter nationality',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Ethnicity',
                    'L${i}_Ethnicty',
                    p.ethnicity,
                    (v) => p.ethnicity = v,
                    required: true,
                    placeholder: 'Enter ethnicity',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Religion',
                    'L${i}_Religion',
                    p.religion,
                    (v) => p.religion = v,
                    required: true,
                    placeholder: 'Enter religion',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'House No.',
                    'L${i}_Home_no',
                    p.homeNo,
                    (v) => p.homeNo = v,
                    required: true,
                    placeholder: 'Enter house no.',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'House Unit',
                    'L${i}_Home_unit',
                    p.homeUnit,
                    (v) => p.homeUnit = v,
                    required: true,
                    placeholder: 'Enter unit / room',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Village',
                    'L${i}_Village',
                    p.village,
                    (v) => p.village = v,
                    required: true,
                    placeholder: 'Enter village',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'District',
                    'L${i}_District',
                    p.district,
                    (v) => p.district = v,
                    required: true,
                    placeholder: 'Enter district',
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Province',
                    'L${i}_Province',
                    p.province,
                    (v) => p.province = v,
                    required: true,
                    placeholder: 'Enter province',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepEmergency() {
    final missing = _errors.containsKey('Emergency_Required');
    return Column(
      children: [
        for (var i = 0; i < _s.emergencyContacts.length; i++) ...[
          _emergencyCard(i),
          const SizedBox(height: 14),
        ],
        _addCardButton(
          label: _s.emergencyContacts.isEmpty
              ? 'Add an emergency contact'
              : 'Add another emergency contact',
          onTap: () {
            setState(() {
              _s.emergencyContacts.add(EmergencyContactEntry());
              _errors.remove('Emergency_Required');
            });
          },
        ),
        if (_s.emergencyContacts.isEmpty) ...[
          const SizedBox(height: 14),
          _emptyHint(
            icon: Icons.warning_amber_rounded,
            title: missing
                ? 'At least one emergency contact is required'
                : 'No emergency contact added yet',
            body:
                'Add one or more emergency contacts the school can reach if needed.',
            error: missing,
          ),
        ],
      ],
    );
  }

  Widget _emergencyCard(int i) {
    final e = _s.emergencyContacts[i];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: const BoxDecoration(
                  color: _blue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'EMERGENCY CONTACT',
                  style: TextStyle(
                    fontSize: 12,
                    color: _blue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () =>
                    setState(() => _s.emergencyContacts.removeAt(i)),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: _rose500,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(color: _slate100, height: 20),
          _input(
            'Full Name',
            'E${i}_Fullname',
            e.fullname,
            (v) => e.fullname = v,
            required: true,
            placeholder: 'Enter full name',
          ),
          const SizedBox(height: 12),
          _input(
            'Occupation',
            'E${i}_Job',
            e.occupation,
            (v) => e.occupation = v,
            required: true,
            placeholder: 'Enter occupation',
          ),
          const SizedBox(height: 12),
          _input(
            'Workplace',
            'E${i}_Working_place',
            e.workplace,
            (v) => e.workplace = v,
            required: true,
            placeholder: 'Enter workplace',
          ),
          const SizedBox(height: 12),
          _input(
            'Phone No. 1',
            'E${i}_Phone1',
            e.phone1,
            (v) => e.phone1 = v,
            required: true,
            placeholder: 'Enter phone 1',
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _input(
            'Phone No. 2',
            'E${i}_Phone2',
            e.phone2,
            (v) => e.phone2 = v,
            required: true,
            placeholder: 'Enter phone 2',
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _input(
            'Hospital',
            'E${i}_Hospital',
            e.hospital,
            (v) => e.hospital = v,
            required: true,
            placeholder: 'Enter hospital name',
          ),
          const SizedBox(height: 12),
          _input(
            'Doctor Name',
            'E${i}_Doc_name',
            e.docName,
            (v) => e.docName = v,
            required: true,
            placeholder: 'Enter doctor name',
          ),
          const SizedBox(height: 12),
          _input(
            'Doctor Contact',
            'E${i}_Doc_contract',
            e.docContact,
            (v) => e.docContact = v,
            required: true,
            placeholder: 'Enter doctor contact',
            keyboard: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Reusable widgets
  // ──────────────────────────────────────────────────────────────────

  Widget _section(int num, String label, {required List<Widget> children}) {
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
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _slate100),
          const SizedBox(height: 20),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _addCardButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            border: Border.all(
              color: _blueSoft,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: const BoxDecoration(
                  color: _blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHint({
    required IconData icon,
    required String title,
    required String body,
    bool error = false,
  }) {
    final bg = error ? const Color(0xFFFFF1F2) : _blueSofter;
    final border = error ? _rose500.withValues(alpha: .4) : _slate100;
    final tile = error ? _rose500.withValues(alpha: .12) : _blueSoft;
    final iconColor = error ? _rose500 : _blue;
    final titleColor = error ? _rose500 : _navy;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: tile,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              error ? Icons.error_outline_rounded : icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
    String key,
    String value,
    ValueChanged<String> onChanged, {
    String? placeholder,
    bool required = false,
    TextInputType? keyboard,
  }) {
    final err = _errors[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required),
        TextFormField(
          key: ValueKey('inp_$key'),
          initialValue: value,
          onChanged: (v) {
            onChanged(v);
            if (_errors.containsKey(key)) {
              setState(() => _errors.remove(key));
            }
          },
          keyboardType: keyboard,
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(placeholder, err),
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
    String key,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    String? placeholder,
    bool required = false,
  }) {
    final err = _errors[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required),
        DropdownButtonFormField<String>(
          initialValue: options.contains(value) ? value : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
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
            if (v != null) {
              onChanged(v);
              if (_errors.containsKey(key)) {
                setState(() => _errors.remove(key));
              }
            }
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

  Widget _dateInput(
    String label,
    String key,
    String value,
    ValueChanged<String> onChanged, {
    bool required = false,
  }) {
    final err = _errors[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            DateTime initial = now;
            if (value.isNotEmpty) {
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
              final iso =
                  '${picked.year.toString().padLeft(4, '0')}-'
                  '${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
              onChanged(iso);
              setState(() {
                if (_errors.containsKey(key)) _errors.remove(key);
              });
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: _decoration(null, err).copyWith(
              suffixIcon: const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: _muted,
              ),
            ),
            child: Text(
              value.isEmpty ? 'YYYY-MM-DD' : value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: value.isEmpty ? _slate400 : _navy,
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
}

class _StepMeta {
  final int id;
  final String title;
  final IconData icon;
  const _StepMeta(this.id, this.title, this.icon);
}

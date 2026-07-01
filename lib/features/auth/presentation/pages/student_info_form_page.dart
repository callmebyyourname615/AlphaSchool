import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/global_alert_service.dart';
import '../../data/parent_registration_service.dart';
import '../../data/student_registration_service.dart';
import 'student_pending_page.dart';

class StudentInfoFormPage extends StatefulWidget {
  /// Combined-registration mode: include parent data + service so we POST
  /// /parents first, then /students.
  const StudentInfoFormPage({
    super.key,
    required this.parentData,
    required this.parentService,
  }) : parentId = null,
       addOnly = false,
       resubmitStudentId = null;

  /// Add-student-only mode (from the Pending screen). Skips parent POST,
  /// only calls POST /students with [parentId].
  const StudentInfoFormPage.addOnly({super.key, required this.parentId})
    : parentData = const {},
      parentService = null,
      addOnly = true,
      resubmitStudentId = null;

  /// Resubmit mode (from the Pending screen after admin rejected). Loads
  /// existing data and PUTs /students/:id to clear the rejection.
  const StudentInfoFormPage.resubmit({
    super.key,
    required this.resubmitStudentId,
    required this.parentId,
  }) : parentData = const {},
       parentService = null,
       addOnly = true;

  final Map<String, String> parentData;
  final ParentRegistrationService? parentService;
  final String? parentId;
  final bool addOnly;
  final String? resubmitStudentId;

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
    _StepMeta(1, 'Student', LucideIcons.user),
    _StepMeta(2, 'Address', LucideIcons.mapPin),
    _StepMeta(3, 'Education', LucideIcons.school),
    _StepMeta(4, 'Sibling', LucideIcons.users),
    _StepMeta(5, 'Live With', LucideIcons.house),
    _StepMeta(6, 'Emergency', LucideIcons.hospital),
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
  bool _prefilling = false;
  final Set<int> _livingExpanded = {};

  List<_ProvinceOption> _provinces = const [];
  bool _provincesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    if (widget.resubmitStudentId != null) {
      _prefilling = true;
      _prefillFromExisting(widget.resubmitStudentId!)
          .whenComplete(() {
        if (mounted) setState(() => _prefilling = false);
      });
    }
  }

  Future<void> _loadProvinces() async {
    if (_provincesLoading) return;
    setState(() => _provincesLoading = true);
    try {
      final res = await ApiClient().get('/locations/province');
      final raw = res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] as List : const []);
      final list = raw
          .whereType<Map>()
          .map((m) => _ProvinceOption.fromJson(Map<String, dynamic>.from(m)))
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

  _ProvinceOption? _findProvince(String id) {
    for (final p in _provinces) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _prefillFromExisting(String studentId) async {
    // Prefer the local draft (preserves anything the parent had typed,
    // including fields the backend may not echo back) and only hit the API
    // when no draft exists yet.
    final draft = await StudentDraftStore.load(studentId);
    if (draft != null) {
      if (!mounted) return;
      setState(() {
        _s
          ..firstNameLao = draft.firstNameLao
          ..firstNameEng = draft.firstNameEng
          ..middleNameLao = draft.middleNameLao
          ..middleNameEng = draft.middleNameEng
          ..lastNameLao = draft.lastNameLao
          ..lastNameEng = draft.lastNameEng
          ..nickname = draft.nickname
          ..dob = draft.dob
          ..gender = draft.gender
          ..nationality = draft.nationality
          ..ethnicity = draft.ethnicity
          ..religion = draft.religion
          ..passportNo = draft.passportNo
          ..villageBirth = draft.villageBirth
          ..districtBirth = draft.districtBirth
          ..provinceBirth = draft.provinceBirth
          ..village = draft.village
          ..district = draft.district
          ..province = draft.province
          ..districtId = draft.districtId
          ..provinceId = draft.provinceId
          ..districtName = draft.districtName
          ..provinceName = draft.provinceName;
        _s.kindergarten
          ..academicYear = draft.kindergarten.academicYear
          ..yearLevel = draft.kindergarten.yearLevel
          ..school = draft.kindergarten.school;
        _s.primary
          ..academicYear = draft.primary.academicYear
          ..yearLevel = draft.primary.yearLevel
          ..school = draft.primary.school;
        _s.siblings
          ..clear()
          ..addAll(draft.siblings);
        _s.livingWith
          ..clear()
          ..addAll(draft.livingWith);
        _s.emergencyContacts
          ..clear()
          ..addAll(draft.emergencyContacts);
      });
      return;
    }
    try {
      final res = await ApiClient().get('/students/$studentId');
      final record = res is Map<String, dynamic>
          ? res
          : (res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
      if (!mounted) return;
      _hydrate(record);
    } catch (_) {
      // Soft-fail — the user can still fill the form manually.
    }
  }

  String _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  void _hydrate(Map<String, dynamic> r) {
    _s
      ..firstNameLao = _str(r, ['first_name_lao'])
      ..firstNameEng = _str(r, ['first_name_eng'])
      ..middleNameLao = _str(r, ['midle_name_lao', 'middle_name_lao'])
      ..middleNameEng = _str(r, ['midle_name_eng', 'middle_name_eng'])
      ..lastNameLao = _str(r, ['last_name_lao'])
      ..lastNameEng = _str(r, ['last_name_eng'])
      ..nickname = _str(r, ['nickname'])
      ..dob = _str(r, ['dob']).split('T').first
      ..gender = _str(r, ['gender'])
      ..nationality = _str(r, ['nationality'])
      ..ethnicity = _str(r, ['ethnicity'])
      ..religion = _str(r, ['religion'])
      ..passportNo = _str(r, ['passport_number', 'passport_no'])
      ..villageBirth = _str(r, ['village_bd'])
      ..village = _str(r, ['village']);
    // dm_birth was joined as "village, district, province"
    final dm = _str(r, ['dm_birth']).split(',').map((e) => e.trim()).toList();
    if (dm.length >= 2) _s.districtBirth = dm[1];
    if (dm.length >= 3) _s.provinceBirth = dm[2];
    final district = r['district'];
    if (district is Map) {
      _s.districtId = (district['id'] ?? '').toString();
      _s.districtName =
          (district['nameEn'] ?? district['nameLa'] ?? '').toString();
      _s.district = _s.districtName;
    } else if (district is String) {
      _s.district = district;
    }
    final province = r['province'];
    if (province is Map) {
      _s.provinceId = (province['id'] ?? '').toString();
      _s.provinceName =
          (province['nameEn'] ?? province['nameLa'] ?? '').toString();
      _s.province = _s.provinceName;
    } else if (province is String) {
      _s.province = province;
    }
    final kg = (r['his_school_kindergarten'] as List?)?.cast<Map>().firstOrNull;
    if (kg != null) {
      _s.kindergarten
        ..academicYear = (kg['academic_year'] ?? '').toString()
        ..yearLevel = (kg['year_level'] ?? '').toString()
        ..school = (kg['school'] ?? '').toString();
    }
    final pr = (r['his_school_primary'] as List?)?.cast<Map>().firstOrNull;
    if (pr != null) {
      _s.primary
        ..academicYear = (pr['academic_year'] ?? '').toString()
        ..yearLevel = (pr['year_level'] ?? '').toString()
        ..school = (pr['school'] ?? '').toString();
    }
    _s.siblings
      ..clear()
      ..addAll((r['bos_info'] as List? ?? []).whereType<Map>().map((b) {
        return SiblingEntry()
          ..fullname = (b['fullname'] ?? '').toString()
          ..nickname = (b['nickname'] ?? '').toString()
          ..dob = (b['dob'] ?? '').toString().split('T').first
          ..currentSchool = (b['current_school'] ?? '').toString()
          ..phone1 = (b['phone1'] ?? '').toString()
          ..phone2 = (b['phone2'] ?? '').toString()
          ..village = (b['current_village'] ?? b['village'] ?? '').toString();
      }));
    _s.livingWith
      ..clear()
      ..addAll((r['live_with'] as List? ?? []).whereType<Map>().map((l) {
        // Prefer the split name fields when present; fall back to splitting
        // the joined "fullname" for older records.
        final names = (l['fullname'] ?? '').toString().split(' ');
        return LiveWithEntry()
          ..firstNameLao = (l['first_name_lao'] ?? '').toString()
          ..firstNameEng = (l['first_name_eng'] ??
                  (names.isNotEmpty ? names.first : ''))
              .toString()
          ..middleNameLao = (l['midle_name_lao'] ?? '').toString()
          ..middleNameEng = (l['midle_name_eng'] ??
                  (names.length > 2
                      ? names.sublist(1, names.length - 1).join(' ')
                      : ''))
              .toString()
          ..lastNameLao = (l['last_name_lao'] ?? '').toString()
          ..lastNameEng = (l['last_name_eng'] ??
                  (names.length > 1 ? names.last : ''))
              .toString()
          ..occupation = (l['occupation'] ?? '').toString()
          ..nickname = (l['nickname'] ?? '').toString()
          ..dob = (l['dob'] ?? '').toString().split('T').first
          ..idCardNo = (l['id_card'] ?? '').toString()
          ..passportNo = (l['passport_no'] ?? '').toString()
          ..familyBookNo = (l['family_book_no'] ?? '').toString()
          ..nationality = (l['nationality'] ?? '').toString()
          ..ethnicity = (l['ethnicity'] ?? '').toString()
          ..religion = (l['religion'] ?? '').toString()
          ..educationLevel = (l['education_level'] ?? '').toString()
          ..workplace = (l['working_place'] ?? '').toString()
          ..email = (l['email'] ?? '').toString()
          ..phone1 = (l['phone_number_one'] ?? '').toString()
          ..phone2 = (l['phone_number_two'] ?? '').toString()
          ..homeNo = (l['home_no'] ?? '').toString()
          ..homeUnit = (l['home_unit'] ?? '').toString()
          ..village = (l['current_village'] ?? '').toString()
          ..district = (l['current_district'] ?? '').toString()
          ..province = (l['current_province'] ?? '').toString();
      }));
    _s.emergencyContacts
      ..clear()
      ..addAll((r['emergency_contacts'] as List? ?? []).whereType<Map>().map((e) {
        return EmergencyContactEntry()
          ..fullname = (e['fullname'] ?? '').toString()
          ..occupation = (e['job'] ?? '').toString()
          ..workplace = (e['working_place'] ?? '').toString()
          ..phone1 = (e['phone1'] ?? '').toString()
          ..phone2 = (e['phone2'] ?? '').toString()
          ..hospital = (e['hospital'] ?? '').toString()
          ..docName = (e['doc_name'] ?? '').toString()
          ..docContact = (e['doc_contract'] ?? '').toString();
      }));
    if (_s.emergencyContacts.isEmpty) {
      _s.emergencyContacts.add(EmergencyContactEntry());
    }
    setState(() {});
  }

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
    if (_step <= 1) {
      Navigator.of(context).pop();
      return;
    }
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
      message: widget.resubmitStudentId != null
          ? 'Resubmitting application...'
          : widget.addOnly
              ? 'Adding student...'
              : 'Submitting application...',
    );
    try {
      if (widget.resubmitStudentId != null) {
        await _studentService.resubmit(
          studentId: widget.resubmitStudentId!,
          s: _s,
        );
        // Refresh the local draft with the latest edits so a future rejection
        // still finds the most recent values.
        await StudentDraftStore.save(widget.resubmitStudentId!, _s);
        GlobalAlert.dismiss();
        if (!mounted) return;
        Navigator.of(context).pop<Object>('resubmitted');
        return;
      }
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

      final studentRes = await _studentService.register(
        s: _s,
        parentId: parentId,
      );

      // Cache the submitted form keyed by the new student id so a later
      // rejection can re-open the form with everything still filled in.
      final newStudentId = (studentRes['id'] ?? studentRes['_id'])?.toString();
      if (newStudentId != null && newStudentId.isNotEmpty) {
        await StudentDraftStore.save(newStudentId, _s);
      }

      GlobalAlert.dismiss();
      if (!mounted) return;
      if (widget.addOnly) {
        final fullName = [
          _s.firstNameEng,
          _s.middleNameEng,
          _s.lastNameEng,
        ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');
        final fallbackLao = [
          _s.firstNameLao,
          _s.lastNameLao,
        ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');
        final displayName = fullName.isNotEmpty
            ? fullName
            : (fallbackLao.isNotEmpty ? fallbackLao : 'your child');
        final newId = (studentRes['id'] ?? studentRes['_id'])?.toString() ?? '';
        final localId = (studentRes['student_id'] ?? '').toString();
        // Keep this form route in the stack while the pending screen is open.
        // Its result is forwarded to Choose Student, allowing the parent to
        // start another application or simply finish the flow.
        final pendingResult = await Navigator.of(context).push<Object?>(
          MaterialPageRoute(
            builder: (_) => StudentPendingPage(
              studentId: newId,
              studentName: displayName,
              studentLocalId: localId.isEmpty ? null : localId,
              nickname: _s.nickname.trim().isEmpty ? null : _s.nickname.trim(),
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop<Object?>(pendingResult);
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
    if (_prefilling) {
      // Defer building the form until the cached student data has been
      // hydrated into [_s]. TextFormField's [initialValue] is only read on
      // first build, so rendering before prefill completes would leave every
      // input visually empty even though _s holds the real values.
      return Scaffold(
        backgroundColor: _blueSofter,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _blue),
                      SizedBox(height: 16),
                      Text(
                        'Loading your previous answers...',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
            icon: const Icon(LucideIcons.arrowLeft, size: 18, color: _navy),
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
        completed ? LucideIcons.check : s.icon,
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
                            Icon(LucideIcons.chevronRight, size: 18),
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
            _provinceDropdown(
              label: 'Province of Birth',
              errorKey: 'Province_Birth',
              currentLabel: _s.provinceBirth,
              onPicked: (label) => setState(() {
                _s.provinceBirth = label;
                _s.districtBirth = '';
                _errors.remove('Province_Birth');
                _errors.remove('District_Birth');
              }),
            ),
            _districtDropdown(
              label: 'District of Birth',
              errorKey: 'District_Birth',
              provinceLabel: _s.provinceBirth,
              currentLabel: _s.districtBirth,
              onPicked: (label) => setState(() {
                _s.districtBirth = label;
                _errors.remove('District_Birth');
              }),
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
            _provinceSelect(),
            _districtSelect(),
          ],
        ),
      ],
    );
  }

  _ProvinceOption? _provinceByLabel(String label) {
    if (label.trim().isEmpty) return null;
    final lc = label.trim().toLowerCase();
    for (final p in _provinces) {
      if (p.label.toLowerCase() == lc) return p;
    }
    return null;
  }

  /// Label-only province dropdown (used where the backend stores the province
  /// as a free-text string, e.g. Place of Birth and Living-With entries).
  Widget _provinceDropdown({
    required String label,
    required String errorKey,
    required String currentLabel,
    required void Function(String label) onPicked,
  }) {
    final err = _errors[errorKey];
    final selected = _provinceByLabel(currentLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, true),
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
                  final picked = _findProvince(v);
                  if (picked != null) onPicked(picked.label);
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

  Widget _districtDropdown({
    required String label,
    required String errorKey,
    required String provinceLabel,
    required String currentLabel,
    required void Function(String label) onPicked,
  }) {
    final err = _errors[errorKey];
    final province = _provinceByLabel(provinceLabel);
    final districts = province?.districts ?? const [];
    final selected = districts.firstWhere(
      (d) => d.label.toLowerCase() == currentLabel.trim().toLowerCase(),
      orElse: () => const _DistrictOption(id: '', label: ''),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, true),
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
                  final picked =
                      districts.firstWhere((d) => d.id == v);
                  onPicked(picked.label);
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

  Widget _provinceSelect() {
    final err = _errors['Province'];
    final value = _s.provinceId.isNotEmpty &&
            _provinces.any((p) => p.id == _s.provinceId)
        ? _s.provinceId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Province', true),
        DropdownButtonFormField<String>(
          initialValue: value,
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
                  final picked = _findProvince(v);
                  setState(() {
                    _s.provinceId = v;
                    _s.provinceName = picked?.label ?? '';
                    _s.province = picked?.label ?? '';
                    _s.districtId = '';
                    _s.districtName = '';
                    _s.district = '';
                    _errors.remove('Province');
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

  Widget _districtSelect() {
    final err = _errors['District'];
    final province = _findProvince(_s.provinceId);
    final districts = province?.districts ?? const [];
    final value = _s.districtId.isNotEmpty &&
            districts.any((d) => d.id == _s.districtId)
        ? _s.districtId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('District', true),
        DropdownButtonFormField<String>(
          initialValue: value,
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
                    _s.districtId = v;
                    _s.districtName = picked.label;
                    _s.district = picked.label;
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
            icon: LucideIcons.users,
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
                icon: const Icon(LucideIcons.trash2, color: _rose500, size: 20),
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
            icon: LucideIcons.house,
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
                      LucideIcons.trash2,
                      color: _rose500,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
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
                  _provinceDropdown(
                    label: 'Province',
                    errorKey: 'L${i}_Province',
                    currentLabel: p.province,
                    onPicked: (label) => setState(() {
                      p.province = label;
                      p.district = '';
                      _errors.remove('L${i}_Province');
                      _errors.remove('L${i}_District');
                    }),
                  ),
                  const SizedBox(height: 12),
                  _districtDropdown(
                    label: 'District',
                    errorKey: 'L${i}_District',
                    provinceLabel: p.province,
                    currentLabel: p.district,
                    onPicked: (label) => setState(() {
                      p.district = label;
                      _errors.remove('L${i}_District');
                    }),
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
            icon: LucideIcons.triangleAlert,
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
                icon: const Icon(LucideIcons.trash2, color: _rose500, size: 20),
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
                  LucideIcons.plus,
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
              error ? LucideIcons.circleAlert : icon,
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
                LucideIcons.calendarDays,
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

class _ProvinceOption {
  final String id;
  final String label;
  final List<_DistrictOption> districts;

  const _ProvinceOption({
    required this.id,
    required this.label,
    required this.districts,
  });

  factory _ProvinceOption.fromJson(Map<String, dynamic> j) {
    final raw = (j['districts'] as List?) ?? const [];
    return _ProvinceOption(
      id: (j['id'] ?? '').toString(),
      label: (j['nameEn'] ?? j['nameLa'] ?? j['name'] ?? '').toString(),
      districts: raw
          .whereType<Map>()
          .map((d) => _DistrictOption.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }
}

class _DistrictOption {
  final String id;
  final String label;
  const _DistrictOption({required this.id, required this.label});

  factory _DistrictOption.fromJson(Map<String, dynamic> j) => _DistrictOption(
        id: (j['id'] ?? '').toString(),
        label: (j['nameEn'] ?? j['nameLa'] ?? j['name'] ?? '').toString(),
      );
}

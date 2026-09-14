import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../../../../core/theme/app_icons.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
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
  static const _green = Color(0xFF16A34A);
  static const _greenSoft = Color(0xFFDFF8EA);
  static const bool _disableRequiredValidationForTesting = false;
  static final TextInputFormatter _dateInputFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
        final formatted = _formatDateDigits(newValue.text);
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      });

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
      'Lastname_Lao',
      'Lastname_Eng',
      'Nickname',
      'DateofBirth',
      'Gender',
    ],
    2: ['Educatio_Level', 'Job', 'Workplace', 'Phone_No1', 'Phone_No2'],
    3: [
      'Passport_no',
      'IDCard_no',
      'FamillyBook_no',
      'Nationality',
      'Ethnicty',
      'Religion',
    ],
    4: ['Home_no', 'Home_unit', 'Province', 'District', 'Village'],
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

  static String _formatDateDigits(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    if (clipped.length <= 2) return clipped;
    if (clipped.length <= 4) {
      return '${clipped.substring(0, 2)}/${clipped.substring(2)}';
    }
    return '${clipped.substring(0, 2)}/${clipped.substring(2, 4)}/${clipped.substring(4)}';
  }

  static String _displayDate(String? value) {
    final text = value?.trim() ?? '';
    if (_isDatePlaceholder(text)) return '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return text;
    return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
  }

  static String _storeDateInput(String value) {
    final text = value.trim();
    if (_isDatePlaceholder(text)) return '';
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
    if (match == null) return text;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return text;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return text;
    }

    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static bool _isDatePlaceholder(String value) {
    final text = value.trim().toUpperCase();
    return text.isEmpty ||
        text == 'YYYY-MM-DD' ||
        text == 'DD/MM/YYYY' ||
        text == 'DAY/MONTH/YEAR' ||
        value.contains('ວັນ') ||
        value.contains('ເດືອນ');
  }

  int _step = 1;
  final Map<String, String> _data = {};
  final Map<String, String> _errors = {};
  final Map<String, _ParentAttachmentDraft> _attachments = {};
  final List<_FamilyBookImageDraft> _familyBookImages = [];
  bool _processingFamilyBook = false;
  bool _submitted = false;
  bool _submitting = false;
  String _submissionMessage = '';
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
  String _provincesError = '';
  bool _hasSavedDetails = false;
  int _formRevision = 0;

  String _t(String key) => AppLocalizations.of(context).t(key);

  String _datePlaceholder() {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'lo' || code == 'la' ? 'ວັນ/ເດືອນ/ປີ' : 'Day/Month/Year';
  }

  String _nicknameLabel() {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'lo' || code == 'la'
        ? 'ຊື່ຫລິ້ນ (ອັງກິດ)'
        : 'Nickname (English)';
  }

  String _phonePlaceholder() {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'lo' || code == 'la'
        ? 'ພິມເບີໂທ 020XXXXXXXX'
        : 'Enter phone 020XXXXXXXX';
  }

  bool get _isLaoLocale {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'lo' || code == 'la';
  }

  String _parentPlaceholder(String key) {
    final text = _t(key);
    return _isLaoLocale ? text.replaceFirst('ປ້ອນ', 'ພິມ') : text;
  }

  String _parentAddressLabel(String lao, String english) =>
      _isLaoLocale ? lao : english;

  String _parentAddressHint(String lao, String english) =>
      _isLaoLocale ? lao : english;

  String _identityCardUploadLabel() =>
      _isLaoLocale ? 'ຮູບບັດປະຈຳຕົວ' : 'Identity card image';

  String _familyBookUploadLabel() => _isLaoLocale
      ? 'ຮູບປຶ້ມສຳມະໂນຄົວ (PDF ຫຼື ຮູບ)'
      : 'Family book image (PDF or image)';

  String _stepOfLabel() => _t('stepOf').replaceAll('{step}', '$_step');

  String _optionLabel(String option) {
    switch (option) {
      case 'Primary School':
        return _t('primarySchool');
      case 'Secondary School':
        return _t('secondarySchool');
      case 'High School':
        return _t('highSchool');
      case "Bachelor's Degree":
        return _t('bachelorsDegree');
      case "Master's Degree":
        return _t('mastersDegree');
      case 'Doctorate':
        return _t('doctorate');
      case 'Male':
        return _t('male');
      case 'Female':
        return _t('female');
      case 'Other':
        return _t('other');
      default:
        return option;
    }
  }

  String _stepTitle() {
    switch (_step) {
      case 1:
        return _t('personalInformation');
      case 2:
        return _t('educationContact');
      case 3:
        return _t('identification');
      case 4:
      default:
        return _t('addressInformation');
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _loadProvinces();
    final results = await Future.wait([
      _service.loadPending(),
      _service.loadReusableDetails(),
    ]);
    final pending = results[0] as PendingApplication?;
    var reusableDetails = results[1] as Map<String, String>;
    if (reusableDetails.isEmpty && pending?.formData.isNotEmpty == true) {
      await _service.saveReusableDetails(pending!.formData);
      reusableDetails = await _service.loadReusableDetails();
    }
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
        _hasSavedDetails = reusableDetails.isNotEmpty;
        _bootstrapping = false;
      });
      _refreshStatus(silent: true);
    } else {
      setState(() {
        _hasSavedDetails = reusableDetails.isNotEmpty;
        _bootstrapping = false;
      });
    }
  }

  Future<void> _useSavedDetails() async {
    final results = await Future.wait([
      _service.loadReusableDetails(),
      _service.loadReusableFamilyBook(),
    ]);
    final savedDetails = results[0] as Map<String, String>;
    final savedFamilyBook = results[1] as ReusableParentFamilyBook?;
    if (!mounted) return;
    if (savedDetails.isEmpty) {
      GlobalAlert.showInfo(
        title: _t('noSavedDetailsYet'),
        message: _t('submitPreviousApplicationFirst'),
        buttonText: _t('ok'),
      );
      return;
    }
    setState(() {
      _data.addAll(savedDetails);
      if (savedFamilyBook != null) {
        _familyBookImages.clear();
        _attachments['family_book'] = _ParentAttachmentDraft(
          bytes: savedFamilyBook.bytes,
          filename: savedFamilyBook.filename,
          displayName: savedFamilyBook.filename,
        );
      }
      _errors.removeWhere((key, _) => savedDetails.containsKey(key));
      if (savedFamilyBook != null) _errors.remove('family_book');
      _formRevision++;
    });
    if (_step == 1) _validate();
    GlobalAlert.showSuccess(
      title: _t('savedDetailsApplied'),
      message: _t('savedParentDetailsAppliedMessage'),
      buttonText: _t('continueAction'),
    );
  }

  Future<void> _loadProvinces() async {
    if (_provincesLoading) return;
    debugPrint(
      '[ParentInfoForm] load provinces start baseUrl=${ApiConfig.baseUrl}',
    );
    setState(() {
      _provincesLoading = true;
      _provincesError = '';
    });
    try {
      final res = await ApiClient().get('/locations/province');
      debugPrint(
        '[ParentInfoForm] /locations/province responseType=${res.runtimeType}',
      );
      final raw = res is List
          ? res
          : (res is Map && res['data'] is List
                ? res['data'] as List
                : const []);
      var list = raw
          .whereType<Map>()
          .map(
            (m) => _ParentProvinceOption.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
      if (list.isEmpty) {
        list = _fallbackLaoProvinces();
      }
      if (!mounted) return;
      setState(() {
        _provinces = list;
        _provincesLoading = false;
        _provincesError = '';
      });
      debugPrint(
        '[ParentInfoForm] provinces loaded count=${list.length} districts=${list.map((p) => '${p.label}:${p.districts.length}').join(', ')}',
      );
    } on ApiException catch (error) {
      debugPrint(
        '[ParentInfoForm] provinces failed status=${error.statusCode} message=${error.message} body=${error.body}',
      );
      if (!mounted) return;
      setState(() {
        _provinces = _fallbackLaoProvinces();
        _provincesLoading = false;
        _provincesError = '';
      });
      debugPrint(
        '[ParentInfoForm] using fallback province data count=${_provinces.length}',
      );
    } catch (error, stackTrace) {
      debugPrint('[ParentInfoForm] provinces failed error=$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _provinces = _fallbackLaoProvinces();
        _provincesLoading = false;
        _provincesError = '';
      });
      debugPrint(
        '[ParentInfoForm] using fallback province data count=${_provinces.length}',
      );
    }
  }

  _ParentProvinceOption? _provinceByIdOrLabel({String? id, String? label}) {
    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      for (final p in _provinces) {
        if (p.id == cleanId) return p;
      }
    }
    final cleanLabel = label?.trim() ?? '';
    if (cleanLabel.isEmpty) return null;
    final lc = cleanLabel.toLowerCase();
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
          title: _t('parentApplicationApprovedAlertTitle'),
          message: _t('parentApplicationApprovedAlertMessage'),
          buttonText: _t('continueAction'),
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
          title: _t('parentApplicationRejectedAlertTitle'),
          message: reason.isEmpty
              ? _t('parentApplicationRejectedDefaultMessage')
              : reason,
          buttonText: _t('ok'),
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
    if (_disableRequiredValidationForTesting) {
      setState(_errors.clear);
      return true;
    }

    final next = <String, String>{};
    for (final f in _required[_step] ?? const <String>[]) {
      final value = (_data[f] ?? '').trim();
      if (value.isEmpty || (f == 'DateofBirth' && _isDatePlaceholder(value))) {
        next[f] = _t('fieldRequiredError');
      }
    }
    if (_step == 1 || _step == 2) {
      final email = _data['Email'] ?? '';
      if (email.isNotEmpty &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        next['Email'] = _t('validEmailError');
      }
    }
    if (_step == 1) {
      final password = _data['Password'] ?? '';
      final confirmPassword = _data['ConfirmPassword'] ?? '';
      if (password.isNotEmpty && password.length < 6) {
        next['Password'] = _t('passwordMinLengthError');
      }
      if (password.isNotEmpty &&
          confirmPassword.isNotEmpty &&
          password != confirmPassword) {
        next['ConfirmPassword'] = _t('passwordsDoNotMatchError');
      }
    }
    if (_step == 3) {
      for (final field in ['id_card', 'family_book', 'passport_image']) {
        if (!_attachments.containsKey(field)) {
          next[field] = _t('uploadDocumentError');
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
    setState(() {
      _submitting = true;
      _submissionMessage = _t('preparingApplication');
    });
    await WidgetsBinding.instance.endOfFrame;
    try {
      if (_familyBookImages.isNotEmpty) {
        setState(() {
          _submissionMessage = _familyBookImages.length == 1
              ? _t('convertingFamilyBookSingle')
              : _t(
                  'convertingFamilyBookMany',
                ).replaceAll('{count}', '${_familyBookImages.length}');
        });
        await WidgetsBinding.instance.endOfFrame;
      }
      final attachments = await _buildSubmitAttachments();
      final familyBook = attachments
          .where((attachment) => attachment.field == 'family_book')
          .cast<ParentAttachment?>()
          .firstWhere((attachment) => attachment != null, orElse: () => null);
      setState(() => _submissionMessage = _t('submittingApplication'));
      await WidgetsBinding.instance.endOfFrame;
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
        throw ApiException(_t('couldNotResolveApplicationId'));
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
      await _service.saveReusableDetails(_data);
      await _service.saveReusableFamilyBook(familyBook);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _referenceId = id;
        _pendingEmail = _data['Email'];
        _pendingPassword = submittedPassword;
        _pendingFullName = fullName.isEmpty ? null : fullName;
        _hasSavedDetails = true;
        _passwordVisible = false;
        _rejected = false;
        _approved = false;
        _rejectReason = null;
        _submitting = false;
      });
      GlobalAlert.showSuccess(
        title: _t('parentApplicationSubmittedAlertTitle'),
        message: _t('parentApplicationSubmittedAlertMessage'),
        buttonText: _t('continueAction'),
      );
      _refreshStatus(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      GlobalAlert.showError(
        title: _t('submissionFailed'),
        message: error is ApiException ? error.message : error.toString(),
        buttonText: _t('ok'),
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
        child: Stack(
          children: [
            Column(
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
            if (_submitting) _buildSubmissionLoadingOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _submitted ? null : _buildBottomNav(),
    );
  }

  Widget _buildSubmissionLoadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99071B55),
        child: Center(
          child: Container(
            width: 280,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33071B55),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: _blue,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('pleaseWait'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _submissionMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            tooltip: _t('back'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('parentInformationTitle'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1.08,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _t('parentInformationSubtitle'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
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

  Widget _buildSavedDetailsAction() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blueSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBED4FF)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.clipboardCheck, size: 20, color: _blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('useSavedDetails'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t('fillSavedParentDetails'),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _useSavedDetails, child: Text(_t('use'))),
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
                              color: _green,
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
                    _stepOfLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stepTitle(),
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
    final fillColor = completed ? _green : _blue;
    final haloColor = completed ? _greenSoft : _blueSoft;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: active ? 44 : 40,
      width: active ? 44 : 40,
      decoration: BoxDecoration(
        color: filled ? fillColor : _slate100,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: fillColor.withValues(alpha: .25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: active ? Border.all(color: haloColor, width: 3) : null,
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
            if (_hasSavedDetails) ...[
              _buildSavedDetailsAction(),
              const SizedBox(height: 16),
            ],
            _sectionCard(1, _t('createLoginAccount'), [
              _input(
                _t('email'),
                'Email',
                required: true,
                placeholder: _parentPlaceholder('enterEmail'),
                keyboard: TextInputType.emailAddress,
              ),
              _input(
                _t('password'),
                'Password',
                required: true,
                placeholder: _t('createPassword'),
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
                  tooltip: _formPasswordVisible ? _t('hide') : _t('show'),
                ),
              ),
              _input(
                _t('confirmPassword'),
                'ConfirmPassword',
                required: true,
                placeholder: _t('confirmPasswordPlaceholder'),
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
                  tooltip: _confirmPasswordVisible ? _t('hide') : _t('show'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _sectionCard(1, _t('personalInformation'), [
              _input(
                _t('firstNameLao'),
                'Firstname_Lao',
                required: true,
                placeholder: _parentPlaceholder('enterLao'),
              ),
              _input(
                _t('firstNameEnglish'),
                'Firstname_Eng',
                required: true,
                placeholder: _parentPlaceholder('enterEnglish'),
              ),
              _input(
                _t('middleNameLao'),
                'Midlename_Lao',
                placeholder: _parentPlaceholder('enterLao'),
              ),
              _input(
                _t('middleNameEnglish'),
                'Midlename_Eng',
                placeholder: _parentPlaceholder('enterEnglish'),
              ),
              _input(
                _t('lastNameLao'),
                'Lastname_Lao',
                required: true,
                placeholder: _parentPlaceholder('enterLao'),
              ),
              _input(
                _t('lastNameEnglish'),
                'Lastname_Eng',
                required: true,
                placeholder: _parentPlaceholder('enterEnglish'),
              ),
              _input(
                _nicknameLabel(),
                'Nickname',
                required: true,
                placeholder: _parentPlaceholder('enterNickname'),
              ),
              _dateInput(_t('dateOfBirth'), 'DateofBirth', required: true),
              _select(
                _t('gender'),
                'Gender',
                _genders,
                required: true,
                placeholder: _t('selectGender'),
              ),
            ]),
          ],
        );
      case 2:
        return _sectionCard(2, _t('educationContact'), [
          _select(
            _t('educationLevel'),
            'Educatio_Level',
            _education,
            required: true,
            placeholder: _t('selectEducationLevel'),
          ),
          _input(
            _t('job'),
            'Job',
            required: true,
            placeholder: _parentPlaceholder('enterJob'),
          ),
          _input(
            _t('workplace'),
            'Workplace',
            required: true,
            placeholder: _parentPlaceholder('enterWorkplace'),
          ),
          _input(
            _t('email'),
            'Email',
            required: true,
            placeholder: _parentPlaceholder('enterEmail'),
            keyboard: TextInputType.emailAddress,
          ),
          _input(
            _t('phoneNo1'),
            'Phone_No1',
            required: true,
            placeholder: _phonePlaceholder(),
            keyboard: TextInputType.phone,
          ),
          _input(
            _t('phoneNo2'),
            'Phone_No2',
            required: true,
            placeholder: _phonePlaceholder(),
            keyboard: TextInputType.phone,
          ),
        ]);
      case 3:
        return _sectionCard(3, _t('identification'), [
          _input(
            _t('passportNo'),
            'Passport_no',
            required: true,
            placeholder: _parentPlaceholder('enterPassportNumber'),
          ),
          _input(
            _t('idCardNo'),
            'IDCard_no',
            required: true,
            placeholder: _parentPlaceholder('enterIdCardNumber'),
          ),
          _input(
            _t('familyBookNo'),
            'FamillyBook_no',
            required: true,
            placeholder: _parentPlaceholder('enterFamilyBookNumber'),
          ),
          _fileUpload(
            _t('passportImage'),
            'passport_image',
            required: true,
            pdfOnly: false,
          ),
          _fileUpload(
            _identityCardUploadLabel(),
            'id_card',
            required: true,
            pdfOnly: false,
          ),
          _fileUpload(
            _familyBookUploadLabel(),
            'family_book',
            required: true,
            pdfOnly: true,
          ),
          _input(
            _t('nationality'),
            'Nationality',
            required: true,
            placeholder: _parentPlaceholder('enterNationality'),
          ),
          _input(
            _t('ethnicity'),
            'Ethnicty',
            required: true,
            placeholder: _parentPlaceholder('enterEthnicity'),
          ),
          _input(
            _t('religion'),
            'Religion',
            required: true,
            placeholder: _parentPlaceholder('enterReligion'),
          ),
        ]);
      case 4:
      default:
        return Column(
          children: [
            _sectionCard(4, _t('addressInformation'), [
              _input(
                _t('homeNo'),
                'Home_no',
                required: true,
                placeholder: _parentPlaceholder('enterHomeNumber'),
              ),
              _input(
                _parentAddressLabel('ເລກຫນ່ວຍ', 'Unit number'),
                'Home_unit',
                required: true,
                placeholder: _parentAddressHint(
                  'ພິມເລກຫນ່ວຍ',
                  'Enter unit number',
                ),
              ),
              _locationProvinceSelect(),
              _locationDistrictSelect(),
              _input(
                _parentAddressLabel('ຕາແສງ', 'Sub-district'),
                'SubDistrict',
                placeholder: _parentAddressHint(
                  'ພິມຕາແສງ',
                  'Enter sub-district',
                ),
              ),
              _locationVillageField(),
              _fileUpload(
                _t('homePictureOptional'),
                'home_picture',
                pdfOnly: false,
              ),
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
                            : _t('couldNotReadFile');
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
                  ? (isFamilyBook
                        ? _t('choosePdfOrImages')
                        : (pdfOnly ? _t('choosePdf') : _t('chooseImage')))
                  : (isFamilyBook && _familyBookImages.isNotEmpty
                        ? '${selected.displayName} (${_t('tapToAddMore')})'
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
          if (isFamilyBook && selected != null) ...[
            const SizedBox(height: 10),
            _buildFamilyBookFileList(selected),
          ],
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

  Widget _buildFamilyBookFileList(_ParentAttachmentDraft selected) {
    final imageDrafts = _familyBookImages;
    final isImageList = imageDrafts.isNotEmpty;
    final count = isImageList ? imageDrafts.length : 1;

    return Container(
      decoration: BoxDecoration(
        color: _blueSofter,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) const Divider(height: 1, color: _slate200),
            Builder(
              builder: (_) {
                final image = isImageList ? imageDrafts[index] : null;
                final filename = image?.name ?? selected.displayName;
                final isPdf = image == null;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  leading: Icon(
                    isPdf ? LucideIcons.fileText : LucideIcons.image,
                    size: 18,
                    color: _blue,
                  ),
                  title: Text(
                    filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        tooltip: _t('preview'),
                        icon: const Icon(LucideIcons.eye, size: 18),
                        onPressed: () => isPdf
                            ? _previewFamilyBookPdf(selected)
                            : _previewFamilyBookImage(image),
                      ),
                      IconButton(
                        tooltip: _t('remove'),
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: 17,
                          color: _rose500,
                        ),
                        onPressed: () => isPdf
                            ? _removeFamilyBookPdf()
                            : _removeFamilyBookImage(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _removeFamilyBookPdf() {
    setState(() {
      _attachments.remove('family_book');
      _familyBookImages.clear();
    });
  }

  void _removeFamilyBookImage(int index) {
    setState(() {
      _familyBookImages.removeAt(index);
      if (_familyBookImages.isEmpty) {
        _attachments.remove('family_book');
        return;
      }
      final imageCount = _familyBookImages.length;
      final baseName = imageCount == 1
          ? _basenameWithoutExtension(_familyBookImages.first.name)
          : 'family_book_${imageCount}_images';
      _attachments['family_book'] = _ParentAttachmentDraft(
        bytes: Uint8List(0),
        filename: '$baseName.pdf',
        displayName: imageCount == 1
            ? _t(
                'convertedToPdf',
              ).replaceAll('{name}', _familyBookImages.first.name)
            : _t('imagesConvertedToPdf').replaceAll('{count}', '$imageCount'),
        deferUntilSubmit: true,
      );
    });
  }

  Future<void> _previewFamilyBookImage(_FamilyBookImageDraft image) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        image.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(image.bytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _previewFamilyBookPdf(_ParentAttachmentDraft attachment) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 900,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        attachment.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: SfPdfViewer.memory(attachment.bytes)),
            ],
          ),
        ),
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
          label: pdfOnly ? _t('pdf') : _t('image'),
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
      acceptedTypeGroups: [
        XTypeGroup(
          label: _t('choosePdfOrImages'),
          extensions: const ['pdf', 'jpg', 'jpeg', 'png'],
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
      throw Exception(_t('chooseEitherPdfOrImagesNotBoth'));
    }
    if (pdfFiles.length > 1) {
      throw Exception(_t('chooseOnlyOnePdfFile'));
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
      throw Exception(_t('choosePdfJpgJpegPngFiles'));
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
          ? _t(
              'convertedToPdf',
            ).replaceAll('{name}', _familyBookImages.first.name)
          : _t('imagesConvertedToPdf').replaceAll('{count}', '$imageCount'),
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
          key: ValueKey('input_$name:$_formRevision'),
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
    final selected = _provinceByIdOrLabel(
      id: _data['ProvinceId'],
      label: current,
    );
    final loadError = _provincesError.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_parentAddressLabel('ຊື່ແຂວງ', 'Province name'), true),
        DropdownButtonFormField<String>(
          key: ValueKey('province_$_formRevision'),
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
            _provincesLoading
                ? _t('loadingProvinces')
                : loadError.isNotEmpty
                ? _t('couldNotLoadProvinces')
                : _parentAddressHint('ເລືອກຊື່ແຂວງ', 'Select province name'),
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
                  debugPrint(
                    '[ParentInfoForm] province selected id=${picked.id} label=${picked.label} districts=${picked.districts.length}',
                  );
                  setState(() {
                    _data['ProvinceId'] = picked.id;
                    _data[name] = picked.label;
                    _data['DistrictId'] = '';
                    _data['District'] = '';
                    _data['SubDistrict'] = '';
                    _data['Village'] = '';
                    _errors.remove(name);
                    _errors.remove('District');
                    _errors.remove('Village');
                    _formRevision++;
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
        if (loadError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  size: 15,
                  color: _rose500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_t('couldNotLoadProvinces')}: $loadError',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _rose500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _provincesLoading ? null : _loadProvinces,
                  child: Text(_t('retry')),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _locationDistrictSelect() {
    const name = 'District';
    final err = _errors[name];
    final current = _data[name] ?? '';
    final province = _provinceByIdOrLabel(
      id: _data['ProvinceId'],
      label: _data['Province'],
    );
    final districts = province?.districts ?? const [];
    final selected = _districtByIdOrLabel(
      districts,
      id: _data['DistrictId'],
      label: current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_parentAddressLabel('ຊື່ເມືອງ', 'District name'), true),
        DropdownButtonFormField<String>(
          key: ValueKey('district_${province?.id ?? ''}_$_formRevision'),
          initialValue: selected?.id,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, color: _muted),
          hint: Text(
            province == null
                ? _parentAddressHint(
                    'ເລືອກຊື່ແຂວງກ່ອນ',
                    'Select province name first',
                  )
                : _parentAddressHint('ເລືອກຊື່ເມືອງ', 'Select district name'),
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
                  debugPrint(
                    '[ParentInfoForm] district selected id=${picked.id} label=${picked.label} villages=${picked.villages.length}',
                  );
                  setState(() {
                    _data['DistrictId'] = picked.id;
                    _data[name] = picked.label;
                    _data['SubDistrict'] = '';
                    _data['Village'] = '';
                    _errors.remove(name);
                    _errors.remove('Village');
                    _formRevision++;
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

  _ParentDistrictOption? _districtByIdOrLabel(
    List<_ParentDistrictOption> districts, {
    String? id,
    String? label,
  }) {
    final cleanId = id?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      for (final d in districts) {
        if (d.id == cleanId) return d;
      }
    }
    final cleanLabel = label?.trim() ?? '';
    if (cleanLabel.isEmpty) return null;
    final lc = cleanLabel.toLowerCase();
    for (final d in districts) {
      if (d.label.toLowerCase() == lc) return d;
    }
    return null;
  }

  Widget _locationVillageField() {
    const name = 'Village';
    final province = _provinceByIdOrLabel(
      id: _data['ProvinceId'],
      label: _data['Province'],
    );
    final district = _districtByIdOrLabel(
      province?.districts ?? const [],
      id: _data['DistrictId'],
      label: _data['District'],
    );
    final villages = district?.villages ?? const <String>[];

    if (villages.isEmpty) {
      return _input(
        _parentAddressLabel('ຊື່ບ້ານ', 'Village name'),
        name,
        required: true,
        placeholder: district == null
            ? _parentAddressHint(
                'ເລືອກຊື່ເມືອງກ່ອນ',
                'Select district name first',
              )
            : _parentAddressHint('ພິມຊື່ບ້ານ', 'Enter village name'),
      );
    }

    final err = _errors[name];
    final current = _data[name] ?? '';
    final selected =
        villages.any((v) => v.toLowerCase() == current.toLowerCase())
        ? villages.firstWhere((v) => v.toLowerCase() == current.toLowerCase())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_parentAddressLabel('ຊື່ບ້ານ', 'Village name'), true),
        DropdownButtonFormField<String>(
          key: ValueKey('village_${district?.id ?? ''}_$_formRevision'),
          initialValue: selected,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, color: _muted),
          hint: Text(
            _parentAddressHint('ເລືອກຊື່ບ້ານ', 'Select village name'),
            style: const TextStyle(color: _slate400, fontSize: 14),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(null, err),
          items: villages
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _data[name] = v;
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
          key: ValueKey('select_$name:$_formRevision'),
          initialValue: (value != null && options.contains(value))
              ? value
              : null,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, color: _muted),
          hint: Text(
            placeholder ?? _t('selectPlaceholder'),
            style: const TextStyle(color: _slate400, fontSize: 14),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(null, err),
          items: options
              .map(
                (o) => DropdownMenuItem(value: o, child: Text(_optionLabel(o))),
              )
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
        TextFormField(
          key: ValueKey('date_text_$name'),
          initialValue: _displayDate(value),
          onChanged: (v) => _set(name, _storeDateInput(v)),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _dateInputFormatter,
          ],
          style: const TextStyle(
            fontSize: 16,
            color: _navy,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(_datePlaceholder(), err),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('note'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('parentFormPrivacyNote'),
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
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _onBack,
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    label: Text(_t('back')),
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
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_t('next')),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.chevronRight, size: 18),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_t('submitParentInformation')),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.chevronRight, size: 18),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.circle, color: amber, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      _t('pendingApprovalUpper'),
                      style: const TextStyle(
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
              Text(
                _t('parentApplicationSubmittedTitle'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: _t('parentApplicationThanks'),
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
                    TextSpan(
                      text: '. ${_t('parentApplicationWaitingMessage')}',
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
              _checkingStatus
                  ? _t('checkingStatus')
                  : _t('checkApprovalStatus'),
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
            child: Text(_t('backToSignIn')),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            final ok = await GlobalAlert.showConfirmation(
              title: _t('cancelApplicationQuestion'),
              message: _t('cancelApplicationMessage'),
              confirmText: _t('ok'),
              cancelText: _t('cancel'),
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
          child: Text(
            _t('cancelApplication'),
            style: const TextStyle(fontWeight: FontWeight.w600),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.circle, color: green, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      _t('accountApprovedUpper'),
                      style: const TextStyle(
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
              Text(
                _t('youreApproved'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: _t('welcome'),
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
                    TextSpan(text: '. ${_t('accountApprovedMessage')}'),
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
            label: Text(_t('goToSignIn')),
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
        : _t('reviewParentInformationAndSubmitAgain');
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.circleX, color: rose, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      _t('rejectedUpper'),
                      style: const TextStyle(
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
              Text(
                _t('applicationRejected'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(text: _t('applicationRejectedMessage')),
                style: const TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 1.5,
                ),
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
            label: Text(
              _checkingStatus ? _t('checkingStatus') : _t('checkAgain'),
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
          child: OutlinedButton.icon(
            onPressed: _resubmitApplication,
            icon: const Icon(LucideIcons.filePenLine, size: 18),
            label: Text(_t('editAndResubmit')),
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
            child: Text(_t('backToSignIn')),
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
                Text(
                  _t('reasonFromAdmin'),
                  style: const TextStyle(
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
          Text(
            _t('yourLogin'),
            style: const TextStyle(
              fontSize: 11,
              color: _blue,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          if (_pendingEmail != null) ...[
            _credRow(
              label: _t('email'),
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
            label: _t('password'),
            value: pwd.isEmpty
                ? _t('notAvailable')
                : (_passwordVisible ? pwd : masked),
            icon: LucideIcons.lock,
            monospace: pwd.isNotEmpty,
            muted: pwd.isEmpty,
            trailing: IconButton(
              onPressed: () {
                if (pwd.isEmpty) {
                  GlobalAlert.showInfo(
                    title: _t('passwordUnavailable'),
                    message: _t('passwordUnavailableMessage'),
                    buttonText: _t('ok'),
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
              tooltip: _passwordVisible ? _t('hide') : _t('show'),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 14, color: _blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _t('savePasswordHint'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                      height: 1.4,
                    ),
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
        _t('submitted'),
        _t('applicationReceived'),
        LucideIcons.circleCheck,
        _blue,
        true,
      ),
      (
        _rejected ? _t('rejected') : _t('pendingReview'),
        _rejected ? _t('adminRequestedChanges') : _t('waitingForAdminApproval'),
        _rejected ? LucideIcons.circleX : LucideIcons.hourglass,
        _rejected ? rose : amber,
        true,
      ),
      (
        _rejected ? _t('resubmit') : _t('approved'),
        _rejected
            ? _t('updateDetailsAndSendAgain')
            : _t('notifiedOnceApproved'),
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
  final List<String> villages;

  const _ParentDistrictOption({
    required this.id,
    required this.label,
    this.villages = const [],
  });

  factory _ParentDistrictOption.fromJson(Map<String, dynamic> j) {
    final rawVillages =
        j['villages'] ?? j['village'] ?? j['bans'] ?? j['ban'] ?? const [];
    final villages = rawVillages is List
        ? rawVillages
              .map((item) {
                if (item is Map) {
                  return (item['nameEn'] ??
                          item['nameLa'] ??
                          item['name'] ??
                          item['label'] ??
                          '')
                      .toString()
                      .trim();
                }
                return item.toString().trim();
              })
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
        : const <String>[];

    return _ParentDistrictOption(
      id: (j['id'] ?? '').toString(),
      label: (j['nameEn'] ?? j['nameLa'] ?? j['name'] ?? '').toString(),
      villages: villages,
    );
  }
}

List<_ParentProvinceOption> _fallbackLaoProvinces() => const [
  _ParentProvinceOption(
    id: 'fallback-vientiane-capital',
    label: 'ນະຄອນຫຼວງວຽງຈັນ',
    districts: [
      _ParentDistrictOption(id: 'fallback-vtc-chanthabuly', label: 'ຈັນທະບູລີ'),
      _ParentDistrictOption(
        id: 'fallback-vtc-sikhottabong',
        label: 'ສີໂຄດຕະບອງ',
      ),
      _ParentDistrictOption(id: 'fallback-vtc-xaysetha', label: 'ໄຊເສດຖາ'),
      _ParentDistrictOption(id: 'fallback-vtc-sisattanak', label: 'ສີສັດຕະນາກ'),
      _ParentDistrictOption(id: 'fallback-vtc-naxaythong', label: 'ນາຊາຍທອງ'),
      _ParentDistrictOption(id: 'fallback-vtc-xaythany', label: 'ໄຊທານີ'),
      _ParentDistrictOption(id: 'fallback-vtc-hatsaifong', label: 'ຫາດຊາຍຟອງ'),
      _ParentDistrictOption(id: 'fallback-vtc-sangthong', label: 'ສັງທອງ'),
      _ParentDistrictOption(id: 'fallback-vtc-pakngum', label: 'ປາກງື່ມ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-phongsaly',
    label: 'ຜົ້ງສາລີ',
    districts: [
      _ParentDistrictOption(id: 'fallback-psl-phongsaly', label: 'ຜົ້ງສາລີ'),
      _ParentDistrictOption(id: 'fallback-psl-may', label: 'ໃໝ່'),
      _ParentDistrictOption(id: 'fallback-psl-khoua', label: 'ຂວາ'),
      _ParentDistrictOption(id: 'fallback-psl-samphan', label: 'ສຳພັນ'),
      _ParentDistrictOption(id: 'fallback-psl-bounneua', label: 'ບຸນເໜືອ'),
      _ParentDistrictOption(id: 'fallback-psl-nyot-ou', label: 'ຍອດອູ'),
      _ParentDistrictOption(id: 'fallback-psl-bountai', label: 'ບຸນໃຕ້'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-luangnamtha',
    label: 'ຫຼວງນ້ຳທາ',
    districts: [
      _ParentDistrictOption(id: 'fallback-lnt-luangnamtha', label: 'ຫຼວງນ້ຳທາ'),
      _ParentDistrictOption(id: 'fallback-lnt-sing', label: 'ສິງ'),
      _ParentDistrictOption(id: 'fallback-lnt-long', label: 'ລອງ'),
      _ParentDistrictOption(id: 'fallback-lnt-viengphoukha', label: 'ວຽງພູຄາ'),
      _ParentDistrictOption(id: 'fallback-lnt-nalae', label: 'ນາແລ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-oudomxay',
    label: 'ອຸດົມໄຊ',
    districts: [
      _ParentDistrictOption(id: 'fallback-odx-xay', label: 'ໄຊ'),
      _ParentDistrictOption(id: 'fallback-odx-la', label: 'ຫຼາ'),
      _ParentDistrictOption(id: 'fallback-odx-namo', label: 'ນາໝໍ້'),
      _ParentDistrictOption(id: 'fallback-odx-nga', label: 'ງາ'),
      _ParentDistrictOption(id: 'fallback-odx-beng', label: 'ແບງ'),
      _ParentDistrictOption(id: 'fallback-odx-houn', label: 'ຮຸນ'),
      _ParentDistrictOption(id: 'fallback-odx-pakbeng', label: 'ປາກແບງ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-bokeo',
    label: 'ບໍ່ແກ້ວ',
    districts: [
      _ParentDistrictOption(id: 'fallback-bko-houayxay', label: 'ຫ້ວຍຊາຍ'),
      _ParentDistrictOption(id: 'fallback-bko-tonpheung', label: 'ຕົ້ນເຜິ້ງ'),
      _ParentDistrictOption(id: 'fallback-bko-meung', label: 'ເມິງ'),
      _ParentDistrictOption(id: 'fallback-bko-phaoudom', label: 'ຜາອຸດົມ'),
      _ParentDistrictOption(id: 'fallback-bko-paktha', label: 'ປາກທາ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-luangprabang',
    label: 'ຫຼວງພະບາງ',
    districts: [
      _ParentDistrictOption(
        id: 'fallback-lpb-luangprabang',
        label: 'ຫຼວງພະບາງ',
      ),
      _ParentDistrictOption(id: 'fallback-lpb-xiengngeun', label: 'ຊຽງເງິນ'),
      _ParentDistrictOption(id: 'fallback-lpb-nan', label: 'ນານ'),
      _ParentDistrictOption(id: 'fallback-lpb-pak-ou', label: 'ປາກອູ'),
      _ParentDistrictOption(id: 'fallback-lpb-nambak', label: 'ນ້ຳບາກ'),
      _ParentDistrictOption(id: 'fallback-lpb-ngoy', label: 'ງອຍ'),
      _ParentDistrictOption(id: 'fallback-lpb-pakxeng', label: 'ປາກແຊງ'),
      _ParentDistrictOption(id: 'fallback-lpb-phonxay', label: 'ໂພນໄຊ'),
      _ParentDistrictOption(id: 'fallback-lpb-chomphet', label: 'ຈອມເພັດ'),
      _ParentDistrictOption(id: 'fallback-lpb-viengkham', label: 'ວຽງຄຳ'),
      _ParentDistrictOption(id: 'fallback-lpb-phoukhoun', label: 'ພູຄູນ'),
      _ParentDistrictOption(id: 'fallback-lpb-phonthong', label: 'ໂພນທອງ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-houaphanh',
    label: 'ຫົວພັນ',
    districts: [
      _ParentDistrictOption(id: 'fallback-hph-xamneua', label: 'ຊຳເໜືອ'),
      _ParentDistrictOption(id: 'fallback-hph-xiengkhor', label: 'ຊຽງຄໍ້'),
      _ParentDistrictOption(id: 'fallback-hph-hiem', label: 'ຮ້ຽມ'),
      _ParentDistrictOption(id: 'fallback-hph-viengxay', label: 'ວຽງໄຊ'),
      _ParentDistrictOption(id: 'fallback-hph-houameuang', label: 'ຫົວເມືອງ'),
      _ParentDistrictOption(id: 'fallback-hph-xamtai', label: 'ຊຳໃຕ້'),
      _ParentDistrictOption(id: 'fallback-hph-sopbao', label: 'ສົບເບົາ'),
      _ParentDistrictOption(id: 'fallback-hph-add', label: 'ແອດ'),
      _ParentDistrictOption(id: 'fallback-hph-kuan', label: 'ກວັນ'),
      _ParentDistrictOption(id: 'fallback-hph-xon', label: 'ຊ່ອນ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-xayaboury',
    label: 'ໄຊຍະບູລີ',
    districts: [
      _ParentDistrictOption(id: 'fallback-xbl-xayaboury', label: 'ໄຊຍະບູລີ'),
      _ParentDistrictOption(id: 'fallback-xbl-khop', label: 'ຄອບ'),
      _ParentDistrictOption(id: 'fallback-xbl-hongsa', label: 'ຫົງສາ'),
      _ParentDistrictOption(id: 'fallback-xbl-ngeun', label: 'ເງິນ'),
      _ParentDistrictOption(id: 'fallback-xbl-xienghone', label: 'ຊຽງຮ່ອນ'),
      _ParentDistrictOption(id: 'fallback-xbl-phieng', label: 'ພຽງ'),
      _ParentDistrictOption(id: 'fallback-xbl-paklai', label: 'ປາກລາຍ'),
      _ParentDistrictOption(id: 'fallback-xbl-kaenthao', label: 'ແກ່ນທ້າວ'),
      _ParentDistrictOption(id: 'fallback-xbl-boten', label: 'ບໍ່ແຕນ'),
      _ParentDistrictOption(id: 'fallback-xbl-thongmixay', label: 'ທົ່ງມີໄຊ'),
      _ParentDistrictOption(id: 'fallback-xbl-xaysathan', label: 'ໄຊສະຖານ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-xiengkhouang',
    label: 'ຊຽງຂວາງ',
    districts: [
      _ParentDistrictOption(id: 'fallback-xkh-pek', label: 'ແປກ'),
      _ParentDistrictOption(id: 'fallback-xkh-kham', label: 'ຄຳ'),
      _ParentDistrictOption(id: 'fallback-xkh-nonghed', label: 'ໜອງແຮດ'),
      _ParentDistrictOption(id: 'fallback-xkh-khoun', label: 'ຄູນ'),
      _ParentDistrictOption(id: 'fallback-xkh-mokmai', label: 'ໝອກໃໝ່'),
      _ParentDistrictOption(id: 'fallback-xkh-phoukoud', label: 'ພູກູດ'),
      _ParentDistrictOption(id: 'fallback-xkh-phaxay', label: 'ຜາໄຊ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-vientiane-province',
    label: 'ວຽງຈັນ',
    districts: [
      _ParentDistrictOption(id: 'fallback-vtp-phonhong', label: 'ໂພນໂຮງ'),
      _ParentDistrictOption(id: 'fallback-vtp-thoulakhom', label: 'ທຸລະຄົມ'),
      _ParentDistrictOption(id: 'fallback-vtp-keooudom', label: 'ແກ້ວອຸດົມ'),
      _ParentDistrictOption(id: 'fallback-vtp-kasy', label: 'ກາສີ'),
      _ParentDistrictOption(id: 'fallback-vtp-vangvieng', label: 'ວັງວຽງ'),
      _ParentDistrictOption(id: 'fallback-vtp-feuang', label: 'ເຟືອງ'),
      _ParentDistrictOption(id: 'fallback-vtp-xanakham', label: 'ຊະນະຄາມ'),
      _ParentDistrictOption(id: 'fallback-vtp-mad', label: 'ແມດ'),
      _ParentDistrictOption(id: 'fallback-vtp-viengkham', label: 'ວຽງຄຳ'),
      _ParentDistrictOption(id: 'fallback-vtp-hinhurp', label: 'ຫີນເຫີບ'),
      _ParentDistrictOption(id: 'fallback-vtp-meun', label: 'ໝື່ນ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-bolikhamxay',
    label: 'ບໍລິຄຳໄຊ',
    districts: [
      _ParentDistrictOption(id: 'fallback-blk-paksan', label: 'ປາກຊັນ'),
      _ParentDistrictOption(id: 'fallback-blk-thaphabat', label: 'ທ່າພະບາດ'),
      _ParentDistrictOption(id: 'fallback-blk-pakkading', label: 'ປາກກະດິງ'),
      _ParentDistrictOption(id: 'fallback-blk-bolikhan', label: 'ບໍລິຄັນ'),
      _ParentDistrictOption(id: 'fallback-blk-khamkeut', label: 'ຄຳເກີດ'),
      _ParentDistrictOption(id: 'fallback-blk-viengthong', label: 'ວຽງທອງ'),
      _ParentDistrictOption(id: 'fallback-blk-xaychamphon', label: 'ໄຊຈຳພອນ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-khammouane',
    label: 'ຄຳມ່ວນ',
    districts: [
      _ParentDistrictOption(id: 'fallback-khm-thakhek', label: 'ທ່າແຂກ'),
      _ParentDistrictOption(id: 'fallback-khm-mahaxay', label: 'ມະຫາໄຊ'),
      _ParentDistrictOption(id: 'fallback-khm-nongbok', label: 'ໜອງບົກ'),
      _ParentDistrictOption(id: 'fallback-khm-hinboun', label: 'ຫີນບູນ'),
      _ParentDistrictOption(id: 'fallback-khm-nyommalath', label: 'ຍົມມະລາດ'),
      _ParentDistrictOption(id: 'fallback-khm-boualapha', label: 'ບົວລະພາ'),
      _ParentDistrictOption(id: 'fallback-khm-nakay', label: 'ນາກາຍ'),
      _ParentDistrictOption(id: 'fallback-khm-xebangfai', label: 'ເຊບັ້ງໄຟ'),
      _ParentDistrictOption(id: 'fallback-khm-xaybuathong', label: 'ໄຊບົວທອງ'),
      _ParentDistrictOption(id: 'fallback-khm-khounkham', label: 'ຄູນຄຳ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-savannakhet',
    label: 'ສະຫວັນນະເຂດ',
    districts: [
      _ParentDistrictOption(id: 'fallback-svk-kaysone', label: 'ໄກສອນພົມວິຫານ'),
      _ParentDistrictOption(id: 'fallback-svk-outhoumphone', label: 'ອຸທຸມພອນ'),
      _ParentDistrictOption(
        id: 'fallback-svk-atsaphangthong',
        label: 'ອາດສະພັງທອງ',
      ),
      _ParentDistrictOption(id: 'fallback-svk-phin', label: 'ພີນ'),
      _ParentDistrictOption(id: 'fallback-svk-sepon', label: 'ເຊໂປນ'),
      _ParentDistrictOption(id: 'fallback-svk-nong', label: 'ນອງ'),
      _ParentDistrictOption(
        id: 'fallback-svk-thapangthong',
        label: 'ທ່າປາງທອງ',
      ),
      _ParentDistrictOption(id: 'fallback-svk-songkhone', label: 'ສອງຄອນ'),
      _ParentDistrictOption(id: 'fallback-svk-champhone', label: 'ຈຳພອນ'),
      _ParentDistrictOption(id: 'fallback-svk-xonbuly', label: 'ຊົນບູລີ'),
      _ParentDistrictOption(id: 'fallback-svk-xaybouly', label: 'ໄຊບູລີ'),
      _ParentDistrictOption(id: 'fallback-svk-vilabouly', label: 'ວິລະບູລີ'),
      _ParentDistrictOption(id: 'fallback-svk-atsaphone', label: 'ອາດສະພອນ'),
      _ParentDistrictOption(id: 'fallback-svk-xayphouthong', label: 'ໄຊພູທອງ'),
      _ParentDistrictOption(id: 'fallback-svk-phalanxay', label: 'ພະລານໄຊ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-salavan',
    label: 'ສາລະວັນ',
    districts: [
      _ParentDistrictOption(id: 'fallback-slv-salavan', label: 'ສາລະວັນ'),
      _ParentDistrictOption(id: 'fallback-slv-ta-oy', label: 'ຕາໂອ້ຍ'),
      _ParentDistrictOption(id: 'fallback-slv-toumlan', label: 'ຕຸ້ມລານ'),
      _ParentDistrictOption(id: 'fallback-slv-lakhonpheng', label: 'ລະຄອນເພັງ'),
      _ParentDistrictOption(id: 'fallback-slv-vapy', label: 'ວາປີ'),
      _ParentDistrictOption(id: 'fallback-slv-khongxedone', label: 'ຄົງເຊໂດນ'),
      _ParentDistrictOption(id: 'fallback-slv-laongam', label: 'ເລົ່າງາມ'),
      _ParentDistrictOption(id: 'fallback-slv-samouay', label: 'ສະມ້ວຍ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-sekong',
    label: 'ເຊກອງ',
    districts: [
      _ParentDistrictOption(id: 'fallback-skg-lamam', label: 'ລະມາມ'),
      _ParentDistrictOption(id: 'fallback-skg-kaleum', label: 'ກະລຶມ'),
      _ParentDistrictOption(id: 'fallback-skg-dakcheung', label: 'ດາກຈຶງ'),
      _ParentDistrictOption(id: 'fallback-skg-thateng', label: 'ທ່າແຕງ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-champasak',
    label: 'ຈຳປາສັກ',
    districts: [
      _ParentDistrictOption(id: 'fallback-cps-pakse', label: 'ປາກເຊ'),
      _ParentDistrictOption(
        id: 'fallback-cps-xanasomboun',
        label: 'ຊະນະສົມບູນ',
      ),
      _ParentDistrictOption(
        id: 'fallback-cps-bachieng',
        label: 'ບາຈຽງຈະເລີນສຸກ',
      ),
      _ParentDistrictOption(id: 'fallback-cps-pakxong', label: 'ປາກຊ່ອງ'),
      _ParentDistrictOption(id: 'fallback-cps-pathoumphone', label: 'ປະທຸມພອນ'),
      _ParentDistrictOption(id: 'fallback-cps-phonthong', label: 'ໂພນທອງ'),
      _ParentDistrictOption(id: 'fallback-cps-champasak', label: 'ຈຳປາສັກ'),
      _ParentDistrictOption(id: 'fallback-cps-sukhuma', label: 'ສຸຂຸມາ'),
      _ParentDistrictOption(
        id: 'fallback-cps-mounlapamok',
        label: 'ມຸນລະປະໂມກ',
      ),
      _ParentDistrictOption(id: 'fallback-cps-khong', label: 'ໂຂງ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-attapeu',
    label: 'ອັດຕະປື',
    districts: [
      _ParentDistrictOption(id: 'fallback-atp-xaysetha', label: 'ໄຊເສດຖາ'),
      _ParentDistrictOption(id: 'fallback-atp-samakkhixay', label: 'ສາມັກຄີໄຊ'),
      _ParentDistrictOption(id: 'fallback-atp-sanamxay', label: 'ສະໜາມໄຊ'),
      _ParentDistrictOption(id: 'fallback-atp-sanxay', label: 'ສານໄຊ'),
      _ParentDistrictOption(id: 'fallback-atp-phouvong', label: 'ພູວົງ'),
    ],
  ),
  _ParentProvinceOption(
    id: 'fallback-xaysomboun',
    label: 'ໄຊສົມບູນ',
    districts: [
      _ParentDistrictOption(id: 'fallback-xsb-anuvong', label: 'ອະນຸວົງ'),
      _ParentDistrictOption(id: 'fallback-xsb-longchaeng', label: 'ລ້ອງແຈ້ງ'),
      _ParentDistrictOption(id: 'fallback-xsb-longxan', label: 'ລ້ອງຊານ'),
      _ParentDistrictOption(id: 'fallback-xsb-hom', label: 'ຮົ່ມ'),
      _ParentDistrictOption(id: 'fallback-xsb-thathom', label: 'ທ່າໂທມ'),
    ],
  ),
];

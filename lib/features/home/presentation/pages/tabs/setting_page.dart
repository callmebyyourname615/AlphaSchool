import 'package:alpha_school/features/home/presentation/pages/profile/profile.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/services/global_alert_service.dart';
// ✅ same AppTheme.mode as Year Picker
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/models/student_card_item.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.title = 'Settings',
    this.selectedStudent,
  });

  final String title;
  final StudentCardItem? selectedStudent;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ✅ Light palette (MUST remain exactly as your original)
  static const _bg = Colors.white;
  static const _titleColor = Color(0xFF111827);
  static const _textColor = Color(0xFF6B7280);
  static const _iconColor = Color(0xFF111827);
  static const _chevColor = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFF1F5F9);

  /// 'lo' or 'en'
  String _lang = 'lo';
  final ApiClient _api = ApiClient();
  bool _loadingEmergency = false;
  String _emergencyError = '';
  List<_EmergencyContactInfo> _emergencyContacts = const [];

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStudent?.id != widget.selectedStudent?.id) {
      _loadEmergencyContacts();
    }
  }

  void _back() => Navigator.of(context).maybePop();

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(student: widget.selectedStudent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final isDarkMode = mode == ThemeMode.dark;
        final p = _SettingsPalette.from(isDarkMode);

        final tiles = <Widget>[
          _SettingsTile(
            icon: LucideIcons.user,
            label: 'Account',
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 26,
              color: p.chevColor,
            ),
            onTap: _openProfile,
            iconColor: p.iconColor.withOpacity(.75),
            textColor: p.textColor,
          ),
          const SizedBox(height: 14),

          _SettingsTile(
            icon: LucideIcons.heartPulse,
            label: 'Emergency contact',
            valueText: _emergencyValueText,
            trailing: _loadingEmergency
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.chevColor,
                    ),
                  )
                : Icon(LucideIcons.chevronRight, size: 26, color: p.chevColor),
            onTap: _openEmergencyPage,
            iconColor: p.iconColor.withOpacity(.75),
            textColor: p.textColor,
          ),
          const SizedBox(height: 14),

          _SettingsTile(
            icon: LucideIcons.globe,
            label: 'Language',
            valueText: _lang == 'lo' ? 'Laos' : 'English',
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 26,
              color: p.chevColor,
            ),
            onTap: _openLanguageSheet,
            iconColor: p.iconColor.withOpacity(.75),
            textColor: p.textColor,
          ),

          const SizedBox(height: 18),

          _LogoutButton(
            onTap: () {
              // TODO: your logout logic
            },
            bgColor: p.logoutBg,
            borderColor: p.logoutBorder,
          ),
        ];

        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                      child: _TopBar(
                        title: widget.title,
                        onBack: _back,
                        titleColor: p.titleColor,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 260.ms)
                    .slideY(begin: -0.10, end: 0, duration: 320.ms),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    children: [
                      _SectionCard(
                        bgColor: p.cardBg,
                        borderColor: p.cardBorder,
                        shadowColor: p.cardShadow,
                        child: Column(
                          children: [
                            for (int i = 0; i < tiles.length; i++)
                              tiles[i]
                                  .animate()
                                  .fadeIn(
                                    delay: (80 + (i * 55)).ms,
                                    duration: 240.ms,
                                  )
                                  .slideY(
                                    begin: 0.10,
                                    end: 0,
                                    delay: (80 + (i * 55)).ms,
                                    duration: 300.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 120.ms, duration: 280.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openLanguageSheet() {
    final isDarkMode = AppTheme.mode.value == ThemeMode.dark;
    final p = _SettingsPalette.from(isDarkMode);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        final items = [
          _LangItem(
            code: 'lo',
            title: 'Laos',
            flag: const Text('🇱🇦', style: TextStyle(fontSize: 22)),
          ),
          _LangItem(
            code: 'en',
            title: 'English',
            flag: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
          ),
        ];

        return _BottomSheetShell(
          title: 'Select language',
          bgColor: p.sheetBg,
          borderColor: p.sheetBorder,
          titleColor: p.sheetTitle,
          closeColor: p.sheetClose,
          dragColor: p.sheetDrag,
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++)
                _LanguageRow(
                      item: items[i],
                      selected: _lang == items[i].code,
                      onTap: () {
                        setState(() => _lang = items[i].code);
                        Navigator.of(context).pop();
                      },
                      selectedBorder: p.langSelectedBorder,
                      border: p.langBorder,
                      selectedBg: p.langSelectedBg,
                      bg: p.langBg,
                      textColor: p.langText,
                      checkColor: p.langCheck,
                    )
                    .animate()
                    .fadeIn(delay: (60 + i * 70).ms, duration: 220.ms)
                    .slideY(
                      begin: 0.12,
                      end: 0,
                      delay: (60 + i * 70).ms,
                      duration: 280.ms,
                      curve: Curves.easeOutCubic,
                    ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  String? get _emergencyValueText {
    if (_loadingEmergency) return 'Loading';
    if (_emergencyError.isNotEmpty) return 'Error';
    if (_emergencyContacts.isEmpty) return 'None';
    return '${_emergencyContacts.length} contact${_emergencyContacts.length == 1 ? '' : 's'}';
  }

  Future<void> _loadEmergencyContacts() async {
    final studentId = widget.selectedStudent?.id?.trim() ?? '';
    if (studentId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingEmergency = false;
        _emergencyError = '';
        _emergencyContacts = const [];
      });
      return;
    }

    setState(() {
      _loadingEmergency = true;
      _emergencyError = '';
    });

    try {
      final response = await _api.get('/students/$studentId');
      if (!mounted) return;
      final record = _studentRecord(response);
      setState(() {
        _emergencyContacts = _extractEmergencyContacts(record);
        _loadingEmergency = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEmergency = false;
        _emergencyError = 'Could not load emergency contact.';
        _emergencyContacts = const [];
      });
    }
  }

  Map<String, dynamic> _studentRecord(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      final student = response['student'];
      if (student is Map<String, dynamic>) return student;
      return response;
    }
    return const {};
  }

  List<_EmergencyContactInfo> _extractEmergencyContacts(
    Map<String, dynamic> record,
  ) {
    final raw = record['emergency_contacts'] ?? record['emergencyContacts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => _EmergencyContactInfo.fromJson(item))
        .where((contact) => contact.hasAnyValue)
        .toList(growable: false);
  }

  Future<void> _openEmergencyPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EmergencyContactPage(
          selectedStudent: widget.selectedStudent,
          initialContacts: _emergencyContacts,
        ),
      ),
    );
    if (mounted) _loadEmergencyContacts();
  }
}

class _EmergencyContactPage extends StatefulWidget {
  const _EmergencyContactPage({
    required this.selectedStudent,
    this.initialContacts = const [],
  });

  final StudentCardItem? selectedStudent;
  final List<_EmergencyContactInfo> initialContacts;

  @override
  State<_EmergencyContactPage> createState() => _EmergencyContactPageState();
}

class _EmergencyContactPageState extends State<_EmergencyContactPage> {
  static const int _maxEmergencyContacts = 5;

  final ApiClient _api = ApiClient();
  bool _loading = true;
  bool _saving = false;
  String _error = '';
  late List<_EmergencyContactInfo> _contacts = widget.initialContacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final studentId = widget.selectedStudent?.id?.trim() ?? '';
    if (studentId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '';
        _contacts = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final response = await _api.get('/students/$studentId');
      if (!mounted) return;
      final record = _studentRecord(response);
      setState(() {
        _contacts = _extractEmergencyContacts(record);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load emergency contact.';
        _contacts = const [];
      });
    }
  }

  Future<bool> _saveContacts(List<_EmergencyContactInfo> next) async {
    final studentId = widget.selectedStudent?.id?.trim() ?? '';
    if (studentId.isEmpty || _saving) return false;

    setState(() => _saving = true);
    try {
      await _api.put(
        '/students/$studentId',
        body: {
          'emergency_contacts': next
              .map((contact) => contact.toJson())
              .toList(),
        },
      );
      if (!mounted) return false;
      setState(() {
        _contacts = next;
        _saving = false;
        _error = '';
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _error = 'Could not save emergency contact.';
      });
      GlobalAlert.showError(
        title: 'Save failed',
        message: 'Could not save emergency contact. Please try again.',
        buttonText: 'OK',
      );
      return false;
    }
  }

  Future<void> _addContact() async {
    if (_contacts.length >= _maxEmergencyContacts) {
      GlobalAlert.showWarning(
        title: 'Limit reached',
        message: 'You can add up to 5 emergency contacts only.',
        buttonText: 'OK',
      );
      return;
    }

    final created = await Navigator.of(context).push<_EmergencyContactInfo>(
      MaterialPageRoute(builder: (_) => const _EmergencyContactEditPage()),
    );
    if (created == null || !mounted) return;
    if (_contacts.length >= _maxEmergencyContacts) {
      GlobalAlert.showWarning(
        title: 'Limit reached',
        message: 'You can add up to 5 emergency contacts only.',
        buttonText: 'OK',
      );
      return;
    }

    final saved = await _saveContacts([..._contacts, created]);
    if (saved && mounted) _showSaved('Emergency contact added.');
  }

  Future<void> _editContact(int index) async {
    final updated = await Navigator.of(context).push<_EmergencyContactInfo>(
      MaterialPageRoute(
        builder: (_) => _EmergencyContactEditPage(contact: _contacts[index]),
      ),
    );
    if (updated == null || !mounted) return;
    final next = [..._contacts]..[index] = updated;
    final saved = await _saveContacts(next);
    if (saved && mounted) {
      GlobalAlert.showSuccess(
        title: 'Contact updated',
        message: 'Emergency contact information has been saved.',
        buttonText: 'OK',
      );
    }
  }

  Future<void> _deleteContact(int index) async {
    final removed = _contacts[index];
    final confirmed = await GlobalAlert.showConfirmation(
      title: 'Delete contact?',
      message: 'Remove ${removed.fullnameOrFallback} from emergency contacts.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: const Color(0xFFE11D48),
    );
    if (confirmed != true || !mounted) return;

    final next = [..._contacts]..removeAt(index);
    final saved = await _saveContacts(next);
    if (!saved || !mounted) return;
    GlobalAlert.showSuccess(
      title: 'Contact deleted',
      message: '${removed.fullnameOrFallback} has been removed.',
      buttonText: 'OK',
    );
  }

  Future<void> _moveContact(int from, int to) async {
    if (to < 0 || to >= _contacts.length || from == to) return;
    final next = [..._contacts];
    final item = next.removeAt(from);
    next.insert(to, item);
    final saved = await _saveContacts(next);
    if (saved && mounted) _showSaved('Priority updated.');
  }

  void _showSaved(String message) {
    GlobalAlert.showSuccess(title: 'Saved', message: message, buttonText: 'OK');
  }

  Map<String, dynamic> _studentRecord(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      final student = response['student'];
      if (student is Map<String, dynamic>) return student;
      return response;
    }
    return const {};
  }

  List<_EmergencyContactInfo> _extractEmergencyContacts(
    Map<String, dynamic> record,
  ) {
    final raw = record['emergency_contacts'] ?? record['emergencyContacts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => _EmergencyContactInfo.fromJson(item))
        .where((contact) => contact.hasAnyValue)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final p = _SettingsPalette.from(mode == ThemeMode.dark);
        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _TopBar(
                        title: 'Emergency contact',
                        onBack: () => Navigator.of(context).maybePop(),
                        titleColor: p.titleColor,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed:
                              _saving ||
                                  _contacts.length >= _maxEmergencyContacts
                              ? null
                              : _addContact,
                          icon: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: p.chevColor,
                                  ),
                                )
                              : const Icon(LucideIcons.plus),
                          color: p.titleColor,
                          splashRadius: 22,
                          tooltip: 'Add emergency contact',
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.selectedStudent != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: _SectionCard(
                      bgColor: p.cardBg,
                      borderColor: p.cardBorder,
                      shadowColor: p.cardShadow,
                      child: Row(
                        children: [
                          Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              LucideIcons.graduationCap,
                              color: Color(0xFF0756D1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.selectedStudent!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.selectedStudent!.studentId,
                                  style: TextStyle(
                                    color: p.chevColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: _EmergencyContactContent(
                      loading: _loading,
                      error: _error,
                      contacts: _contacts,
                      saving: _saving,
                      textColor: p.langText,
                      mutedColor: p.chevColor,
                      borderColor: p.langBorder,
                      cardColor: p.langBg,
                      onRetry: _load,
                      onAdd: _addContact,
                      onEdit: _editContact,
                      onDelete: _deleteContact,
                      onMove: _moveContact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmergencyContactInfo {
  const _EmergencyContactInfo({
    required this.fullname,
    required this.relationship,
    required this.job,
    required this.workingPlace,
    required this.phone1,
    required this.phone2,
    required this.hospital,
    required this.doctorName,
    required this.doctorContact,
  });

  final String fullname;
  final String relationship;
  final String job;
  final String workingPlace;
  final String phone1;
  final String phone2;
  final String hospital;
  final String doctorName;
  final String doctorContact;

  String get fullnameOrFallback =>
      fullname.isEmpty ? 'Emergency contact' : fullname;

  bool get hasAnyValue =>
      fullname.isNotEmpty ||
      relationship.isNotEmpty ||
      job.isNotEmpty ||
      workingPlace.isNotEmpty ||
      phone1.isNotEmpty ||
      phone2.isNotEmpty ||
      hospital.isNotEmpty ||
      doctorName.isNotEmpty ||
      doctorContact.isNotEmpty;

  factory _EmergencyContactInfo.fromJson(Map<dynamic, dynamic> json) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    return _EmergencyContactInfo(
      fullname: read(const ['fullname', 'fullName', 'name']),
      relationship: read(const [
        'relationship_to_student',
        'relationshipToStudent',
        'relation',
      ]),
      job: read(const ['job', 'occupation']),
      workingPlace: read(const ['working_place', 'workingPlace']),
      phone1: read(const ['phone1', 'phone_1', 'phone']),
      phone2: read(const ['phone2', 'phone_2']),
      hospital: read(const ['hospital']),
      doctorName: read(const ['doc_name', 'docName', 'doctor_name']),
      doctorContact: read(const [
        'doc_contract',
        'docContact',
        'doctor_contact',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullname': fullname,
      'relationship_to_student': relationship,
      'job': job,
      'working_place': workingPlace,
      'phone1': phone1,
      'phone2': phone2,
      'hospital': hospital,
      'doc_name': doctorName,
      'doc_contract': doctorContact,
    };
  }
}

class _EmergencyContactEditPage extends StatefulWidget {
  const _EmergencyContactEditPage({this.contact});

  final _EmergencyContactInfo? contact;

  @override
  State<_EmergencyContactEditPage> createState() =>
      _EmergencyContactEditPageState();
}

class _EmergencyContactEditPageState extends State<_EmergencyContactEditPage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.contact?.fullname ?? '',
  );
  late final TextEditingController _relationship = TextEditingController(
    text: widget.contact?.relationship ?? '',
  );
  late final TextEditingController _phone1 = TextEditingController(
    text: widget.contact?.phone1 ?? '',
  );
  late final TextEditingController _phone2 = TextEditingController(
    text: widget.contact?.phone2 ?? '',
  );
  late final TextEditingController _job = TextEditingController(
    text: widget.contact?.job ?? '',
  );
  late final TextEditingController _workingPlace = TextEditingController(
    text: widget.contact?.workingPlace ?? '',
  );
  late final TextEditingController _hospital = TextEditingController(
    text: widget.contact?.hospital ?? '',
  );
  late final TextEditingController _doctorName = TextEditingController(
    text: widget.contact?.doctorName ?? '',
  );
  late final TextEditingController _doctorContact = TextEditingController(
    text: widget.contact?.doctorContact ?? '',
  );

  bool get _isEditing => widget.contact != null;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone1.dispose();
    _phone2.dispose();
    _job.dispose();
    _workingPlace.dispose();
    _hospital.dispose();
    _doctorName.dispose();
    _doctorContact.dispose();
    super.dispose();
  }

  void _save() {
    final contact = _EmergencyContactInfo(
      fullname: _name.text.trim(),
      relationship: _relationship.text.trim(),
      job: _job.text.trim(),
      workingPlace: _workingPlace.text.trim(),
      phone1: _phone1.text.trim(),
      phone2: _phone2.text.trim(),
      hospital: _hospital.text.trim(),
      doctorName: _doctorName.text.trim(),
      doctorContact: _doctorContact.text.trim(),
    );

    if (contact.fullname.isEmpty || contact.phone1.isEmpty) {
      GlobalAlert.showWarning(
        title: 'Missing information',
        message: 'Name and Phone #1 are required.',
        buttonText: 'OK',
      );
      return;
    }
    Navigator.of(context).pop(contact);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final p = _SettingsPalette.from(mode == ThemeMode.dark);
        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: _TopBar(
                    title: _isEditing ? 'Edit contact' : 'Add contact',
                    onBack: () => Navigator.of(context).maybePop(),
                    titleColor: p.titleColor,
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    children: [
                      _SectionCard(
                        bgColor: p.cardBg,
                        borderColor: p.cardBorder,
                        shadowColor: p.cardShadow,
                        child: Column(
                          children: [
                            _EmergencyTextField(
                              controller: _name,
                              label: 'Full name',
                              required: true,
                            ),
                            _EmergencyTextField(
                              controller: _relationship,
                              label: 'Relationship with student',
                            ),
                            _EmergencyTextField(
                              controller: _phone1,
                              label: 'Phone #1',
                              required: true,
                              keyboardType: TextInputType.phone,
                            ),
                            _EmergencyTextField(
                              controller: _phone2,
                              label: 'Phone #2',
                              keyboardType: TextInputType.phone,
                            ),
                            _EmergencyTextField(controller: _job, label: 'Job'),
                            _EmergencyTextField(
                              controller: _workingPlace,
                              label: 'Working place',
                            ),
                            _EmergencyTextField(
                              controller: _hospital,
                              label: 'Hospital',
                            ),
                            _EmergencyTextField(
                              controller: _doctorName,
                              label: 'Doctor',
                            ),
                            _EmergencyTextField(
                              controller: _doctorContact,
                              label: 'Doctor contact',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(LucideIcons.check, size: 17),
                      label: Text(_isEditing ? 'Save changes' : 'Add contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0756D1),
                        foregroundColor: const Color(0xFFF8FBFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmergencyTextField extends StatelessWidget {
  const _EmergencyTextField({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0756D1);
    const border = Color(0xFFE3E9F2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        style: const TextStyle(
          color: Color(0xFF082653),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          floatingLabelStyle: const TextStyle(
            color: blue,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF647594),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          filled: true,
          fillColor: const Color(0xFFFCFDFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 22,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: border, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: border, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: blue, width: 2.2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.6),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFE11D48), width: 2.2),
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactContent extends StatefulWidget {
  const _EmergencyContactContent({
    required this.loading,
    required this.error,
    required this.contacts,
    required this.saving,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.cardColor,
    required this.onRetry,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
  });

  final bool loading;
  final String error;
  final List<_EmergencyContactInfo> contacts;
  final bool saving;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final Color cardColor;
  final VoidCallback onRetry;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final void Function(int from, int to) onMove;

  @override
  State<_EmergencyContactContent> createState() =>
      _EmergencyContactContentState();
}

class _EmergencyContactContentState extends State<_EmergencyContactContent> {
  final Set<int> _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _EmergencySkeletonCard(
          borderColor: widget.borderColor,
          cardColor: widget.cardColor,
          mutedColor: widget.mutedColor,
        ),
      );
    }

    if (widget.error.isNotEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                color: widget.mutedColor,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                widget.error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.contacts.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.heartPulse, color: widget.mutedColor, size: 30),
              const SizedBox(height: 12),
              Text(
                'No emergency contact found.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0756D1),
                    foregroundColor: const Color(0xFFF8FBFF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: widget.contacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final isExpanded = _expanded.contains(index);
        return _EmergencyContactCard(
          contact: widget.contacts[index],
          index: index,
          total: widget.contacts.length,
          expanded: isExpanded,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(index);
              } else {
                _expanded.add(index);
              }
            });
          },
          textColor: widget.textColor,
          mutedColor: widget.mutedColor,
          borderColor: widget.borderColor,
          cardColor: widget.cardColor,
          saving: widget.saving,
          onEdit: () => widget.onEdit(index),
          onDelete: () => widget.onDelete(index),
          onMoveUp: index == 0 ? null : () => widget.onMove(index, index - 1),
          onMoveDown: index == widget.contacts.length - 1
              ? null
              : () => widget.onMove(index, index + 1),
        );
      },
    );
  }
}

class _EmergencySkeletonCard extends StatelessWidget {
  const _EmergencySkeletonCard({
    required this.borderColor,
    required this.cardColor,
    required this.mutedColor,
  });

  final Color borderColor;
  final Color cardColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    Color bar(double opacity) => mutedColor.withValues(alpha: opacity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bar(.14),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 150,
                  decoration: BoxDecoration(
                    color: bar(.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 10,
                  width: 94,
                  decoration: BoxDecoration(
                    color: bar(.12),
                    borderRadius: BorderRadius.circular(999),
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

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({
    required this.contact,
    required this.index,
    required this.total,
    required this.expanded,
    required this.onTap,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.cardColor,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final _EmergencyContactInfo contact;
  final int index;
  final int total;
  final bool expanded;
  final VoidCallback onTap;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final Color cardColor;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final name = contact.fullname.isEmpty
        ? 'Emergency contact'
        : contact.fullname;
    final primaryPhone = contact.phone1.isNotEmpty
        ? contact.phone1
        : contact.phone2;
    final detailRows = [
      _ContactInfoData(
        LucideIcons.phone,
        'Phone #2',
        contact.phone2 == primaryPhone ? '' : contact.phone2,
      ),
      _ContactInfoData(LucideIcons.briefcaseBusiness, 'Job', contact.job),
      _ContactInfoData(
        LucideIcons.building,
        'Working place',
        contact.workingPlace,
      ),
      _ContactInfoData(LucideIcons.hospital, 'Hospital', contact.hospital),
      _ContactInfoData(LucideIcons.syringe, 'Doctor', contact.doctorName),
      _ContactInfoData(
        LucideIcons.phone,
        'Doctor contact',
        contact.doctorContact,
      ),
    ].where((row) => row.value.trim().isNotEmpty).toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: expanded ? const Color(0xFFB9CEF5) : borderColor,
              width: expanded ? 1.4 : 1,
            ),
            boxShadow: expanded
                ? [
                    BoxShadow(
                      color: const Color(0xFF0756D1).withValues(alpha: .08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  _IconChipButton(
                    icon: LucideIcons.arrowUpRight,
                    onTap: saving ? null : onMoveUp,
                    color: mutedColor,
                    tooltip: 'Move higher priority',
                  ),
                  const SizedBox(width: 6),
                  _IconChipButton(
                    icon: LucideIcons.arrowDownToLine,
                    onTap: saving ? null : onMoveDown,
                    color: mutedColor,
                    tooltip: 'Move lower priority',
                  ),
                  const SizedBox(width: 6),
                  _IconChipButton(
                    icon: LucideIcons.squarePen,
                    onTap: saving ? null : onEdit,
                    color: const Color(0xFF0756D1),
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 6),
                  _IconChipButton(
                    icon: LucideIcons.trash2,
                    onTap: saving ? null : onDelete,
                    color: const Color(0xFFE11D48),
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EmergencyAvatar(name: name, active: expanded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EmergencySummary(
                      name: name,
                      relationship: contact.relationship,
                      phone: primaryPhone,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      LucideIcons.chevronDown,
                      color: mutedColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expanded
                    ? _EmergencyDetails(
                        rows: detailRows,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyAvatar extends StatelessWidget {
  const _EmergencyAvatar({required this.name, required this.active});

  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final label = clean.isEmpty ? 'E' : clean.characters.first.toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0756D1) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFFF8FBFF) : const Color(0xFF0756D1),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: enabled ? .08 : .04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 14,
              color: color.withValues(alpha: enabled ? 1 : .32),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencySummary extends StatelessWidget {
  const _EmergencySummary({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.textColor,
    required this.mutedColor,
  });

  final String name;
  final String relationship;
  final String phone;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (relationship.isNotEmpty)
              _TinyPill(
                icon: LucideIcons.user,
                text: relationship,
                color: mutedColor,
              ),
            if (phone.isNotEmpty)
              _TinyPill(
                icon: LucideIcons.phone,
                text: phone,
                color: const Color(0xFF0756D1),
              ),
          ],
        ),
      ],
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoData {
  const _ContactInfoData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _EmergencyDetails extends StatelessWidget {
  const _EmergencyDetails({
    required this.rows,
    required this.textColor,
    required this.mutedColor,
  });

  final List<_ContactInfoData> rows;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          'No additional details.',
          style: TextStyle(
            color: mutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: mutedColor.withValues(alpha: .14)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 360;
              final tileWidth = twoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final row in rows)
                    SizedBox(
                      width: tileWidth,
                      child: _ContactInfoTile(
                        icon: row.icon,
                        label: row.label,
                        value: row.value,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContactInfoTile extends StatelessWidget {
  const _ContactInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EDF7)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0756D1).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 14, color: const Color(0xFF0756D1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
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

// =====================
// Palette (light = original, dark = only colors to look dark)
// =====================

class _SettingsPalette {
  const _SettingsPalette({
    required this.bg,
    required this.titleColor,
    required this.textColor,
    required this.iconColor,
    required this.chevColor,
    required this.divider,
    required this.cardBg,
    required this.cardBorder,
    required this.cardShadow,
    required this.sheetBg,
    required this.sheetBorder,
    required this.sheetTitle,
    required this.sheetClose,
    required this.sheetDrag,
    required this.langSelectedBorder,
    required this.langBorder,
    required this.langSelectedBg,
    required this.langBg,
    required this.langText,
    required this.langCheck,
    required this.logoutBg,
    required this.logoutBorder,
  });

  final Color bg;
  final Color titleColor;
  final Color textColor;
  final Color iconColor;
  final Color chevColor;
  final Color divider;

  final Color cardBg;
  final Color cardBorder;
  final Color cardShadow;

  final Color sheetBg;
  final Color sheetBorder;
  final Color sheetTitle;
  final Color sheetClose;
  final Color sheetDrag;

  final Color langSelectedBorder;
  final Color langBorder;
  final Color langSelectedBg;
  final Color langBg;
  final Color langText;
  final Color langCheck;

  final Color logoutBg;
  final Color logoutBorder;

  factory _SettingsPalette.from(bool isDark) {
    if (!isDark) {
      // ✅ EXACTLY your original light style
      return const _SettingsPalette(
        bg: _SettingsPageState._bg,
        titleColor: _SettingsPageState._titleColor,
        textColor: _SettingsPageState._textColor,
        iconColor: _SettingsPageState._iconColor,
        chevColor: _SettingsPageState._chevColor,
        divider: _SettingsPageState._divider,
        cardBg: Colors.white,
        cardBorder: Color(0xFFF1F5F9),
        cardShadow: Color(0x0A111827),
        sheetBg: Colors.white,
        sheetBorder: Color(0xFFF1F5F9),
        sheetTitle: Color(0xFF111827),
        sheetClose: Color(0xFF9CA3AF),
        sheetDrag: Color(0xFFE5E7EB),
        langSelectedBorder: Color(0xFF111827),
        langBorder: Color(0xFFF1F5F9),
        langSelectedBg: Color(0xFFF9FAFB),
        langBg: Colors.white,
        langText: Color(0xFF111827),
        langCheck: Color(0xFF111827),
        logoutBg: Color(0xFFFEF2F2),
        logoutBorder: Color(0xFFFEE2E2),
      );
    }

    // ✅ Dark colors only (layout remains identical)
    return _SettingsPalette(
      bg: const Color(0xFF0B1220),
      titleColor: Colors.white.withOpacity(.95),
      textColor: Colors.white.withOpacity(.75),
      iconColor: Colors.white.withOpacity(.90),
      chevColor: Colors.white.withOpacity(.55),
      divider: Colors.white.withOpacity(.10),
      cardBg: const Color(0xFF0F172A),
      cardBorder: Colors.white.withOpacity(.10),
      cardShadow: Colors.black.withOpacity(.35),
      sheetBg: const Color(0xFF0F172A),
      sheetBorder: Colors.white.withOpacity(.12),
      sheetTitle: Colors.white.withOpacity(.92),
      sheetClose: Colors.white.withOpacity(.60),
      sheetDrag: Colors.white.withOpacity(.18),
      langSelectedBorder: Colors.white.withOpacity(.85),
      langBorder: Colors.white.withOpacity(.12),
      langSelectedBg: Colors.white.withOpacity(.06),
      langBg: const Color(0xFF0F172A),
      langText: Colors.white.withOpacity(.92),
      langCheck: Colors.white.withOpacity(.90),
      logoutBg: const Color(0xFF2A0F14),
      logoutBorder: const Color(0xFF5B1B25),
    );
  }
}

// =====================
// UI widgets (layout unchanged)
// =====================

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.titleColor,
  });

  final String title;
  final VoidCallback onBack;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.arrowLeft),
              color: titleColor,
              splashRadius: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    required this.bgColor,
    required this.borderColor,
    required this.shadowColor,
  });

  final Widget child;
  final Color bgColor;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 8),
            color: shadowColor,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
    required this.iconColor,
    required this.textColor,
    this.valueText,
  });

  final IconData icon;
  final String label;
  final String? valueText;
  final Widget trailing;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Center(child: Icon(icon, size: 20, color: iconColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (valueText != null) ...[
                Text(
                  valueText!,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.onTap,
    required this.bgColor,
    required this.borderColor,
  });

  final VoidCallback onTap;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: bgColor,
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.logOut, size: 18, color: Color(0xFFDC2626)),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 220.ms, duration: 260.ms)
        .slideY(
          begin: 0.10,
          end: 0,
          delay: 220.ms,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({
    required this.title,
    required this.child,
    required this.bgColor,
    required this.borderColor,
    required this.titleColor,
    required this.closeColor,
    required this.dragColor,
  });

  final String title;
  final Widget child;

  final Color bgColor;
  final Color borderColor;
  final Color titleColor;
  final Color closeColor;
  final Color dragColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 12),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: dragColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                  splashRadius: 20,
                  color: closeColor,
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.selectedBorder,
    required this.border,
    required this.selectedBg,
    required this.bg,
    required this.textColor,
    required this.checkColor,
  });

  final _LangItem item;
  final bool selected;
  final VoidCallback onTap;

  final Color selectedBorder;
  final Color border;
  final Color selectedBg;
  final Color bg;
  final Color textColor;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    final b = selected ? selectedBorder : border;
    final c = selected ? selectedBg : bg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: b),
            color: c,
          ),
          child: Row(
            children: [
              item.flag,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected) Icon(LucideIcons.check, color: checkColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangItem {
  const _LangItem({
    required this.code,
    required this.title,
    required this.flag,
  });

  final String code;
  final String title;
  final Widget flag;
}

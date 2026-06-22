import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class SiblingEntry {
  String fullname = '';
  String nickname = '';
  String dob = '';
  String currentSchool = '';
  String phone1 = '';
  String phone2 = '';
  String village = '';

  Map<String, dynamic> toJson() => {
        'fullname': fullname.trim(),
        if (nickname.trim().isNotEmpty) 'nickname': nickname.trim(),
        if (dob.trim().isNotEmpty) 'dob': dob.trim(),
        if (currentSchool.trim().isNotEmpty) 'current_school': currentSchool.trim(),
        if (phone1.trim().isNotEmpty) 'phone1': phone1.trim(),
        if (phone2.trim().isNotEmpty) 'phone2': phone2.trim(),
        if (village.trim().isNotEmpty) 'current_village': village.trim(),
      };
}

class LiveWithEntry {
  String firstNameLao = '';
  String firstNameEng = '';
  String middleNameLao = '';
  String middleNameEng = '';
  String lastNameLao = '';
  String lastNameEng = '';
  String nickname = '';
  String educationLevel = '';
  String occupation = '';
  String workplace = '';
  String email = '';
  String phone1 = '';
  String phone2 = '';
  String dob = '';
  String idCardNo = '';
  String passportNo = '';
  String familyBookNo = '';
  String nationality = '';
  String ethnicity = '';
  String religion = '';
  String homeNo = '';
  String homeUnit = '';
  String village = '';
  String district = '';
  String province = '';

  String _fullname() {
    final parts = [firstNameEng, middleNameEng, lastNameEng]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      final lao = [firstNameLao, middleNameLao, lastNameLao]
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return lao.join(' ');
    }
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'fullname': _fullname(),
        'nickname': nickname.trim(),
        'dob': dob.trim(),
        'id_card': idCardNo.trim(),
        if (passportNo.trim().isNotEmpty) 'passport_no': passportNo.trim(),
        if (nationality.trim().isNotEmpty) 'nationality': nationality.trim(),
        if (ethnicity.trim().isNotEmpty) 'ethnicity': ethnicity.trim(),
        if (religion.trim().isNotEmpty) 'religion': religion.trim(),
        if (educationLevel.trim().isNotEmpty) 'education_level': educationLevel.trim(),
        if (village.trim().isNotEmpty) 'current_village': village.trim(),
        if (district.trim().isNotEmpty) 'current_district': district.trim(),
        if (province.trim().isNotEmpty) 'current_province': province.trim(),
        if (homeNo.trim().isNotEmpty) 'home_no': homeNo.trim(),
        if (homeUnit.trim().isNotEmpty) 'home_unit': homeUnit.trim(),
        if (familyBookNo.trim().isNotEmpty) 'family_book_no': familyBookNo.trim(),
        if (phone1.trim().isNotEmpty) 'phone_number_one': phone1.trim(),
        if (phone2.trim().isNotEmpty) 'phone_number_two': phone2.trim(),
        if (workplace.trim().isNotEmpty) 'working_place': workplace.trim(),
        if (email.trim().isNotEmpty) 'email': email.trim(),
      };
}

class EmergencyContactEntry {
  String fullname = '';
  String occupation = '';
  String workplace = '';
  String phone1 = '';
  String phone2 = '';
  String hospital = '';
  String docName = '';
  String docContact = '';

  Map<String, dynamic> toJson() => {
        'fullname': fullname.trim(),
        if (occupation.trim().isNotEmpty) 'job': occupation.trim(),
        if (workplace.trim().isNotEmpty) 'working_place': workplace.trim(),
        if (phone1.trim().isNotEmpty) 'phone1': phone1.trim(),
        if (phone2.trim().isNotEmpty) 'phone2': phone2.trim(),
        if (hospital.trim().isNotEmpty) 'hospital': hospital.trim(),
        if (docName.trim().isNotEmpty) 'doc_name': docName.trim(),
        if (docContact.trim().isNotEmpty) 'doc_contract': docContact.trim(),
      };
}

class SchoolHistoryEntry {
  String academicYear;
  String yearLevel;
  String school;
  SchoolHistoryEntry({this.academicYear = '', this.yearLevel = '', this.school = ''});

  bool get isEmpty =>
      academicYear.trim().isEmpty && yearLevel.trim().isEmpty && school.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'academic_year': academicYear.trim(),
        'year_level': yearLevel.trim(),
        'school': school.trim(),
      };
}

class StudentSubmission {
  // Step 1 — Student basic
  String firstNameLao = '';
  String firstNameEng = '';
  String middleNameLao = '';
  String middleNameEng = '';
  String lastNameLao = '';
  String lastNameEng = '';
  String nickname = '';
  String dob = '';
  String gender = '';
  String nationality = '';
  String ethnicity = '';
  String religion = '';
  String passportNo = '';

  // Step 2 — Place of Birth + Current Address
  String villageBirth = '';
  String districtBirth = '';
  String provinceBirth = '';
  String village = '';
  String district = '';
  String province = '';

  // Step 3 — Education history (fixed 2 rows)
  final SchoolHistoryEntry kindergarten = SchoolHistoryEntry();
  final SchoolHistoryEntry primary = SchoolHistoryEntry();

  // Step 4 — Siblings (dynamic)
  final List<SiblingEntry> siblings = [];

  // Step 5 — Living with (dynamic)
  final List<LiveWithEntry> livingWith = [];

  // Step 6 — Emergency contact (single — matches design)
  final EmergencyContactEntry emergency = EmergencyContactEntry();
}

class StudentRegistrationService {
  StudentRegistrationService({ApiClient? client})
      : _api = client ?? ApiClient(timeout: const Duration(seconds: 60));
  final ApiClient _api;

  Future<String?> _resolveBranchId() async {
    try {
      final res = await _api.get('/branches');
      final list = res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] as List : null);
      if (list == null || list.isEmpty) return null;
      final first = list.first;
      if (first is Map) return first['id']?.toString();
    } catch (_) {}
    return null;
  }

  String _generateStudentId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'PENDING-${ts.substring(ts.length - 9)}';
  }

  Future<Map<String, dynamic>> register({
    required StudentSubmission s,
    required String parentId,
  }) async {
    final branchId = await _resolveBranchId();
    if (branchId == null) {
      throw ApiException('No school branch found. Please contact admin.');
    }

    final body = <String, dynamic>{
      'branchId': branchId,
      'student_id': _generateStudentId(),
      if (s.firstNameLao.trim().isNotEmpty) 'first_name_lao': s.firstNameLao.trim(),
      if (s.firstNameEng.trim().isNotEmpty) 'first_name_eng': s.firstNameEng.trim(),
      if (s.middleNameLao.trim().isNotEmpty) 'midle_name_lao': s.middleNameLao.trim(),
      if (s.middleNameEng.trim().isNotEmpty) 'midle_name_eng': s.middleNameEng.trim(),
      if (s.lastNameLao.trim().isNotEmpty) 'last_name_lao': s.lastNameLao.trim(),
      if (s.lastNameEng.trim().isNotEmpty) 'last_name_eng': s.lastNameEng.trim(),
      if (s.nickname.trim().isNotEmpty) 'nickname': s.nickname.trim(),
      'dob': s.dob.trim(),
      'gender': s.gender.trim().isEmpty ? 'unspecified' : s.gender.trim(),
      if (s.nationality.trim().isNotEmpty) 'nationality': s.nationality.trim(),
      if (s.ethnicity.trim().isNotEmpty) 'ethnicity': s.ethnicity.trim(),
      if (s.religion.trim().isNotEmpty) 'religion': s.religion.trim(),
      if (s.passportNo.trim().isNotEmpty) 'passport_number': s.passportNo.trim(),
      if (s.village.trim().isNotEmpty) 'village': s.village.trim(),
      if (s.villageBirth.trim().isNotEmpty) 'village_bd': s.villageBirth.trim(),
      if (s.districtBirth.trim().isNotEmpty || s.provinceBirth.trim().isNotEmpty)
        'dm_birth': [s.villageBirth, s.districtBirth, s.provinceBirth]
            .where((e) => e.trim().isNotEmpty)
            .join(', '),
      if (s.siblings.isNotEmpty)
        'bos_info': s.siblings
            .where((e) => e.fullname.trim().isNotEmpty)
            .map((e) => e.toJson())
            .toList(),
      if (s.livingWith.isNotEmpty)
        'live_with': s.livingWith.map((e) => e.toJson()).toList(),
      if (s.emergency.fullname.trim().isNotEmpty)
        'emergency_contacts': [s.emergency.toJson()],
      if (!s.kindergarten.isEmpty) 'his_school_kindergarten': [s.kindergarten.toJson()],
      if (!s.primary.isEmpty) 'his_school_primary': [s.primary.toJson()],
      'parentIds': [parentId],
    };

    final res = await _api.post('/students', body: body);
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'data': res};
  }
}

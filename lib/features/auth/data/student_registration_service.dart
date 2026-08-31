import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  /// Lossless draft serialization — preserves empty strings so a half-filled
  /// form round-trips cleanly. Distinct from [toJson] which strips empties
  /// for the API.
  Map<String, dynamic> toDraft() => {
    'fullname': fullname,
    'nickname': nickname,
    'dob': dob,
    'currentSchool': currentSchool,
    'phone1': phone1,
    'phone2': phone2,
    'village': village,
  };

  static SiblingEntry fromDraft(Map<String, dynamic> j) => SiblingEntry()
    ..fullname = (j['fullname'] ?? '').toString()
    ..nickname = (j['nickname'] ?? '').toString()
    ..dob = (j['dob'] ?? '').toString()
    ..currentSchool = (j['currentSchool'] ?? '').toString()
    ..phone1 = (j['phone1'] ?? '').toString()
    ..phone2 = (j['phone2'] ?? '').toString()
    ..village = (j['village'] ?? '').toString();

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

  Map<String, dynamic> toDraft() => {
    'firstNameLao': firstNameLao,
    'firstNameEng': firstNameEng,
    'middleNameLao': middleNameLao,
    'middleNameEng': middleNameEng,
    'lastNameLao': lastNameLao,
    'lastNameEng': lastNameEng,
    'nickname': nickname,
    'educationLevel': educationLevel,
    'occupation': occupation,
    'workplace': workplace,
    'email': email,
    'phone1': phone1,
    'phone2': phone2,
    'dob': dob,
    'idCardNo': idCardNo,
    'passportNo': passportNo,
    'familyBookNo': familyBookNo,
    'nationality': nationality,
    'ethnicity': ethnicity,
    'religion': religion,
    'homeNo': homeNo,
    'homeUnit': homeUnit,
    'village': village,
    'district': district,
    'province': province,
  };

  static LiveWithEntry fromDraft(Map<String, dynamic> j) => LiveWithEntry()
    ..firstNameLao = (j['firstNameLao'] ?? '').toString()
    ..firstNameEng = (j['firstNameEng'] ?? '').toString()
    ..middleNameLao = (j['middleNameLao'] ?? '').toString()
    ..middleNameEng = (j['middleNameEng'] ?? '').toString()
    ..lastNameLao = (j['lastNameLao'] ?? '').toString()
    ..lastNameEng = (j['lastNameEng'] ?? '').toString()
    ..nickname = (j['nickname'] ?? '').toString()
    ..educationLevel = (j['educationLevel'] ?? '').toString()
    ..occupation = (j['occupation'] ?? '').toString()
    ..workplace = (j['workplace'] ?? '').toString()
    ..email = (j['email'] ?? '').toString()
    ..phone1 = (j['phone1'] ?? '').toString()
    ..phone2 = (j['phone2'] ?? '').toString()
    ..dob = (j['dob'] ?? '').toString()
    ..idCardNo = (j['idCardNo'] ?? '').toString()
    ..passportNo = (j['passportNo'] ?? '').toString()
    ..familyBookNo = (j['familyBookNo'] ?? '').toString()
    ..nationality = (j['nationality'] ?? '').toString()
    ..ethnicity = (j['ethnicity'] ?? '').toString()
    ..religion = (j['religion'] ?? '').toString()
    ..homeNo = (j['homeNo'] ?? '').toString()
    ..homeUnit = (j['homeUnit'] ?? '').toString()
    ..village = (j['village'] ?? '').toString()
    ..district = (j['district'] ?? '').toString()
    ..province = (j['province'] ?? '').toString();

  String _fullname() {
    final parts = [
      firstNameEng,
      middleNameEng,
      lastNameEng,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      final lao = [
        firstNameLao,
        middleNameLao,
        lastNameLao,
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return lao.join(' ');
    }
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
    'fullname': _fullname(),
    if (firstNameLao.trim().isNotEmpty) 'first_name_lao': firstNameLao.trim(),
    if (firstNameEng.trim().isNotEmpty) 'first_name_eng': firstNameEng.trim(),
    if (middleNameLao.trim().isNotEmpty) 'midle_name_lao': middleNameLao.trim(),
    if (middleNameEng.trim().isNotEmpty) 'midle_name_eng': middleNameEng.trim(),
    if (lastNameLao.trim().isNotEmpty) 'last_name_lao': lastNameLao.trim(),
    if (lastNameEng.trim().isNotEmpty) 'last_name_eng': lastNameEng.trim(),
    'nickname': nickname.trim(),
    'dob': dob.trim(),
    'id_card': idCardNo.trim(),
    if (passportNo.trim().isNotEmpty) 'passport_no': passportNo.trim(),
    if (nationality.trim().isNotEmpty) 'nationality': nationality.trim(),
    if (ethnicity.trim().isNotEmpty) 'ethnicity': ethnicity.trim(),
    if (religion.trim().isNotEmpty) 'religion': religion.trim(),
    if (educationLevel.trim().isNotEmpty)
      'education_level': educationLevel.trim(),
    if (occupation.trim().isNotEmpty) 'occupation': occupation.trim(),
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
  String relationshipToStudent = '';
  String occupation = '';
  String workplace = '';
  String phone1 = '';
  String phone2 = '';
  String hospital = '';
  String docName = '';
  String docContact = '';

  Map<String, dynamic> toDraft() => {
    'fullname': fullname,
    'relationshipToStudent': relationshipToStudent,
    'occupation': occupation,
    'workplace': workplace,
    'phone1': phone1,
    'phone2': phone2,
    'hospital': hospital,
    'docName': docName,
    'docContact': docContact,
  };

  static EmergencyContactEntry fromDraft(Map<String, dynamic> j) =>
      EmergencyContactEntry()
        ..fullname = (j['fullname'] ?? '').toString()
        ..relationshipToStudent =
            (j['relationshipToStudent'] ??
                    j['relationship_to_student'] ??
                    j['relationship'] ??
                    j['relation'] ??
                    '')
                .toString()
        ..occupation = (j['occupation'] ?? '').toString()
        ..workplace = (j['workplace'] ?? '').toString()
        ..phone1 = (j['phone1'] ?? '').toString()
        ..phone2 = (j['phone2'] ?? '').toString()
        ..hospital = (j['hospital'] ?? '').toString()
        ..docName = (j['docName'] ?? '').toString()
        ..docContact = (j['docContact'] ?? '').toString();

  Map<String, dynamic> toJson() => {
    'fullname': fullname.trim(),
    if (relationshipToStudent.trim().isNotEmpty)
      'relationship_to_student': relationshipToStudent.trim(),
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
  SchoolHistoryEntry({
    this.academicYear = '',
    this.yearLevel = '',
    this.school = '',
  });

  bool get isEmpty =>
      academicYear.trim().isEmpty &&
      yearLevel.trim().isEmpty &&
      school.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'academic_year': academicYear.trim(),
    'year_level': yearLevel.trim(),
    'school': school.trim(),
  };

  Map<String, dynamic> toDraft() => {
    'academicYear': academicYear,
    'yearLevel': yearLevel,
    'school': school,
  };

  void fillFromDraft(Map<String, dynamic> j) {
    academicYear = (j['academicYear'] ?? '').toString();
    yearLevel = (j['yearLevel'] ?? '').toString();
    school = (j['school'] ?? '').toString();
  }
}

class StudentPhysicalDisabilityCategory {
  final String title;
  final String description;
  final List<String> details;

  const StudentPhysicalDisabilityCategory({
    required this.title,
    this.description = '',
    required this.details,
  });
}

class StudentPhysicalDisabilitySelection {
  static const String optionTitle = 'Physical and Mobility Disabilities';
  static const String sensoryOptionTitle = 'Sensory Disabilities';
  static const String intellectualOptionTitle =
      'Intellectual and Cognitive Disabilities';
  static const String neurodevelopmentalOptionTitle =
      'Neurodevelopmental and Learning Disabilities';
  static const String psychiatricOptionTitle =
      'Psychiatric and Mental Health Disabilities';
  static const String chronicIllnessOptionTitle =
      'Chronic Illnesses and Invisible Disabilities';
  static const List<StudentPhysicalDisabilityCategory> categories = [
    StudentPhysicalDisabilityCategory(
      title: 'Mobility disability',
      details: [
        'Difficulty walking or using stairs',
        'Often requiring wheelchairs, walkers, or canes.',
      ],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Amputation and Limb Differences',
      details: ['Missing limbs from birth, accidents, or medical procedures.'],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Neuromuscular Conditions',
      details: ['Cerebral Palsy', 'Muscular Dystrophy', 'Multiple Sclerosis'],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Spinal Cord Injuries',
      details: [
        'Trauma to the spine resulting in partial pain',
        'Trauma to the spine resulting in full paralysis',
      ],
    ),
  ];
  static const List<StudentPhysicalDisabilityCategory> sensoryCategories = [
    StudentPhysicalDisabilityCategory(
      title: 'Visual differences',
      details: [
        'Low vision not correctable by glasses',
        'Legal blindness',
        'Total blindness',
        'Colourblindness',
        'Albinism or aniridia',
      ],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Hearing loss',
      details: [
        'Mild hearing loss (cannot hear soft sounds)',
        'Moderate hearing loss (struggles to hear normal speech)',
        'Severe hearing loss (cannot hear speech)',
        'Profound deafness (cannot hear speech and only detects very loud sounds)',
      ],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Sensory Processing Differences',
      details: [
        'Interoception (Internal Senses): Processing internal bodily signals like heart rate, hunger, thirst, and the need to use the restroom.',
      ],
    ),
  ];
  static const List<StudentPhysicalDisabilityCategory> intellectualCategories =
      [
        StudentPhysicalDisabilityCategory(
          title: 'Mild intellectual disability',
          details: [],
        ),
        StudentPhysicalDisabilityCategory(
          title: 'Moderate intellectual disability',
          details: [],
        ),
        StudentPhysicalDisabilityCategory(
          title: 'Severe intellectual disability',
          details: [],
        ),
        StudentPhysicalDisabilityCategory(
          title: 'Traumatic Brain Injuries (TBI)',
          details: [],
        ),
        StudentPhysicalDisabilityCategory(
          title: 'Hypoxic/Anoxic Brain Injury',
          details: [],
        ),
        StudentPhysicalDisabilityCategory(title: 'Stroke', details: []),
      ];
  static const List<StudentPhysicalDisabilityCategory>
  neurodevelopmentalCategories = [
    StudentPhysicalDisabilityCategory(
      title: 'Specific Learning Disabilities',
      description: 'Difficulties with specific academic skills, such as',
      details: [
        'Dyslexia (reading)',
        'Dyscalculia (math)',
        'Dysgraphia (writing)',
      ],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Autism Spectrum Disorder (ASD)',
      details: [],
    ),
    StudentPhysicalDisabilityCategory(title: 'ADHD', details: []),
    StudentPhysicalDisabilityCategory(
      title: 'Foetal alcohol spectrum disorders',
      details: [],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Developmental language disorder',
      details: [],
    ),
  ];
  static const List<StudentPhysicalDisabilityCategory> psychiatricCategories = [
    StudentPhysicalDisabilityCategory(
      title: 'Mood Disorders',
      details: ['Major Depressive Disorder', 'Bipolar Disorder.'],
    ),
    StudentPhysicalDisabilityCategory(
      title: 'Anxiety Disorders',
      details: [
        'Severe anxiety',
        'Panic Disorder',
        'Obsessive-Compulsive Disorder (OCD)',
        'Post-Traumatic Stress Disorder (PTSD)',
      ],
    ),
  ];
  static const List<StudentPhysicalDisabilityCategory>
  chronicIllnessCategories = [
    StudentPhysicalDisabilityCategory(
      title: 'Respiratory and Cardiovascular Conditions',
      description: 'Severe',
      details: ['Asthma'],
    ),
  ];

  bool physicalMobilityDisabilities = false;
  bool sensoryDisabilities = false;
  bool intellectualCognitiveDisabilities = false;
  bool neurodevelopmentalLearningDisabilities = false;
  bool psychiatricMentalHealthDisabilities = false;
  bool chronicIllnessesInvisibleDisabilities = false;
  final Set<String> selectedCategories = {};
  final Map<String, Set<String>> selectedDetails = {};

  bool get isSelected =>
      physicalMobilityDisabilities ||
      sensoryDisabilities ||
      intellectualCognitiveDisabilities ||
      neurodevelopmentalLearningDisabilities ||
      psychiatricMentalHealthDisabilities ||
      chronicIllnessesInvisibleDisabilities;

  Map<String, dynamic> toDraft() => {
    'physicalMobilityDisabilities': physicalMobilityDisabilities,
    'sensoryDisabilities': sensoryDisabilities,
    'intellectualCognitiveDisabilities': intellectualCognitiveDisabilities,
    'neurodevelopmentalLearningDisabilities':
        neurodevelopmentalLearningDisabilities,
    'psychiatricMentalHealthDisabilities': psychiatricMentalHealthDisabilities,
    'chronicIllnessesInvisibleDisabilities':
        chronicIllnessesInvisibleDisabilities,
    'selectedCategories': selectedCategories.toList(),
    'selectedDetails': selectedDetails.map(
      (key, value) => MapEntry(key, value.toList()),
    ),
  };

  void hydrateFromDraft(Map<String, dynamic> j) {
    physicalMobilityDisabilities =
        j['physicalMobilityDisabilities'] == true ||
        j['physical_mobility_disabilities'] == true;
    sensoryDisabilities =
        j['sensoryDisabilities'] == true || j['sensory_disabilities'] == true;
    intellectualCognitiveDisabilities =
        j['intellectualCognitiveDisabilities'] == true ||
        j['intellectual_cognitive_disabilities'] == true;
    neurodevelopmentalLearningDisabilities =
        j['neurodevelopmentalLearningDisabilities'] == true ||
        j['neurodevelopmental_learning_disabilities'] == true;
    psychiatricMentalHealthDisabilities =
        j['psychiatricMentalHealthDisabilities'] == true ||
        j['psychiatric_mental_health_disabilities'] == true;
    chronicIllnessesInvisibleDisabilities =
        j['chronicIllnessesInvisibleDisabilities'] == true ||
        j['chronic_illnesses_invisible_disabilities'] == true;
    selectedCategories
      ..clear()
      ..addAll(((j['selectedCategories'] as List?) ?? []).map((e) => '$e'));
    selectedDetails
      ..clear()
      ..addAll(
        ((j['selectedDetails'] as Map?) ?? {}).map(
          (key, value) => MapEntry(
            '$key',
            ((value as List?) ?? []).map((e) => '$e').toSet(),
          ),
        ),
      );
  }

  void hydrateFromApi(dynamic value) {
    final rows = switch (value) {
      List() => value,
      String() => _tryDecodeList(value),
      _ => const [],
    };
    if (rows.isEmpty) return;
    final flattened = rows
        .whereType<Map>()
        .map((item) => item.values.join(' '))
        .join(' ')
        .toLowerCase();
    physicalMobilityDisabilities =
        flattened.contains(optionTitle.toLowerCase()) ||
        flattened.contains('mobility disability') ||
        flattened.contains('spinal cord injuries');
    sensoryDisabilities =
        flattened.contains(sensoryOptionTitle.toLowerCase()) ||
        flattened.contains('visual differences') ||
        flattened.contains('hearing loss') ||
        flattened.contains('sensory processing differences');
    intellectualCognitiveDisabilities =
        flattened.contains(intellectualOptionTitle.toLowerCase()) ||
        flattened.contains('mild intellectual disability') ||
        flattened.contains('traumatic brain injuries') ||
        flattened.contains('hypoxic/anoxic brain injury') ||
        flattened.contains('stroke');
    neurodevelopmentalLearningDisabilities =
        flattened.contains(neurodevelopmentalOptionTitle.toLowerCase()) ||
        flattened.contains('specific learning disabilities') ||
        flattened.contains('autism spectrum disorder') ||
        flattened.contains('adhd') ||
        flattened.contains('foetal alcohol spectrum disorders') ||
        flattened.contains('developmental language disorder');
    psychiatricMentalHealthDisabilities =
        flattened.contains(psychiatricOptionTitle.toLowerCase()) ||
        flattened.contains('mood disorders') ||
        flattened.contains('major depressive disorder') ||
        flattened.contains('bipolar disorder') ||
        flattened.contains('anxiety disorders') ||
        flattened.contains('obsessive-compulsive disorder') ||
        flattened.contains('post-traumatic stress disorder');
    chronicIllnessesInvisibleDisabilities =
        flattened.contains(chronicIllnessOptionTitle.toLowerCase()) ||
        flattened.contains('respiratory and cardiovascular conditions') ||
        flattened.contains('asthma');
    if (!isSelected) return;
    for (final category in [
      ...categories,
      ...sensoryCategories,
      ...intellectualCategories,
      ...neurodevelopmentalCategories,
      ...psychiatricCategories,
      ...chronicIllnessCategories,
    ]) {
      if (flattened.contains(category.title.toLowerCase())) {
        selectedCategories.add(category.title);
      }
      for (final detail in category.details) {
        if (flattened.contains(detail.toLowerCase())) {
          selectedCategories.add(category.title);
          selectedDetails
              .putIfAbsent(category.title, () => <String>{})
              .add(detail);
        }
      }
    }
  }

  List<dynamic> _tryDecodeList(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> toJson() {
    if (!isSelected) return const [];
    return [
      {'other_condition': _serializedSummary()},
    ];
  }

  List<String> reviewReasons() {
    if (!isSelected) return const [];
    final parts = <String>[
      if (physicalMobilityDisabilities) optionTitle,
      if (sensoryDisabilities) sensoryOptionTitle,
      if (intellectualCognitiveDisabilities) intellectualOptionTitle,
      if (neurodevelopmentalLearningDisabilities) neurodevelopmentalOptionTitle,
      if (psychiatricMentalHealthDisabilities) psychiatricOptionTitle,
      if (chronicIllnessesInvisibleDisabilities) chronicIllnessOptionTitle,
    ];
    for (final category in [
      ...categories,
      ...sensoryCategories,
      ...intellectualCategories,
      ...neurodevelopmentalCategories,
      ...psychiatricCategories,
      ...chronicIllnessCategories,
    ]) {
      if (!selectedCategories.contains(category.title)) continue;
      final details = selectedDetails[category.title] ?? const <String>{};
      parts.add(
        details.isEmpty
            ? category.title
            : '${category.title}: ${details.join('; ')}',
      );
    }
    return parts;
  }

  String _serializedSummary() => reviewReasons().join(' | ');

  void setMainSelected(bool value) {
    setMainOptionSelected(optionTitle, value);
  }

  bool isMainOptionSelected(String title) => switch (title) {
    optionTitle => physicalMobilityDisabilities,
    sensoryOptionTitle => sensoryDisabilities,
    intellectualOptionTitle => intellectualCognitiveDisabilities,
    neurodevelopmentalOptionTitle => neurodevelopmentalLearningDisabilities,
    psychiatricOptionTitle => psychiatricMentalHealthDisabilities,
    chronicIllnessOptionTitle => chronicIllnessesInvisibleDisabilities,
    _ => false,
  };

  void setMainOptionSelected(String title, bool value) {
    switch (title) {
      case optionTitle:
        physicalMobilityDisabilities = value;
      case sensoryOptionTitle:
        sensoryDisabilities = value;
      case intellectualOptionTitle:
        intellectualCognitiveDisabilities = value;
      case neurodevelopmentalOptionTitle:
        neurodevelopmentalLearningDisabilities = value;
      case psychiatricOptionTitle:
        psychiatricMentalHealthDisabilities = value;
      case chronicIllnessOptionTitle:
        chronicIllnessesInvisibleDisabilities = value;
    }
    if (!value) {
      for (final category in categoriesFor(title)) {
        selectedCategories.remove(category.title);
        selectedDetails.remove(category.title);
      }
    }
  }

  List<StudentPhysicalDisabilityCategory> categoriesFor(String title) {
    return switch (title) {
      optionTitle => categories,
      sensoryOptionTitle => sensoryCategories,
      intellectualOptionTitle => intellectualCategories,
      neurodevelopmentalOptionTitle => neurodevelopmentalCategories,
      psychiatricOptionTitle => psychiatricCategories,
      chronicIllnessOptionTitle => chronicIllnessCategories,
      _ => const [],
    };
  }

  bool isCategorySelected(String title) => selectedCategories.contains(title);

  void setCategorySelected(String title, bool value) {
    if (value) {
      selectedCategories.add(title);
    } else {
      selectedCategories.remove(title);
      selectedDetails.remove(title);
    }
  }

  bool isDetailSelected(String categoryTitle, String detail) =>
      selectedDetails[categoryTitle]?.contains(detail) ?? false;

  void setDetailSelected(String categoryTitle, String detail, bool value) {
    final details = selectedDetails.putIfAbsent(
      categoryTitle,
      () => <String>{},
    );
    if (value) {
      selectedCategories.add(categoryTitle);
      details.add(detail);
    } else {
      details.remove(detail);
      if (details.isEmpty) selectedDetails.remove(categoryTitle);
    }
  }
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

  final StudentPhysicalDisabilitySelection physicalDisability =
      StudentPhysicalDisabilitySelection();

  // Step 2 — Place of Birth + Current Address
  String villageBirth = '';
  String districtBirth = '';
  String provinceBirth = '';
  String village = '';
  String district = '';
  String province = '';
  // Location relations (resolved against /locations) — strings above are kept
  // for the Place-of-Birth free-text fields but Current Address goes through
  // UUIDs so the backend records the relation.
  String districtId = '';
  String provinceId = '';
  String districtName = '';
  String provinceName = '';

  // Step 3 — Education history (fixed 2 rows)
  final SchoolHistoryEntry kindergarten = SchoolHistoryEntry();
  final SchoolHistoryEntry primary = SchoolHistoryEntry();

  // Step 4 — Siblings (dynamic)
  final List<SiblingEntry> siblings = [];

  // Step 5 — Living with (dynamic)
  final List<LiveWithEntry> livingWith = [];

  // Step 6 — Emergency contacts (dynamic, like siblings)
  final List<EmergencyContactEntry> emergencyContacts = [
    EmergencyContactEntry(),
  ];

  Map<String, dynamic> toDraft() => {
    'firstNameLao': firstNameLao,
    'firstNameEng': firstNameEng,
    'middleNameLao': middleNameLao,
    'middleNameEng': middleNameEng,
    'lastNameLao': lastNameLao,
    'lastNameEng': lastNameEng,
    'nickname': nickname,
    'dob': dob,
    'gender': gender,
    'nationality': nationality,
    'ethnicity': ethnicity,
    'religion': religion,
    'passportNo': passportNo,
    'physicalDisability': physicalDisability.toDraft(),
    'villageBirth': villageBirth,
    'districtBirth': districtBirth,
    'provinceBirth': provinceBirth,
    'village': village,
    'district': district,
    'province': province,
    'districtId': districtId,
    'provinceId': provinceId,
    'districtName': districtName,
    'provinceName': provinceName,
    'kindergarten': kindergarten.toDraft(),
    'primary': primary.toDraft(),
    'siblings': siblings.map((e) => e.toDraft()).toList(),
    'livingWith': livingWith.map((e) => e.toDraft()).toList(),
    'emergencyContacts': emergencyContacts.map((e) => e.toDraft()).toList(),
  };

  void hydrateFromDraft(Map<String, dynamic> j) {
    firstNameLao = (j['firstNameLao'] ?? '').toString();
    firstNameEng = (j['firstNameEng'] ?? '').toString();
    middleNameLao = (j['middleNameLao'] ?? '').toString();
    middleNameEng = (j['middleNameEng'] ?? '').toString();
    lastNameLao = (j['lastNameLao'] ?? '').toString();
    lastNameEng = (j['lastNameEng'] ?? '').toString();
    nickname = (j['nickname'] ?? '').toString();
    dob = (j['dob'] ?? '').toString();
    gender = (j['gender'] ?? '').toString();
    nationality = (j['nationality'] ?? '').toString();
    ethnicity = (j['ethnicity'] ?? '').toString();
    religion = (j['religion'] ?? '').toString();
    passportNo = (j['passportNo'] ?? '').toString();
    if (j['physicalDisability'] is Map) {
      physicalDisability.hydrateFromDraft(
        Map<String, dynamic>.from(j['physicalDisability'] as Map),
      );
    }
    villageBirth = (j['villageBirth'] ?? '').toString();
    districtBirth = (j['districtBirth'] ?? '').toString();
    provinceBirth = (j['provinceBirth'] ?? '').toString();
    village = (j['village'] ?? '').toString();
    district = (j['district'] ?? '').toString();
    province = (j['province'] ?? '').toString();
    districtId = (j['districtId'] ?? '').toString();
    provinceId = (j['provinceId'] ?? '').toString();
    districtName = (j['districtName'] ?? '').toString();
    provinceName = (j['provinceName'] ?? '').toString();
    if (j['kindergarten'] is Map) {
      kindergarten.fillFromDraft(
        Map<String, dynamic>.from(j['kindergarten'] as Map),
      );
    }
    if (j['primary'] is Map) {
      primary.fillFromDraft(Map<String, dynamic>.from(j['primary'] as Map));
    }
    siblings
      ..clear()
      ..addAll(
        ((j['siblings'] as List?) ?? []).whereType<Map>().map(
          (m) => SiblingEntry.fromDraft(Map<String, dynamic>.from(m)),
        ),
      );
    livingWith
      ..clear()
      ..addAll(
        ((j['livingWith'] as List?) ?? []).whereType<Map>().map(
          (m) => LiveWithEntry.fromDraft(Map<String, dynamic>.from(m)),
        ),
      );
    emergencyContacts
      ..clear()
      ..addAll(
        ((j['emergencyContacts'] as List?) ?? []).whereType<Map>().map(
          (m) => EmergencyContactEntry.fromDraft(Map<String, dynamic>.from(m)),
        ),
      );
    if (emergencyContacts.isEmpty) {
      emergencyContacts.add(EmergencyContactEntry());
    }
  }
}

/// Persists in-progress / submitted student forms to SharedPreferences so a
/// rejection from admin doesn't force the parent to re-fill from scratch.
/// Drafts live under a per-student key and are cleared once that student
/// reaches the approved state.
class StudentDraftStore {
  static const String _prefix = 'student_draft_';

  static String _key(String studentId) => '$_prefix${studentId.trim()}';

  static Future<void> save(String studentId, StudentSubmission s) async {
    if (studentId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(studentId), jsonEncode(s.toDraft()));
  }

  static Future<StudentSubmission?> load(String studentId) async {
    if (studentId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(studentId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final s = StudentSubmission();
      s.hydrateFromDraft(map);
      return s;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String studentId) async {
    if (studentId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(studentId));
  }
}

/// Stores only household details that can safely be re-used when a parent
/// registers another child. Student identity and education history are never
/// included in this record.
class StudentReusableDetailsStore {
  static const _key = 'student_reusable_details_v1';

  static Future<void> save(StudentSubmission submission) async {
    final details = <String, dynamic>{
      'nationality': submission.nationality.trim(),
      'ethnicity': submission.ethnicity.trim(),
      'religion': submission.religion.trim(),
      'village': submission.village.trim(),
      'district': submission.district.trim(),
      'province': submission.province.trim(),
      'districtId': submission.districtId.trim(),
      'provinceId': submission.provinceId.trim(),
      'districtName': submission.districtName.trim(),
      'provinceName': submission.provinceName.trim(),
      'livingWith': submission.livingWith
          .map((entry) => entry.toDraft())
          .toList(),
      'emergencyContacts': submission.emergencyContacts
          .map((entry) => entry.toDraft())
          .toList(),
    };
    final hasReusableValue = details.entries.any((entry) {
      final value = entry.value;
      return value is String
          ? value.isNotEmpty
          : value is List && value.isNotEmpty;
    });
    if (!hasReusableValue) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(details));
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}

/// A pre-existing student the backend flagged as a likely duplicate of the
/// one being submitted (same parent, matching name + date of birth).
class DuplicateStudentMatch {
  final String id;
  final String name;
  final String dob;

  const DuplicateStudentMatch({
    required this.id,
    required this.name,
    required this.dob,
  });

  factory DuplicateStudentMatch.fromJson(Map<String, dynamic> json) {
    return DuplicateStudentMatch(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      dob: (json['dob'] ?? '').toString(),
    );
  }
}

/// Thrown when the backend rejects a student submission (409) because a
/// matching student already exists under the same parent. Callers should
/// confirm with the parent, then retry `register(... confirmDuplicate: true)`.
class StudentDuplicateException extends ApiException {
  final List<DuplicateStudentMatch> matches;

  StudentDuplicateException(String message, {required this.matches})
    : super(message, statusCode: 409);
}

class StudentRegistrationService {
  StudentRegistrationService({ApiClient? client})
    : _api = client ?? ApiClient(timeout: const Duration(seconds: 60));
  final ApiClient _api;

  /// Storage key shared with the parent registration form; the parent picks
  /// a branch in that screen and we persist it here for the student POST.
  static const String _kSelectedBranchIdKey = 'selected_branch_id';

  Future<String?> _resolveBranchId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kSelectedBranchIdKey);
      if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    } catch (_) {}
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

  void _addSpecialReviewFields(
    Map<String, dynamic> body,
    StudentSubmission s,
  ) {
    final reasons = s.physicalDisability.reviewReasons();
    body['physical_disability'] = s.physicalDisability.isSelected
        ? s.physicalDisability.toJson()
        : <Map<String, dynamic>>[];
    body['health_review_required'] = reasons.isNotEmpty;
    body['health_review_reasons'] = reasons;
  }

  Future<Map<String, dynamic>> register({
    required StudentSubmission s,
    required String parentId,
    bool confirmDuplicate = false,
  }) async {
    final branchId = await _resolveBranchId();
    if (branchId == null) {
      throw const ApiException('No school branch found. Please contact admin.');
    }

    final body = <String, dynamic>{
      'branchId': branchId,
      'student_id': _generateStudentId(),
      'confirmDuplicate': confirmDuplicate,
      if (s.firstNameLao.trim().isNotEmpty)
        'first_name_lao': s.firstNameLao.trim(),
      if (s.firstNameEng.trim().isNotEmpty)
        'first_name_eng': s.firstNameEng.trim(),
      if (s.middleNameLao.trim().isNotEmpty)
        'midle_name_lao': s.middleNameLao.trim(),
      if (s.middleNameEng.trim().isNotEmpty)
        'midle_name_eng': s.middleNameEng.trim(),
      if (s.lastNameLao.trim().isNotEmpty)
        'last_name_lao': s.lastNameLao.trim(),
      if (s.lastNameEng.trim().isNotEmpty)
        'last_name_eng': s.lastNameEng.trim(),
      if (s.nickname.trim().isNotEmpty) 'nickname': s.nickname.trim(),
      'dob': s.dob.trim(),
      'gender': s.gender.trim().isEmpty ? 'unspecified' : s.gender.trim(),
      if (s.nationality.trim().isNotEmpty) 'nationality': s.nationality.trim(),
      if (s.ethnicity.trim().isNotEmpty) 'ethnicity': s.ethnicity.trim(),
      if (s.religion.trim().isNotEmpty) 'religion': s.religion.trim(),
      if (s.passportNo.trim().isNotEmpty)
        'passport_number': s.passportNo.trim(),
      if (s.village.trim().isNotEmpty) 'village': s.village.trim(),
      if (s.districtId.trim().isNotEmpty) 'districtId': s.districtId.trim(),
      if (s.provinceId.trim().isNotEmpty) 'provinceId': s.provinceId.trim(),
      if (s.villageBirth.trim().isNotEmpty) 'village_bd': s.villageBirth.trim(),
      if (s.districtBirth.trim().isNotEmpty ||
          s.provinceBirth.trim().isNotEmpty)
        'dm_birth': [
          s.villageBirth,
          s.districtBirth,
          s.provinceBirth,
        ].where((e) => e.trim().isNotEmpty).join(', '),
      if (s.siblings.isNotEmpty)
        'bos_info': s.siblings
            .where((e) => e.fullname.trim().isNotEmpty)
            .map((e) => e.toJson())
            .toList(),
      if (s.livingWith.isNotEmpty)
        'live_with': s.livingWith.map((e) => e.toJson()).toList(),
      if (s.emergencyContacts.any((e) => e.fullname.trim().isNotEmpty))
        'emergency_contacts': s.emergencyContacts
            .where((e) => e.fullname.trim().isNotEmpty)
            .map((e) => e.toJson())
            .toList(),
      if (!s.kindergarten.isEmpty)
        'his_school_kindergarten': [s.kindergarten.toJson()],
      if (!s.primary.isEmpty) 'his_school_primary': [s.primary.toJson()],
      'parentIds': [parentId],
    };
    _addSpecialReviewFields(body, s);

    try {
      final res = await _api.post('/students', body: body);
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'data': res};
    } on ApiException catch (e) {
      final duplicate = _asDuplicateException(e);
      if (duplicate != null) throw duplicate;
      rethrow;
    }
  }

  /// Recognizes the createStudent() 409 shape ({ possibleDuplicates: [...] })
  /// and converts it into a typed exception; returns null for any other error
  /// so the original ApiException keeps propagating unchanged.
  StudentDuplicateException? _asDuplicateException(ApiException e) {
    if (e.statusCode != 409) return null;
    final body = e.body;
    final rawMatches = body is Map ? body['possibleDuplicates'] : null;
    if (rawMatches is! List || rawMatches.isEmpty) return null;
    final matches = rawMatches
        .whereType<Map>()
        .map(
          (m) => DuplicateStudentMatch.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList();
    if (matches.isEmpty) return null;
    return StudentDuplicateException(e.message, matches: matches);
  }

  /// Re-send a previously rejected application. Clears the approval/reject
  /// flags so admin can review the updated submission.
  Future<Map<String, dynamic>> resubmit({
    required String studentId,
    required StudentSubmission s,
  }) async {
    final body = await _buildBody(s, includeParentIds: null);
    body['approval_status'] = 'pending';
    body['approvalStatus'] = 'pending';
    body['reject_reason'] = '';
    body['rejectReason'] = '';
    body['rejection_reason'] = '';
    body['is_active'] = false;
    body['isActive'] = false;
    final res = await _api.put('/students/$studentId', body: body);
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'data': res};
  }

  /// Same body shape register() builds — extracted for re-use by resubmit().
  Future<Map<String, dynamic>> _buildBody(
    StudentSubmission s, {
    required String? includeParentIds,
  }) async {
    final branchId = await _resolveBranchId();
    final body = <String, dynamic>{
      if (branchId != null) 'branchId': branchId,
      if (s.firstNameLao.trim().isNotEmpty)
        'first_name_lao': s.firstNameLao.trim(),
      if (s.firstNameEng.trim().isNotEmpty)
        'first_name_eng': s.firstNameEng.trim(),
      if (s.middleNameLao.trim().isNotEmpty)
        'midle_name_lao': s.middleNameLao.trim(),
      if (s.middleNameEng.trim().isNotEmpty)
        'midle_name_eng': s.middleNameEng.trim(),
      if (s.lastNameLao.trim().isNotEmpty)
        'last_name_lao': s.lastNameLao.trim(),
      if (s.lastNameEng.trim().isNotEmpty)
        'last_name_eng': s.lastNameEng.trim(),
      if (s.nickname.trim().isNotEmpty) 'nickname': s.nickname.trim(),
      'dob': s.dob.trim(),
      'gender': s.gender.trim().isEmpty ? 'unspecified' : s.gender.trim(),
      if (s.nationality.trim().isNotEmpty) 'nationality': s.nationality.trim(),
      if (s.ethnicity.trim().isNotEmpty) 'ethnicity': s.ethnicity.trim(),
      if (s.religion.trim().isNotEmpty) 'religion': s.religion.trim(),
      if (s.passportNo.trim().isNotEmpty)
        'passport_number': s.passportNo.trim(),
      if (s.village.trim().isNotEmpty) 'village': s.village.trim(),
      if (s.districtId.trim().isNotEmpty) 'districtId': s.districtId.trim(),
      if (s.provinceId.trim().isNotEmpty) 'provinceId': s.provinceId.trim(),
      if (s.villageBirth.trim().isNotEmpty) 'village_bd': s.villageBirth.trim(),
      if (s.districtBirth.trim().isNotEmpty ||
          s.provinceBirth.trim().isNotEmpty)
        'dm_birth': [
          s.villageBirth,
          s.districtBirth,
          s.provinceBirth,
        ].where((e) => e.trim().isNotEmpty).join(', '),
      if (s.siblings.isNotEmpty)
        'bos_info': s.siblings
            .where((e) => e.fullname.trim().isNotEmpty)
            .map((e) => e.toJson())
            .toList(),
      if (s.livingWith.isNotEmpty)
        'live_with': s.livingWith.map((e) => e.toJson()).toList(),
      if (s.emergencyContacts.any((e) => e.fullname.trim().isNotEmpty))
        'emergency_contacts': s.emergencyContacts
            .where((e) => e.fullname.trim().isNotEmpty)
            .map((e) => e.toJson())
            .toList(),
      if (!s.kindergarten.isEmpty)
        'his_school_kindergarten': [s.kindergarten.toJson()],
      if (!s.primary.isEmpty) 'his_school_primary': [s.primary.toJson()],
      if (includeParentIds != null) 'parentIds': [includeParentIds],
    };
    _addSpecialReviewFields(body, s);
    return body;
  }
}

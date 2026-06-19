import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/models/student_card_item.dart';

class StudentService {
  StudentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Fetches every student linked to the given parent.
  ///
  /// There is no dedicated "students by parent" endpoint, so this loads
  /// `GET /students` (which embeds each student's `parents` relation) and
  /// matches client-side wherever `parents[].id == parentId`.
  Future<List<StudentCardItem>> fetchStudentsForParent(String parentId) async {
    final responses = await Future.wait([
      _apiClient.get('/students'),
      _apiClient.get('/classes'),
    ]);
    final studentRecords = _extractRecords(responses[0], 'students');
    final classNamesById = _classNamesById(
      _extractRecords(responses[1], 'classes'),
    );

    final items = <StudentCardItem>[];
    for (final record in studentRecords) {
      if (!_isActive(record)) continue;
      if (record['is_deleted'] == true) continue;
      if (!_linkedToParent(record, parentId)) continue;

      items.add(_toCardItem(record, classNamesById));
    }

    return items;
  }

  bool _linkedToParent(Map<String, dynamic> record, String parentId) {
    final parents = record['parents'];
    if (parents is! List) return false;

    return parents.any(
      (parent) =>
          parent is Map<String, dynamic> &&
          parent['id']?.toString() == parentId,
    );
  }

  StudentCardItem _toCardItem(
    Map<String, dynamic> record,
    Map<String, String> classNamesById,
  ) {
    final studentId = _readString(record, const ['student_id']);
    final firstName = _readString(record, const [
      'first_name_lao',
      'firstNameLao',
      'first_name',
      'first_name_eng',
      'firstNameEng',
    ]);
    final lastName = _readString(record, const [
      'last_name_lao',
      'lastNameLao',
      'last_name',
      'last_name_eng',
      'lastNameEng',
    ]);
    final classId = _readStudentClassId(record);
    final name = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');

    return StudentCardItem(
      id: _readString(record, const ['id']),
      studentId: studentId,
      name: name.isEmpty ? studentId : name,
      photoUrl: _photoUrl(_readString(record, const ['profile_image_path'])),
      className: classNamesById[classId],
      branchId: _readStudentBranchId(record),
      classId: classId.isEmpty ? null : classId,
    );
  }

  Map<String, String> _classNamesById(List<Map<String, dynamic>> classRecords) {
    final result = <String, String>{};

    for (final record in classRecords) {
      final id = _readString(record, const ['id', 'class_id', 'classId']);
      final name = _readString(record, const [
        'name',
        'class_name',
        'className',
        'title',
      ]);
      if (id.isNotEmpty && name.isNotEmpty) {
        result[id] = name;
      }
    }

    return result;
  }

  String _readStudentBranchId(Map<String, dynamic> record) {
    final direct = _readString(record, const ['branchId', 'branch_id']);
    if (direct.isNotEmpty) return direct;

    final enrollments = record['enrollments'];
    if (enrollments is! List) return '';

    Map<String, dynamic>? fallback;
    for (final enrollment in enrollments.whereType<Map<String, dynamic>>()) {
      fallback ??= enrollment;
      if (_isActive(enrollment)) {
        return _readString(enrollment, const ['branchId', 'branch_id']);
      }
    }
    return fallback == null
        ? ''
        : _readString(fallback, const ['branchId', 'branch_id']);
  }

  String _readStudentClassId(Map<String, dynamic> record) {
    final directId = _readString(record, const ['class_id', 'classId']);
    if (directId.isNotEmpty) return directId;

    final enrollments = record['enrollments'];
    if (enrollments is! List) return '';

    Map<String, dynamic>? fallback;
    for (final enrollment in enrollments.whereType<Map<String, dynamic>>()) {
      fallback ??= enrollment;
      if (_isActive(enrollment)) {
        return _readString(enrollment, const ['classId', 'class_id']);
      }
    }

    return fallback == null
        ? ''
        : _readString(fallback, const ['classId', 'class_id']);
  }

  /// Static uploads are served from the API host root (e.g.
  /// `http://host:port/uploads/...`), not under the `/api/v2` prefix that
  /// `ApiConfig.baseUrl` (and therefore `ApiClient`) resolves relative paths
  /// against — so the host has to be reused with a fresh root-relative path.
  String? _photoUrl(String relativePath) {
    if (relativePath.isEmpty) return null;

    final base = Uri.parse(ApiConfig.baseUrl);
    final cleanPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return base.replace(path: '/$cleanPath').toString();
  }

  /// Same defensive shape-handling as other feature services: the backend
  /// may answer with a bare array, `{data: [...]}`, `{results: [...]}`, or
  /// `{students: [...]}`.
  List<Map<String, dynamic>> _extractRecords(
    dynamic response,
    String resourceKey,
  ) {
    List<dynamic> rawList = const [];

    if (response is List<dynamic>) {
      rawList = response;
    } else if (response is Map<String, dynamic>) {
      final byResource = response[resourceKey];
      final data = response['data'];
      final results = response['results'];
      if (byResource is List<dynamic>) {
        rawList = byResource;
      } else if (data is List<dynamic>) {
        rawList = data;
      } else if (results is List<dynamic>) {
        rawList = results;
      }
    }

    return rawList.whereType<Map<String, dynamic>>().toList();
  }

  /// Mirrors `AuthService._isActive`: missing/null counts as active.
  bool _isActive(Map<String, dynamic> json) {
    final value = json['is_active'] ?? json['isActive'];
    return value != false;
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value.toString().trim();
    }
    return '';
  }
}

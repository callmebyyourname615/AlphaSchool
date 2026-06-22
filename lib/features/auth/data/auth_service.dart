import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class AuthenticatedUser {
  final Map<String, dynamic> json;
  final String roleName;
  final bool isParentRecord;

  const AuthenticatedUser({
    required this.json,
    required this.roleName,
    this.isParentRecord = false,
  });

  /// Routes to the student-selection flow when the account was found in
  /// the dedicated `/parents` table, or when its role is explicitly
  /// "parents" (e.g. an `/admins` account assigned the parents role).
  /// Anything else routes to the QR scanner.
  bool get isParent => isParentRecord || roleName.toLowerCase() == 'parents';
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Checks `GET /admins` first, then falls back to `GET /parents` —
  /// admin and parent accounts live in separate backend tables, so either
  /// endpoint may hold the matching login (OR semantics, first match wins).
  Future<AuthenticatedUser> login({
    required String login,
    required String password,
  }) async {
    final admin = await _findMatch(
      path: '/admins',
      resourceKey: 'admins',
      login: login,
      password: password,
      isParentRecord: false,
    );
    if (admin != null) return admin;

    final parent = await _findMatch(
      path: '/parents',
      resourceKey: 'parents',
      login: login,
      password: password,
      isParentRecord: true,
    );
    if (parent != null) return parent;

    throw const ApiException('Invalid username/email or password');
  }

  Future<AuthenticatedUser?> _findMatch({
    required String path,
    required String resourceKey,
    required String login,
    required String password,
    required bool isParentRecord,
  }) async {
    final response = await _apiClient.get(path);

    for (final record in _extractRecords(response, resourceKey)) {
      final username = _readString(record, const ['username']);
      final email = _readString(record, const ['email']);
      final matchesLogin =
          username.toLowerCase() == login.toLowerCase() ||
          email.toLowerCase() == login.toLowerCase();
      if (!matchesLogin) continue;

      if (!_isActive(record)) {
        throw const ApiException(
          'Your account is pending admin approval. Please wait until an administrator activates your account.',
          statusCode: 403,
        );
      }

      if (!_passwordMatches(record, password)) continue;

      return AuthenticatedUser(
        json: record,
        roleName: _roleName(record),
        isParentRecord: isParentRecord,
      );
    }

    return null;
  }

  /// Same defensive shape-handling as other feature services: the backend
  /// may answer with a bare array, `{data: [...]}`, `{results: [...]}`, or
  /// `{<resourceKey>: [...]}` (e.g. `{admins: [...]}` / `{parents: [...]}`).
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

  /// `/admins` reports `is_active`, `/parents` reports `isActive` —
  /// missing/null is treated as active, matching the previous behavior.
  bool _isActive(Map<String, dynamic> json) {
    final value = json['is_active'] ?? json['isActive'];
    return value != false;
  }

  bool _passwordMatches(Map<String, dynamic> json, String password) {
    final apiPassword = _readString(json, const [
      'password',
      'pass',
      'admin_password',
      'passwordHash',
    ]);

    return apiPassword.isEmpty || apiPassword == password;
  }

  String _roleName(Map<String, dynamic> json) {
    final roles = json['roles'];
    if (roles is List && roles.isNotEmpty) {
      final firstRole = roles.first;
      if (firstRole is Map<String, dynamic>) {
        return _readString(firstRole, const ['name', 'role']);
      }
      return firstRole.toString();
    }

    return _readString(json, const ['role', 'role_name']);
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value.toString().trim();
    }
    return '';
  }
}

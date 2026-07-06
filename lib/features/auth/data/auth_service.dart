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

  /// Login must go through the backend auth endpoints so password validation
  /// happens against the stored bcrypt hash. Do not fall back to listing users:
  /// those endpoints intentionally omit password hashes.
  Future<AuthenticatedUser> login({
    required String login,
    required String password,
  }) async {
    final email = login.trim().toLowerCase();

    try {
      return await _loginWithEndpoint(
        path: '/auth/parent/login',
        email: email,
        password: password,
        isParentRecord: true,
      );
    } on ApiException catch (parentError) {
      if (parentError.statusCode == 403) rethrow;

      try {
        return await _loginWithEndpoint(
          path: '/auth/login',
          email: email,
          password: password,
          isParentRecord: false,
        );
      } on ApiException catch (adminError) {
        if (adminError.statusCode == 403) rethrow;
        throw const ApiException('Invalid email or password');
      }
    }
  }

  Future<AuthenticatedUser> _loginWithEndpoint({
    required String path,
    required String email,
    required String password,
    required bool isParentRecord,
  }) async {
    final response = await _apiClient.post(
      path,
      body: {'email': email, 'password': password},
    );
    final user = _userFromLoginResponse(response);
    return AuthenticatedUser(
      json: user,
      roleName: _roleName(user),
      isParentRecord: isParentRecord,
    );
  }

  Map<String, dynamic> _userFromLoginResponse(dynamic response) {
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Invalid login response from API');
    }

    final rawUser = response['user'];
    if (rawUser is! Map<String, dynamic>) {
      throw const ApiException('Invalid login response from API');
    }

    return {
      ...rawUser,
      'id': _readString(rawUser, const ['id', 'sub']),
      'access_token': response['access_token'],
    };
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

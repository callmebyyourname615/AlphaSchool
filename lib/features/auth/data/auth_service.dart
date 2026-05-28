import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class AuthenticatedAdmin {
  final Map<String, dynamic> json;
  final String roleName;

  const AuthenticatedAdmin({required this.json, required this.roleName});

  bool get isParent => roleName.toLowerCase() == 'parents';
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthenticatedAdmin> login({
    required String login,
    required String password,
  }) async {
    final response = await _apiClient.get('/admins');
    final admins = _extractAdmins(response);

    for (final admin in admins) {
      if (admin['is_active'] == false) continue;

      final username = _readString(admin, const ['username']);
      final email = _readString(admin, const ['email']);
      final matchesLogin =
          username.toLowerCase() == login.toLowerCase() ||
          email.toLowerCase() == login.toLowerCase();

      if (!matchesLogin) continue;
      if (!_passwordMatches(admin, password)) continue;

      return AuthenticatedAdmin(json: admin, roleName: _roleName(admin));
    }

    throw const ApiException('Invalid username/email or password');
  }

  List<Map<String, dynamic>> _extractAdmins(dynamic response) {
    final rawList = switch (response) {
      List<dynamic>() => response,
      {'data': final List<dynamic> data} => data,
      {'admins': final List<dynamic> admins} => admins,
      {'results': final List<dynamic> results} => results,
      _ => const <dynamic>[],
    };

    return rawList.whereType<Map<String, dynamic>>().toList();
  }

  bool _passwordMatches(Map<String, dynamic> admin, String password) {
    final apiPassword = _readString(admin, const [
      'password',
      'pass',
      'admin_password',
    ]);

    return apiPassword.isEmpty || apiPassword == password;
  }

  String _roleName(Map<String, dynamic> admin) {
    final roles = admin['roles'];
    if (roles is List && roles.isNotEmpty) {
      final firstRole = roles.first;
      if (firstRole is Map<String, dynamic>) {
        return _readString(firstRole, const ['name', 'role']);
      }
      return firstRole.toString();
    }

    return _readString(admin, const ['role', 'role_name']);
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value.toString().trim();
    }
    return '';
  }
}

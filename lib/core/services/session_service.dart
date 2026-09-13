import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _kId = 'session_admin_id';
  static const _kUsername = 'session_admin_username';
  static const _kEmail = 'session_admin_email';
  static const _kBranchId = 'session_branch_id';
  static const _kAccessToken = 'session_access_token';
  static const _kRoleName = 'session_role_name';

  Future<void> save(Map<String, dynamic> adminJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kId, adminJson['id']?.toString() ?? '');
    await prefs.setString(_kUsername, adminJson['username']?.toString() ?? '');
    await prefs.setString(_kEmail, adminJson['email']?.toString() ?? '');
    await prefs.setString(
      _kAccessToken,
      adminJson['access_token']?.toString() ?? '',
    );
    final branch = adminJson['branch'];
    final branchId =
        (adminJson['branch_id'] ??
                adminJson['branchId'] ??
                (branch is Map ? branch['id'] : null) ??
                '')
            .toString();
    await prefs.setString(_kBranchId, branchId);
    await prefs.setString(_kRoleName, _roleName(adminJson));
  }

  Future<SessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kId) ?? '';
    final username = prefs.getString(_kUsername) ?? '';
    final email = prefs.getString(_kEmail) ?? '';
    if (id.isEmpty && username.isEmpty && email.isEmpty) return null;
    return SessionData(
      id: id,
      username: username,
      email: email,
      branchId: prefs.getString(_kBranchId) ?? '',
      accessToken: prefs.getString(_kAccessToken) ?? '',
      roleName: prefs.getString(_kRoleName) ?? '',
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kId);
    await prefs.remove(_kUsername);
    await prefs.remove(_kEmail);
    await prefs.remove(_kBranchId);
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRoleName);
  }

  String _roleName(Map<String, dynamic> json) {
    final roles = json['roles'];
    if (roles is List && roles.isNotEmpty) {
      final firstRole = roles.first;
      if (firstRole is Map) {
        return (firstRole['name'] ?? firstRole['role'] ?? '').toString().trim();
      }
      return firstRole.toString().trim();
    }
    return (json['role_name'] ?? json['roleName'] ?? json['role'] ?? '')
        .toString()
        .trim();
  }
}

class SessionData {
  final String id;
  final String username;
  final String email;
  final String branchId;
  final String accessToken;
  final String roleName;

  const SessionData({
    required this.id,
    required this.username,
    required this.email,
    this.branchId = '',
    this.accessToken = '',
    this.roleName = '',
  });
}

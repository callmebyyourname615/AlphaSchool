import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _kId = 'session_admin_id';
  static const _kUsername = 'session_admin_username';
  static const _kEmail = 'session_admin_email';
  static const _kBranchId = 'session_branch_id';

  Future<void> save(Map<String, dynamic> adminJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kId, adminJson['id']?.toString() ?? '');
    await prefs.setString(_kUsername, adminJson['username']?.toString() ?? '');
    await prefs.setString(_kEmail, adminJson['email']?.toString() ?? '');
    final branch = adminJson['branch'];
    final branchId =
        (adminJson['branch_id'] ??
                adminJson['branchId'] ??
                (branch is Map ? branch['id'] : null) ??
                '')
            .toString();
    await prefs.setString(_kBranchId, branchId);
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
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kId);
    await prefs.remove(_kUsername);
    await prefs.remove(_kEmail);
    await prefs.remove(_kBranchId);
  }
}

class SessionData {
  final String id;
  final String username;
  final String email;
  final String branchId;

  const SessionData({
    required this.id,
    required this.username,
    required this.email,
    this.branchId = '',
  });
}

import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_config.dart';
import 'branch_model.dart';

class BranchService {
  BranchService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Returns the branch matching [branchId], or `null` if not found.
  Future<BranchInfo?> fetchBranch(String branchId) async {
    final code = branchId.trim();
    if (code.isEmpty) return null;

    final response = await _apiClient.get('/branches');
    final rows = _extractRows(response);

    for (final row in rows) {
      final id = row['id']?.toString().trim();
      if (id == code) return BranchInfo.fromJson(row);
    }
    return null;
  }

  /// Static uploads live at the host root (e.g. `/uploads/...`), not under the
  /// `/api/v2` prefix that `ApiConfig.baseUrl` resolves against.
  static String? resolveImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final base = Uri.parse(ApiConfig.baseUrl);
    final clean = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return base.replace(path: '/$clean').toString();
  }

  List<Map<String, dynamic>> _extractRows(dynamic response) {
    List<dynamic> raw = const [];
    if (response is List) {
      raw = response;
    } else if (response is Map<String, dynamic>) {
      for (final key in ['branches', 'data', 'results', 'items']) {
        final v = response[key];
        if (v is List) {
          raw = v;
          break;
        }
      }
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

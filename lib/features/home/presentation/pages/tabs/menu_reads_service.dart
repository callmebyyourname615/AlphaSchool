import 'dart:developer' as developer;

import '../../../../../core/network/api_client.dart';

/// Thin wrapper around `/menu-reads`. Read state for home-menu badges is
/// persisted server-side so it stays in sync across devices and survives
/// app reinstalls.
class MenuReadsService {
  MenuReadsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<String>> fetchReadIds({
    required String studentId,
    required String resource,
  }) async {
    try {
      final response = await _apiClient.get(
        '/menu-reads',
        queryParameters: {'studentId': studentId, 'resource': resource},
      );
      final data = response is Map<String, dynamic> ? response['data'] : null;
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (e) {
      developer.log('fetchReadIds failed: $e', name: 'menu_reads');
      return const [];
    }
  }

  Future<void> markRead({
    required String studentId,
    required String resource,
    required List<String> resourceIds,
  }) async {
    final ids = resourceIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    try {
      await _apiClient.post(
        '/menu-reads',
        body: {
          'studentId': studentId,
          'resource': resource,
          'resourceIds': ids,
        },
      );
    } catch (e) {
      developer.log('markRead failed: $e', name: 'menu_reads');
    }
  }
}

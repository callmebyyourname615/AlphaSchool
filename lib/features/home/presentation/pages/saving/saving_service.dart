import '../../../../../core/network/api_client.dart';
import 'saving_model.dart';

class SavingService {
  SavingService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<SavingData> fetch({required String studentId, String? classId}) async {
    final responses = await Future.wait([
      _api.get('/savings/student/$studentId/history'),
      _api.get('/savings/student/$studentId/balance'),
      if ((classId ?? '').isNotEmpty) _api.get('/savings'),
      if ((classId ?? '').isNotEmpty)
        _api.get('/savings/class/$classId/balance'),
      _api.get('/pay-receives'),
    ]);

    final personal = _records(responses[0]);
    final personalBalance = _balance(responses[1]);
    var classTransactions = <SavingTransaction>[];
    var classBalance = 0.0;
    if ((classId ?? '').isNotEmpty) {
      classTransactions = _records(
        responses[2],
      ).where((item) => _classId(item.$1) == classId).map((e) => e.$2).toList();
      classBalance = _balance(responses[3]);
    }

    // Build saving_id → (payReceiveId, status) so the UI can paint pending
    // withdrawals amber, link to the tracking page, and avoid showing them
    // as final-state deductions.
    final payReceives = _payReceives(responses.last);
    final lookup = <String, _PayReceiveInfo>{};
    for (final pr in payReceives) {
      final savingId = pr.savingId;
      if (savingId.isEmpty) continue;
      // Keep the latest update for each saving_id so a re-submitted record
      // overrides a stale earlier one.
      final existing = lookup[savingId];
      if (existing == null || pr.updatedAt.isAfter(existing.updatedAt)) {
        lookup[savingId] = pr;
      }
    }

    SavingTransaction attach(SavingTransaction t) {
      final info = lookup[t.id];
      if (info == null) return t;
      return t.copyWith(
        payReceiveId: info.id,
        payReceiveStatus: info.status,
      );
    }

    return SavingData(
      personal: personal.map((e) => attach(e.$2)).toList(),
      classTransactions: classTransactions.map(attach).toList(),
      personalBalance: personalBalance,
      classBalance: classBalance,
    );
  }

  List<_PayReceiveInfo> _payReceives(dynamic response) {
    dynamic raw = response;
    if (response is Map<String, dynamic>) {
      raw = response['data'] ?? response['results'] ?? response;
    }
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(_PayReceiveInfo.fromJson).toList();
  }

  Future<Map<String, dynamic>> requestWithdrawal({
    required String studentId,
    required double amount,
    required String withdrawReasonId,
    String? note,
  }) async {
    final res = await _api.post(
      '/savings/parent-withdraw',
      body: {
        'studentId': studentId,
        'amount': amount,
        'withdrawReasonId': withdrawReasonId,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is Map<String, dynamic>) return data;
      return res;
    }
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Poll the status of a parent-initiated withdrawal request so the
  /// pending screen can advance through its timeline.
  Future<Map<String, dynamic>?> fetchWithdrawalStatus(String payReceiveId) async {
    if (payReceiveId.trim().isEmpty) return null;
    try {
      final res = await _api.get('/pay-receives/$payReceiveId');
      if (res is Map<String, dynamic>) return res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (_) {
      // Soft-fail — the page will retry on the next user tap.
    }
    return null;
  }

  Future<List<WithdrawalReason>> fetchWithdrawalReasons() async {
    final response = await _api.get(
      '/save-withdraw-reasons/by-type',
      queryParameters: {'type': 'withdraw'},
    );
    dynamic raw = response;
    if (response is Map<String, dynamic>) {
      raw = response['data'] ?? response['results'];
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((json) => json['status'] != false)
        .map(WithdrawalReason.fromJson)
        .where((reason) => reason.id.isNotEmpty)
        .toList();
  }

  List<(Map<String, dynamic>, SavingTransaction)> _records(dynamic response) {
    dynamic raw = response;
    if (response is Map<String, dynamic>) {
      raw = response['data'] ?? response['savings'] ?? response['results'];
    }
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((json) {
      return (json, SavingTransaction.fromJson(json));
    }).toList();
  }

  String _classId(Map<String, dynamic> json) =>
      (json['class_id'] ?? json['classId'] ?? '').toString();

  double _balance(dynamic response) {
    final data = response is Map<String, dynamic> && response['data'] is Map
        ? response['data'] as Map
        : response;
    final value = data is Map ? data['current_balance'] : null;
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }
}

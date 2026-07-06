import '../../../../../core/network/api_client.dart';
import 'saving_model.dart';

class SavingService {
  SavingService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<SavingData> fetch({required String studentId, String? classId}) async {
    final responses = await Future.wait([
      _api.get('/savings/student/$studentId/history'),
      _api.get('/savings/student/$studentId/balance'),
      _api.get('/pay-receive/available-balance/student/$studentId'),
      if ((classId ?? '').isNotEmpty) _api.get('/savings'),
      if ((classId ?? '').isNotEmpty)
        _api.get('/savings/class/$classId/balance'),
      _api.get('/pay-receive'),
    ]);

    final personal = _records(responses[0]);
    final personalBalance = _balance(responses[1]);
    final balanceBreakdown = _balanceBreakdown(responses[2], personalBalance);
    var classTransactions = <SavingTransaction>[];
    var classBalance = 0.0;
    if ((classId ?? '').isNotEmpty) {
      classTransactions = _records(
        responses[3],
      ).where((item) => _classId(item.$1) == classId).map((e) => e.$2).toList();
      classBalance = _balance(responses[4]);
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
      return t.copyWith(payReceiveId: info.id, payReceiveStatus: info.status);
    }

    return SavingData(
      personal: personal.map((e) => attach(e.$2)).toList(),
      classTransactions: classTransactions.map(attach).toList(),
      personalBalance: personalBalance,
      classBalance: classBalance,
      personalAvailableBalance: balanceBreakdown.available,
      personalNonAvailableBalance: balanceBreakdown.nonAvailable,
    );
  }

  List<_PayReceiveInfo> _payReceives(dynamic response) {
    dynamic raw = response;
    if (response is Map<String, dynamic>) {
      raw = response['data'] ?? response['results'] ?? response;
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_PayReceiveInfo.fromJson)
        .toList();
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
      if (data is Map<String, dynamic>) {
        return _normalizeWithdrawalResponse(data);
      }
      return _normalizeWithdrawalResponse(res);
    }
    if (res is Map) {
      return _normalizeWithdrawalResponse(Map<String, dynamic>.from(res));
    }
    return {};
  }

  Map<String, dynamic> _normalizeWithdrawalResponse(Map<String, dynamic> json) {
    final payReceive = json['payReceive'] ?? json['pay_receive'];
    if (payReceive is Map) {
      final normalized = Map<String, dynamic>.from(payReceive);
      normalized['saving'] ??= json['saving'];
      return normalized;
    }
    final data = json['data'];
    if (data is Map) {
      return _normalizeWithdrawalResponse(Map<String, dynamic>.from(data));
    }
    final saving = json['saving'];
    if (saving is Map) {
      final normalized = Map<String, dynamic>.from(saving);
      normalized['saving'] = saving;
      return normalized;
    }
    return json;
  }

  /// Poll the status of a parent-initiated withdrawal request so the
  /// pending screen can advance through its timeline.
  Future<Map<String, dynamic>?> fetchWithdrawalStatus(
    String payReceiveId,
  ) async {
    if (payReceiveId.trim().isEmpty) return null;
    try {
      final res = await _api.get('/pay-receive/$payReceiveId');
      if (res is Map<String, dynamic>) {
        return res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
      }
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

  ({double available, double nonAvailable}) _balanceBreakdown(
    dynamic response,
    double totalBalance,
  ) {
    final data = response is Map<String, dynamic> && response['data'] is Map
        ? response['data'] as Map
        : response;
    if (data is! Map) {
      return (available: totalBalance, nonAvailable: 0);
    }
    final available = _num(
      data['availableBalance'] ?? data['available_balance'],
    );
    final nonAvailable = _num(
      data['nonAvailableBalance'] ?? data['non_available_balance'],
    );
    final computedNonAvailable = nonAvailable > 0
        ? nonAvailable
        : (totalBalance - available).clamp(0, double.infinity).toDouble();
    final computedAvailable = available > 0
        ? available
        : (totalBalance - computedNonAvailable)
              .clamp(0, double.infinity)
              .toDouble();
    return (available: computedAvailable, nonAvailable: computedNonAvailable);
  }

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

/// Slim view of a PayReceive record used to attach in-flight status onto
/// SavingTransaction rows without exposing the full backend shape.
class _PayReceiveInfo {
  final String id;
  final String savingId;
  final String status;
  final DateTime updatedAt;

  const _PayReceiveInfo({
    required this.id,
    required this.savingId,
    required this.status,
    required this.updatedAt,
  });

  factory _PayReceiveInfo.fromJson(Map<String, dynamic> json) {
    final saving = json['saving'];
    final savingId =
        (json['saving_id'] ??
                json['savingId'] ??
                (saving is Map ? saving['id'] : null) ??
                '')
            .toString();
    return _PayReceiveInfo(
      id: (json['id'] ?? '').toString(),
      savingId: savingId,
      status: (json['status'] ?? '').toString().trim().toLowerCase(),
      updatedAt:
          DateTime.tryParse(
            (json['updated_at'] ??
                    json['updatedAt'] ??
                    json['created_at'] ??
                    json['createdAt'] ??
                    '')
                .toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

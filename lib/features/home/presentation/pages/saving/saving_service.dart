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

    return SavingData(
      personal: personal.map((e) => e.$2).toList(),
      classTransactions: classTransactions,
      personalBalance: personalBalance,
      classBalance: classBalance,
    );
  }

  Future<void> requestWithdrawal({
    required String studentId,
    required double amount,
    required String withdrawReasonId,
    String? note,
  }) async {
    await _api.post(
      '/savings/parent-withdraw',
      body: {
        'studentId': studentId,
        'amount': amount,
        'withdrawReasonId': withdrawReasonId,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
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

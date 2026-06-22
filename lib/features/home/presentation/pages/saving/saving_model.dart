class SavingTransaction {
  final String id;
  final String ownerType;
  final String transactionType;
  final double amount;
  final double closingBalance;
  final DateTime createdAt;

  const SavingTransaction({
    required this.id,
    required this.ownerType,
    required this.transactionType,
    required this.amount,
    required this.closingBalance,
    required this.createdAt,
  });

  factory SavingTransaction.fromJson(Map<String, dynamic> json) {
    return SavingTransaction(
      id: json['id']?.toString() ?? '',
      ownerType: json['owner_type']?.toString().toUpperCase() ?? '',
      transactionType: json['transaction_type']?.toString().toUpperCase() ?? '',
      amount: _number(json['amount']),
      closingBalance: _number(json['closing_balance']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class SavingData {
  final List<SavingTransaction> personal;
  final List<SavingTransaction> classTransactions;
  final double personalBalance;
  final double classBalance;

  const SavingData({
    required this.personal,
    required this.classTransactions,
    required this.personalBalance,
    required this.classBalance,
  });
}

class WithdrawalReason {
  final String id;
  final String nameLao;
  final String nameEn;

  const WithdrawalReason({
    required this.id,
    required this.nameLao,
    required this.nameEn,
  });

  String get label => nameLao.isNotEmpty ? nameLao : nameEn;

  factory WithdrawalReason.fromJson(Map<String, dynamic> json) {
    return WithdrawalReason(
      id: json['id']?.toString() ?? '',
      nameLao: json['nameLao']?.toString().trim() ?? '',
      nameEn: json['nameEn']?.toString().trim() ?? '',
    );
  }
}

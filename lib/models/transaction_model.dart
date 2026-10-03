class Transaction {
  final int? transactionId;
  final String type;
  final double amount;
  final int accountId;
  final int categoryId;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    this.transactionId,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
}
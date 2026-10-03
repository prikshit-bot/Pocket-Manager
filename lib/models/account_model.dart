class Account {
  final int? accountId;
  final String name;
  final String type;
  final double balance;
  final String? note;
  final bool isVisible;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    this.accountId,
    required this.name,
    required this.type,
    required this.balance,
    this.note,
    required this.isVisible,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}
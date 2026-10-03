class Transfer{
	final int? transferId;
	final double amount;
	final int fromAccountId;
	final int toAccountId;
	final DateTime date;
	final String? note;
	final DateTime createdAt;
	final DateTime updatedAt;
	
Transfer({
	this.transferId,
	required this.amount,
	required this.fromAccountId,
	required this.toAccountId,
	required this.date,
	this.note,
	required this.createdAt,
	required this.updatedAt,
	});
}
	
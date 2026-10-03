class Goal{
	final int? goalId;
	final String name;
	final double targetAmount;
	final double savedAmount;
	final DateTime? targetDate;
	final String? note;
	final String status;
	final DateTime createdAt;
	final DateTime updatedAt;
	
Goal({
	this.goalId,
	required this.name,
	required this.targetAmount,
	required this.savedAmount,
	this.targetDate,
	this.note,
	required this.status,
	required this.createdAt,
	required this.updatedAt,
	});
}
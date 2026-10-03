class GoalContribution{
	final int? contributionId;
	final int goalId;
	final int accountId;
	final double amount;
	final DateTime date;
	final String? note;
	final DateTime createdAt;
	
GoalContribution({
	this.contributionId,
	required this.goalId,
	required this.accountId,
	required this.amount,
	required this.date,
	this.note,
	required this.createdAt,
	});
}
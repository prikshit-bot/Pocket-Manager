import 'transaction_model.dart';
import 'goal_model.dart';

class HomeSummary {
  final double totalBalance;
  final double totalReserved;
  final double availableBalance;
  final double monthlyIncome;
  final double monthlyExpense;
  final double monthlyNet;
  final List<Transaction> recentTransactions;
  final List<Goal> goals;

  HomeSummary({
    required this.totalBalance,
    required this.totalReserved,
    required this.availableBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlyNet,
    required this.recentTransactions,
    required this.goals,
  });
}
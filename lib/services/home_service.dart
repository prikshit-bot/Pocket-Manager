import '../database/transaction_dao.dart';
import '../services/account_service.dart';
import '../services/goal_service.dart';
import '../models/home_summary_model.dart';

class HomeService {
  final AccountService _accountService = AccountService();
  final GoalService _goalService = GoalService();
  final TransactionDao _transactionDao = TransactionDao();

  Future<HomeSummary> getHomeSummary({
    int recentTransactionsLimit = 5,
    int goalsPreviewLimit = 3,
  }) async {
    final availableBalance = await _accountService.getTotalAvailableBalance();
    final visibleAccountIds = (await _accountService.getVisibleActiveAccounts())
      .map((account) => account.accountId!)
      .toSet();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    final monthlyTransactions = (await _transactionDao.getTransactionsByDateRange(
      monthStart,
      monthEnd,
    ))
        .where((transaction) => visibleAccountIds.contains(transaction.accountId))
        .toList();

    double monthlyIncome = 0.0;
    double monthlyExpense = 0.0;
    for (final t in monthlyTransactions) {
      if (t.type == 'Income') {
        monthlyIncome += t.amount;
      } else if (t.type == 'Expense') {
        monthlyExpense += t.amount;
      }
    }
    final monthlyNet = monthlyIncome - monthlyExpense;

    final allTransactions = (await _transactionDao.getAllTransactions())
      .where((transaction) => visibleAccountIds.contains(transaction.accountId))
      .toList();
    final recentTransactions =
      allTransactions.take(recentTransactionsLimit).toList();

    final activeGoals = await _goalService.getGoalsByStatus('Active');
    final goalsPreview = activeGoals.take(goalsPreviewLimit).toList();

    return HomeSummary(
      totalBalance: availableBalance,
      totalReserved: 0,
      availableBalance: availableBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      monthlyNet: monthlyNet,
      recentTransactions: recentTransactions,
      goals: goalsPreview,
    );
  }
}
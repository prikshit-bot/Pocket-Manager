import '../database/database_helper.dart';
import '../database/goal_dao.dart';
import '../database/goal_contribution_dao.dart';
import '../database/account_dao.dart';
import '../models/goal_model.dart';
import '../models/goal_contribution_model.dart';

class GoalService {
  static const String active = 'Active';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final GoalDao _goalDao = GoalDao();
  final GoalContributionDao _goalContributionDao = GoalContributionDao();
  final AccountDao _accountDao = AccountDao();

  Goal _goalWith(Goal g, {double? savedAmount, String? status}) {
    return Goal(
      goalId: g.goalId,
      name: g.name,
      targetAmount: g.targetAmount,
      savedAmount: savedAmount ?? g.savedAmount,
      targetDate: g.targetDate,
      note: g.note,
      status: status ?? g.status,
      createdAt: g.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<int> createGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? note,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Goal name is required.');
    }
    if (targetAmount <= 0) {
      throw Exception('Target amount must be greater than zero.');
    }

    final now = DateTime.now();
    return await _goalDao.insertGoal(
      Goal(
        name: trimmedName,
        targetAmount: targetAmount,
        savedAmount: 0,
        targetDate: targetDate,
        note: note,
        status: active,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // Edits name/target/date/note. saved_amount is never edited directly.
  Future<int> updateGoal(Goal edited) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final existing = await _goalDao.getGoal(edited.goalId!, executor: txn);
      if (existing == null) {
        throw Exception('Goal not found.');
      }

      final trimmedName = edited.name.trim();
      if (trimmedName.isEmpty) {
        throw Exception('Goal name is required.');
      }
      if (edited.targetAmount <= 0) {
        throw Exception('Target amount must be greater than zero.');
      }

      return await _goalDao.updateGoal(
        Goal(
          goalId: existing.goalId,
          name: trimmedName,
          targetAmount: edited.targetAmount,
          savedAmount: existing.savedAmount,
          targetDate: edited.targetDate,
          note: edited.note,
          status: existing.status,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
        executor: txn,
      );
    });
  }

  // Reserves money from an account for a goal. Does NOT change accounts.balance.
  Future<int> addMoney({
    required int goalId,
    required int accountId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero.');
      }

      final goal = await _goalDao.getGoal(goalId, executor: txn);
      if (goal == null) {
        throw Exception('Goal not found.');
      }
      if (goal.status != active) {
        throw Exception('Money can only be added to an active goal.');
      }

      final account = await _accountDao.getAccount(accountId, executor: txn);
      if (account == null) {
        throw Exception('Account not found.');
      }
      if (!account.isActive) {
        throw Exception('Account is not active.');
      }

      final reserved = await _goalContributionDao.getTotalReservedForAccount(
        accountId,
        executor: txn,
      );
      final available = account.balance - reserved;
      if (amount > available) {
        throw Exception('Insufficient available balance in this account.');
      }

      final now = DateTime.now();
      final contributionId = await _goalContributionDao.insertContribution(
        GoalContribution(
          goalId: goalId,
          accountId: accountId,
          amount: amount,
          date: date ?? now,
          note: note,
          createdAt: now,
        ),
        executor: txn,
      );

      final newSaved = goal.savedAmount + amount;
      await _goalDao.updateGoal(
        _goalWith(goal, savedAmount: newSaved),
        executor: txn,
      );

      return contributionId;
    });
  }

  // Releases reserved money back to an account's available balance by
  // recording a NEGATIVE contribution (history is never deleted).
  Future<int> withdrawMoney({
    required int goalId,
    required int accountId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero.');
      }

      final goal = await _goalDao.getGoal(goalId, executor: txn);
      if (goal == null) {
        throw Exception('Goal not found.');
      }

      final account = await _accountDao.getAccount(accountId, executor: txn);
      if (account == null) {
        throw Exception('Account not found.');
      }
      if (!account.isActive) {
        throw Exception('Account is not active.');
      }

      if (amount > goal.savedAmount) {
        throw Exception('Cannot withdraw more than the goal has saved.');
      }

      // Money reserved for this goal must be released from the same
      // account it was reserved in.
      final contributions = await _goalContributionDao.getContributionsByGoal(
        goalId,
        executor: txn,
      );
      final heldInAccount = contributions
          .where((c) => c.accountId == accountId)
          .fold<double>(0.0, (sum, c) => sum + c.amount);
      if (amount > heldInAccount) {
        throw Exception(
          'This goal has less money reserved in the selected account.',
        );
      }

      final now = DateTime.now();
      final contributionId = await _goalContributionDao.insertContribution(
        GoalContribution(
          goalId: goalId,
          accountId: accountId,
          amount: -amount,
          date: date ?? now,
          note: note,
          createdAt: now,
        ),
        executor: txn,
      );

      await _goalDao.updateGoal(
        _goalWith(goal, savedAmount: goal.savedAmount - amount),
        executor: txn,
      );

      return contributionId;
    });
  }

  // Manually mark an active goal as completed.
  Future<int> completeGoal(int goalId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final goal = await _goalDao.getGoal(goalId, executor: txn);
      if (goal == null) {
        throw Exception('Goal not found.');
      }
      if (goal.status != active) {
        throw Exception('Only an active goal can be marked complete.');
      }
      return await _goalDao.updateGoal(
        _goalWith(goal, status: completed),
        executor: txn,
      );
    });
  }

  // Pure status change (Option B): reserved money stays reserved until the
  // user explicitly withdraws it.
  Future<int> cancelGoal(int goalId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final goal = await _goalDao.getGoal(goalId, executor: txn);
      if (goal == null) {
        throw Exception('Goal not found.');
      }
      if (goal.status == cancelled) {
        return 0;
      }
      return await _goalDao.updateGoal(
        _goalWith(goal, status: cancelled),
        executor: txn,
      );
    });
  }

  Future<int> deleteGoal(int goalId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final goal = await _goalDao.getGoal(goalId, executor: txn);
      if (goal == null) return 0;

      if (goal.status == active && goal.savedAmount > 0) {
        throw Exception(
          'Withdraw the saved money before deleting an active goal.',
        );
      }

      await _goalContributionDao.deleteContributionsByGoal(
        goalId,
        executor: txn,
      );
      return await _goalDao.deleteGoal(goalId, executor: txn);
    });
  }

  Future<Goal?> getGoal(int goalId) {
    return _goalDao.getGoal(goalId);
  }

  Future<List<Goal>> getAllGoals() {
    return _goalDao.getAllGoals();
  }

  Future<List<Goal>> getGoalsByStatus(String status) {
    return _goalDao.getGoalsByStatus(status);
  }

  Future<List<GoalContribution>> getContributionsForGoal(int goalId) {
    return _goalContributionDao.getContributionsByGoal(goalId);
  }
}
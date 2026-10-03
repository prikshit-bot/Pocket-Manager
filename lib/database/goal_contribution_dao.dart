// goal_contribution_dao.dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/goal_contribution_model.dart';

class GoalContributionDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(GoalContribution contribution) {
    return {
      'contribution_id': contribution.contributionId,
      'goal_id': contribution.goalId,
      'account_id': contribution.accountId,
      'amount': contribution.amount,
      'date': contribution.date.toIso8601String(),
      'note': contribution.note,
      'created_at': contribution.createdAt.toIso8601String(),
    };
  }

  GoalContribution _fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      contributionId: map['contribution_id'] as int?,
      goalId: map['goal_id'] as int,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Future<int> insertContribution(
    GoalContribution contribution, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final map = _toMap(contribution);
    map.remove('contribution_id');
    return await db.insert('goal_contributions', map);
  }

  Future<List<GoalContribution>> getContributionsByGoal(
    int goalId, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'goal_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<GoalContribution>> getContributionsByAccount(
    int accountId, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'goal_contributions',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<int> deleteContributionsByGoal(
    int goalId, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    return await db.delete(
      'goal_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );
  }

  // Sums all contributions (adds count positive, withdrawals count negative)
  // for a given account, giving the total currently reserved for goals
  // out of that account's actual balance.
  Future<double> getTotalReservedForAccount(
    int accountId, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM goal_contributions WHERE account_id = ?',
      [accountId],
    );
    final total = result.first['total'];
    if (total == null) {
      return 0.0;
    }
    return (total as num).toDouble();
  }
}
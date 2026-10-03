// goal_dao.dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/goal_model.dart';

class GoalDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(Goal goal) {
    return {
      'goal_id': goal.goalId,
      'name': goal.name,
      'target_amount': goal.targetAmount,
      'saved_amount': goal.savedAmount,
      'target_date': goal.targetDate?.toIso8601String(),
      'note': goal.note,
      'status': goal.status,
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': goal.updatedAt.toIso8601String(),
    };
  }

  Goal _fromMap(Map<String, dynamic> map) {
    final targetDate = map['target_date'] as String?;
    return Goal(
      goalId: map['goal_id'] as int?,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num).toDouble(),
      targetDate: targetDate == null ? null : DateTime.parse(targetDate),
      note: map['note'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<int> insertGoal(Goal goal, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final map = _toMap(goal);
    map.remove('goal_id');
    return await db.insert('goals', map);
  }

  Future<Goal?> getGoal(int goalId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'goals',
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  Future<List<Goal>> getAllGoals({DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query('goals', orderBy: 'created_at DESC');
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<Goal>> getGoalsByStatus(
    String status, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'goals',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<int> updateGoal(Goal goal, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'goals',
      _toMap(goal),
      where: 'goal_id = ?',
      whereArgs: [goal.goalId],
    );
  }

  Future<int> deleteGoal(int goalId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.delete(
      'goals',
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );
  }
}
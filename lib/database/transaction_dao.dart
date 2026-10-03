// transaction_dao.dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/transaction_model.dart' as app_models;

class TransactionDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(app_models.Transaction transaction) {
    return {
      'transaction_id': transaction.transactionId,
      'type': transaction.type,
      'amount': transaction.amount,
      'account_id': transaction.accountId,
      'category_id': transaction.categoryId,
      'date': transaction.date.toIso8601String(),
      'note': transaction.note,
      'created_at': transaction.createdAt.toIso8601String(),
      'updated_at': transaction.updatedAt.toIso8601String(),
    };
  }

  app_models.Transaction _fromMap(Map<String, dynamic> map) {
    return app_models.Transaction(
      transactionId: map['transaction_id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<int> insertTransaction(app_models.Transaction transaction, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final map = _toMap(transaction);
    map.remove('transaction_id');
    return await db.insert('transactions', map);
  }

  Future<app_models.Transaction?> getTransaction(int transactionId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  Future<List<app_models.Transaction>> getAllTransactions({DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query('transactions', orderBy: 'date DESC');
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<app_models.Transaction>> getTransactionsByAccount(int accountId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<app_models.Transaction>> getTransactionsByCategory(int categoryId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transactions',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<app_models.Transaction>> getTransactionsByType(String type, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<app_models.Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<int> updateTransaction(app_models.Transaction transaction, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'transactions',
      _toMap(transaction),
      where: 'transaction_id = ?',
      whereArgs: [transaction.transactionId],
    );
  }

  Future<int> deleteTransaction(int transactionId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.delete(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }
} 
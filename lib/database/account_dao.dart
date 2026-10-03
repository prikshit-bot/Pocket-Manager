// account_dao.dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/account_model.dart';

class AccountDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Returns the given executor if provided, otherwise the default database.
  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(Account account) {
    return {
      'account_id': account.accountId,
      'name': account.name,
      'type': account.type,
      'balance': account.balance,
      'note': account.note,
      'is_visible': account.isVisible ? 1 : 0,
      'is_active': account.isActive ? 1 : 0,
      'created_at': account.createdAt.toIso8601String(),
      'updated_at': account.updatedAt.toIso8601String(),
    };
  }

  Account _fromMap(Map<String, dynamic> map) {
    return Account(
      accountId: map['account_id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      note: map['note'] as String?,
      isVisible: (map['is_visible'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<int> insertAccount(Account account, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final map = _toMap(account);
    map.remove('account_id');
    return await db.insert('accounts', map);
  }

  Future<Account?> getAccount(int accountId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'accounts',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  Future<List<Account>> getAllAccounts({DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query('accounts');
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<int> updateAccount(Account account, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'accounts',
      _toMap(account),
      where: 'account_id = ?',
      whereArgs: [account.accountId],
    );
  }

  Future<int> deleteAccount(int accountId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.delete(
      'accounts',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }
}
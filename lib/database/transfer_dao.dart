import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/transfer_model.dart';

class TransferDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(Transfer transfer) {
    return {
      'transfer_id': transfer.transferId,
      'amount': transfer.amount,
      'from_account_id': transfer.fromAccountId,
      'to_account_id': transfer.toAccountId,
      'date': transfer.date.toIso8601String(),
      'note': transfer.note,
      'created_at': transfer.createdAt.toIso8601String(),
      'updated_at': transfer.updatedAt.toIso8601String(),
    };
  }

  Transfer _fromMap(Map<String, dynamic> map) {
    return Transfer(
      transferId: map['transfer_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      fromAccountId: map['from_account_id'] as int,
      toAccountId: map['to_account_id'] as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<int> insertTransfer(Transfer transfer, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final map = _toMap(transfer);
    map.remove('transfer_id');
    return await db.insert('transfers', map);
  }

  Future<Transfer?> getTransfer(int transferId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transfers',
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  Future<List<Transfer>> getAllTransfers({DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query('transfers', orderBy: 'date DESC');
    return results.map((map) => _fromMap(map)).toList();
  }

  // Transfers where the account is either the source or the destination.
  Future<List<Transfer>> getTransfersByAccount(int accountId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transfers',
      where: 'from_account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<Transfer>> getTransfersByDateRange(
    DateTime start,
    DateTime end, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'transfers',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<int> updateTransfer(Transfer transfer, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'transfers',
      _toMap(transfer),
      where: 'transfer_id = ?',
      whereArgs: [transfer.transferId],
    );
  }

  Future<int> deleteTransfer(int transferId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.delete(
      'transfers',
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
  }
}
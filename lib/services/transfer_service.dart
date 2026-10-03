import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/transfer_dao.dart';
import '../database/account_dao.dart';
import '../database/goal_contribution_dao.dart';
import '../models/transfer_model.dart';
import '../models/account_model.dart';

class TransferService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TransferDao _transferDao = TransferDao();
  final AccountDao _accountDao = AccountDao();
  final GoalContributionDao _goalContributionDao = GoalContributionDao();

  void _addDelta(Map<int, double> deltas, int accountId, double delta) {
    deltas[accountId] = (deltas[accountId] ?? 0.0) + delta;
  }

  // Applies net balance changes per account. For any account whose balance
  // decreases, its AVAILABLE balance (balance - goal reservations) must stay
  // >= 0 afterwards. Netting deltas first makes same-account edits safe.
  Future<void> _commitDeltas(
    DatabaseExecutor txn,
    Map<int, double> deltas,
  ) async {
    for (final entry in deltas.entries) {
      final account = await _accountDao.getAccount(entry.key, executor: txn);
      if (account == null) {
        throw Exception('Account not found.');
      }

      final newBalance = account.balance + entry.value;

      if (entry.value < 0) {
        final reserved = await _goalContributionDao.getTotalReservedForAccount(
          entry.key,
          executor: txn,
        );
        if (newBalance - reserved < 0) {
          throw Exception(
            'Insufficient available balance in "${account.name}".',
          );
        }
      }

      await _accountDao.updateAccount(
        Account(
          accountId: account.accountId,
          name: account.name,
          type: account.type,
          balance: newBalance,
          note: account.note,
          isVisible: account.isVisible,
          isActive: account.isActive,
          createdAt: account.createdAt,
          updatedAt: DateTime.now(),
        ),
        executor: txn,
      );
    }
  }

  Future<void> _validateNewTransfer(
    DatabaseExecutor txn,
    Transfer transfer,
  ) async {
    if (transfer.amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }
    if (transfer.fromAccountId == transfer.toAccountId) {
      throw Exception('Source and destination accounts must be different.');
    }

    final from = await _accountDao.getAccount(
      transfer.fromAccountId,
      executor: txn,
    );
    final to = await _accountDao.getAccount(
      transfer.toAccountId,
      executor: txn,
    );
    if (from == null) {
      throw Exception('Source account not found.');
    }
    if (to == null) {
      throw Exception('Destination account not found.');
    }
    if (!from.isActive || !to.isActive) {
      throw Exception('Both accounts must be active.');
    }
  }

  Future<int> createTransfer(Transfer transfer) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      await _validateNewTransfer(txn, transfer);

      final deltas = <int, double>{};
      _addDelta(deltas, transfer.fromAccountId, -transfer.amount);
      _addDelta(deltas, transfer.toAccountId, transfer.amount);
      await _commitDeltas(txn, deltas);

      return await _transferDao.insertTransfer(transfer, executor: txn);
    });
  }

  // Reverses the old transfer and applies the new one, netted per account.
  Future<int> updateTransfer(Transfer updated) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final old = await _transferDao.getTransfer(
        updated.transferId!,
        executor: txn,
      );
      if (old == null) {
        throw Exception('Transfer not found.');
      }

      await _validateNewTransfer(txn, updated);

      final deltas = <int, double>{};
      // Reverse old effect.
      _addDelta(deltas, old.fromAccountId, old.amount);
      _addDelta(deltas, old.toAccountId, -old.amount);
      // Apply new effect.
      _addDelta(deltas, updated.fromAccountId, -updated.amount);
      _addDelta(deltas, updated.toAccountId, updated.amount);
      await _commitDeltas(txn, deltas);

      return await _transferDao.updateTransfer(updated, executor: txn);
    });
  }

  Future<int> deleteTransfer(int transferId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final transfer = await _transferDao.getTransfer(
        transferId,
        executor: txn,
      );
      if (transfer == null) {
        return 0;
      }

      // Reversing means the destination gives the money back.
      final deltas = <int, double>{};
      _addDelta(deltas, transfer.fromAccountId, transfer.amount);
      _addDelta(deltas, transfer.toAccountId, -transfer.amount);
      await _commitDeltas(txn, deltas);

      return await _transferDao.deleteTransfer(transferId, executor: txn);
    });
  }

  Future<Transfer?> getTransfer(int transferId) {
    return _transferDao.getTransfer(transferId);
  }

  Future<List<Transfer>> getAllTransfers() {
    return _transferDao.getAllTransfers();
  }

  Future<List<Transfer>> getTransfersByAccount(int accountId) {
    return _transferDao.getTransfersByAccount(accountId);
  }
}
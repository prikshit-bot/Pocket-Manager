import '../database/database_helper.dart';
import '../database/account_dao.dart';
import '../database/transaction_dao.dart';
import '../database/transfer_dao.dart';
import '../database/goal_contribution_dao.dart';
import '../models/account_model.dart';

class AccountService {
  static const List<String> validTypes = [
    'Cash',
    'Bank',
    'Savings',
    'Card',
    'Other',
  ];

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AccountDao _accountDao = AccountDao();
  final TransactionDao _transactionDao = TransactionDao();
  final TransferDao _transferDao = TransferDao();
  final GoalContributionDao _goalContributionDao = GoalContributionDao();

  // Creates an account with an opening balance.
  // No income transaction is created for the opening balance (per rules).
  Future<int> createAccount({
    required String name,
    required String type,
    double openingBalance = 0,
    String? note,
    bool isVisible = true,
    bool isActive = true,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Account name is required.');
    }
    if (!validTypes.contains(type)) {
      throw Exception('Invalid account type.');
    }
    if (openingBalance < 0) {
      throw Exception('Opening balance cannot be negative.');
    }

    final now = DateTime.now();
    final account = Account(
      name: trimmedName,
      type: type,
      balance: openingBalance,
      note: note,
      isVisible: isVisible,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
    return await _accountDao.insertAccount(account);
  }

  // Edits account details. The balance is NEVER changed here — it only
  // changes through transactions, transfers, and balance-affecting services.
  Future<int> updateAccount(Account edited) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final existing = await _accountDao.getAccount(
        edited.accountId!,
        executor: txn,
      );
      if (existing == null) {
        throw Exception('Account not found.');
      }

      final trimmedName = edited.name.trim();
      if (trimmedName.isEmpty) {
        throw Exception('Account name is required.');
      }
      if (!validTypes.contains(edited.type)) {
        throw Exception('Invalid account type.');
      }

      final updated = Account(
        accountId: existing.accountId,
        name: trimmedName,
        type: edited.type,
        balance: existing.balance, // preserved
        note: edited.note,
        isVisible: edited.isVisible,
        isActive: edited.isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      return await _accountDao.updateAccount(updated, executor: txn);
    });
  }

  Future<int> setVisibility(int accountId, bool isVisible) async {
    final existing = await _accountDao.getAccount(accountId);
    if (existing == null) {
      throw Exception('Account not found.');
    }
    return await updateAccount(Account(
      accountId: existing.accountId,
      name: existing.name,
      type: existing.type,
      balance: existing.balance,
      note: existing.note,
      isVisible: isVisible,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    ));
  }

  Future<int> setActive(int accountId, bool isActive) async {
    final existing = await _accountDao.getAccount(accountId);
    if (existing == null) {
      throw Exception('Account not found.');
    }
    return await updateAccount(Account(
      accountId: existing.accountId,
      name: existing.name,
      type: existing.type,
      balance: existing.balance,
      note: existing.note,
      isVisible: existing.isVisible,
      isActive: isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    ));
  }

  // Only allowed when the account has no history and no money in it.
  Future<int> deleteAccount(int accountId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final account = await _accountDao.getAccount(accountId, executor: txn);
      if (account == null) {
        return 0;
      }

      final transactions = await _transactionDao.getTransactionsByAccount(
        accountId,
        executor: txn,
      );
      final transfers = await _transferDao.getTransfersByAccount(
        accountId,
        executor: txn,
      );
      final contributions = await _goalContributionDao.getContributionsByAccount(
        accountId,
        executor: txn,
      );

      if (transactions.isNotEmpty ||
          transfers.isNotEmpty ||
          contributions.isNotEmpty) {
        throw Exception(
          'This account has financial records and cannot be deleted. '
          'Deactivate or hide it instead.',
        );
      }
      if (account.balance != 0) {
        throw Exception('Account still holds a balance and cannot be deleted.');
      }

      return await _accountDao.deleteAccount(accountId, executor: txn);
    });
  }

  Future<Account?> getAccount(int accountId) {
    return _accountDao.getAccount(accountId);
  }

  Future<List<Account>> getAllAccounts() {
    return _accountDao.getAllAccounts();
  }

  Future<List<Account>> getVisibleAccounts() async {
    final accounts = await _accountDao.getAllAccounts();
    return accounts.where((a) => a.isVisible).toList();
  }

  Future<List<Account>> getActiveAccounts() async {
    final accounts = await _accountDao.getAllAccounts();
    return accounts.where((a) => a.isActive).toList();
  }

  Future<List<Account>> getVisibleActiveAccounts() async {
    final accounts = await _accountDao.getAllAccounts();
    return accounts.where((a) => a.isActive && a.isVisible).toList();
  }

  // Actual balance minus money reserved for goals in this account.
  Future<double> getAvailableBalance(int accountId) async {
    final account = await _accountDao.getAccount(accountId);
    if (account == null) {
      throw Exception('Account not found.');
    }
    final reserved =
        await _goalContributionDao.getTotalReservedForAccount(accountId);
    return account.balance - reserved;
  }

  // Sum of balances across active accounts (dashboard "current balance").
  Future<double> getTotalBalance() async {
    final accounts = await getActiveAccounts();
    return accounts.fold<double>(0.0, (sum, a) => sum + a.balance);
  }

  Future<double> getTotalAvailableBalance() async {
    final accounts = await getVisibleActiveAccounts();
    double total = 0.0;
    for (final account in accounts) {
      total += await getAvailableBalance(account.accountId!);
    }
    return total;
  }

  // Sum of goal reservations across active accounts.
  Future<double> getTotalReserved() async {
    final accounts = await getActiveAccounts();
    double total = 0.0;
    for (final account in accounts) {
      total += await _goalContributionDao
          .getTotalReservedForAccount(account.accountId!);
    }
    return total;
  }

  // Liquid Balance = Aggregate Account Capital - Total Sequestered Goal Assets
  Future<double> getLiquidBalance() async {
    final total = await getTotalBalance();
    final reserved = await getTotalReserved();
    return total - reserved;
  }
}
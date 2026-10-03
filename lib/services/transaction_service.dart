import '../database/database_helper.dart';
import '../database/transaction_dao.dart';
import '../database/account_dao.dart';
import '../database/category_dao.dart';
import '../database/goal_contribution_dao.dart';
import '../models/transaction_model.dart' as app_models;
import '../models/account_model.dart';

class TransactionService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TransactionDao _transactionDao = TransactionDao();
  final AccountDao _accountDao = AccountDao();
  final CategoryDao _categoryDao = CategoryDao();
  final GoalContributionDao _goalContributionDao = GoalContributionDao();

  Future<int> createTransaction(app_models.Transaction transaction) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      if (transaction.amount <= 0) {
        throw Exception('Amount must be greater than zero.');
      }

      if (transaction.type != 'Income' && transaction.type != 'Expense') {
        throw Exception('Invalid transaction type.');
      }

      final account = await _accountDao.getAccount(
        transaction.accountId,
        executor: txn,
      );
      if (account == null) {
        throw Exception('Account not found.');
      }
      if (!account.isActive) {
        throw Exception('Account is not active.');
      }

      final category = await _categoryDao.getCategory(
        transaction.categoryId,
        executor: txn,
      );
      if (category == null) {
        throw Exception('Category not found.');
      }
      if (category.isDeleted) {
        throw Exception('Category has been deleted.');
      }
      if (category.type != transaction.type) {
        throw Exception('Category type does not match transaction type.');
      }

      double newBalance;
      if (transaction.type == 'Income') {
        newBalance = account.balance + transaction.amount;
      } else {
        // Expense: check against AVAILABLE balance (actual balance minus
        // money reserved for goals), not raw account.balance.
        final reserved = await _goalContributionDao.getTotalReservedForAccount(
          account.accountId!,
          executor: txn,
        );
        final availableBalance = account.balance - reserved;

        if (transaction.amount > availableBalance) {
          throw Exception('Insufficient available balance for this expense.');
        }

        newBalance = account.balance - transaction.amount;
      }

      final newId = await _transactionDao.insertTransaction(
        transaction,
        executor: txn,
      );

      final updatedAccount = Account(
        accountId: account.accountId,
        name: account.name,
        type: account.type,
        balance: newBalance,
        note: account.note,
        isVisible: account.isVisible,
        isActive: account.isActive,
        createdAt: account.createdAt,
        updatedAt: DateTime.now(),
      );
      await _accountDao.updateAccount(updatedAccount, executor: txn);

      return newId;
    });
  }

  Future<int> updateTransaction(app_models.Transaction updatedTransaction) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final oldTransaction = await _transactionDao.getTransaction(
        updatedTransaction.transactionId!,
        executor: txn,
      );
      if (oldTransaction == null) {
        throw Exception('Transaction not found.');
      }

      final oldAccount = await _accountDao.getAccount(
        oldTransaction.accountId,
        executor: txn,
      );
      if (oldAccount == null) {
        throw Exception('Old account not found.');
      }

      double oldAccountBalance = oldAccount.balance;
      if (oldTransaction.type == 'Income') {
        oldAccountBalance -= oldTransaction.amount;
      } else {
        oldAccountBalance += oldTransaction.amount;
      }

      if (updatedTransaction.amount <= 0) {
        throw Exception('Amount must be greater than zero.');
      }
      if (updatedTransaction.type != 'Income' &&
          updatedTransaction.type != 'Expense') {
        throw Exception('Invalid transaction type.');
      }

      final newAccount = await _accountDao.getAccount(
        updatedTransaction.accountId,
        executor: txn,
      );
      if (newAccount == null) {
        throw Exception('New account not found.');
      }
      if (!newAccount.isActive) {
        throw Exception('Account is not active.');
      }

      final newCategory = await _categoryDao.getCategory(
        updatedTransaction.categoryId,
        executor: txn,
      );
      if (newCategory == null) {
        throw Exception('Category not found.');
      }
      if (newCategory.isDeleted) {
        throw Exception('Category has been deleted.');
      }
      if (newCategory.type != updatedTransaction.type) {
        throw Exception('Category type does not match transaction type.');
      }

      // Save the reversed balance on the old account first.
      final oldAccountUpdated = Account(
        accountId: oldAccount.accountId,
        name: oldAccount.name,
        type: oldAccount.type,
        balance: oldAccountBalance,
        note: oldAccount.note,
        isVisible: oldAccount.isVisible,
        isActive: oldAccount.isActive,
        createdAt: oldAccount.createdAt,
        updatedAt: DateTime.now(),
      );
      await _accountDao.updateAccount(oldAccountUpdated, executor: txn);

      double newAccountBalance = (newAccount.accountId == oldAccount.accountId)
          ? oldAccountBalance
          : newAccount.balance;

      if (updatedTransaction.type == 'Income') {
        newAccountBalance += updatedTransaction.amount;
      } else {
        // Expense: check against available balance on the (post-reversal)
        // starting balance for the new account.
        final reserved = await _goalContributionDao.getTotalReservedForAccount(
          updatedTransaction.accountId,
          executor: txn,
        );
        final availableBalance = newAccountBalance - reserved;

        if (updatedTransaction.amount > availableBalance) {
          throw Exception('Insufficient available balance for this expense.');
        }

        newAccountBalance -= updatedTransaction.amount;
      }

      final newAccountUpdated = Account(
        accountId: newAccount.accountId,
        name: newAccount.name,
        type: newAccount.type,
        balance: newAccountBalance,
        note: newAccount.note,
        isVisible: newAccount.isVisible,
        isActive: newAccount.isActive,
        createdAt: newAccount.createdAt,
        updatedAt: DateTime.now(),
      );
      await _accountDao.updateAccount(newAccountUpdated, executor: txn);

      return await _transactionDao.updateTransaction(
        updatedTransaction,
        executor: txn,
      );
    });
  }

  Future<int> deleteTransaction(int transactionId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final transaction = await _transactionDao.getTransaction(
        transactionId,
        executor: txn,
      );
      if (transaction == null) {
        return 0;
      }

      final account = await _accountDao.getAccount(
        transaction.accountId,
        executor: txn,
      );
      if (account != null) {
        double balance = account.balance;
        if (transaction.type == 'Income') {
          balance -= transaction.amount;
        } else {
          balance += transaction.amount;
        }

        final updatedAccount = Account(
          accountId: account.accountId,
          name: account.name,
          type: account.type,
          balance: balance,
          note: account.note,
          isVisible: account.isVisible,
          isActive: account.isActive,
          createdAt: account.createdAt,
          updatedAt: DateTime.now(),
        );
        await _accountDao.updateAccount(updatedAccount, executor: txn);
      }

      return await _transactionDao.deleteTransaction(
        transactionId,
        executor: txn,
      );
    });
  }

  Future<app_models.Transaction?> getTransaction(int transactionId) {
    return _transactionDao.getTransaction(transactionId);
  }

  Future<List<app_models.Transaction>> getAllTransactions() {
    return _transactionDao.getAllTransactions();
  }

  Future<List<app_models.Transaction>> getTransactionsByType(String type) {
    return _transactionDao.getTransactionsByType(type);
  }

  Future<List<app_models.Transaction>> getTransactionsByAccount(int accountId) {
    return _transactionDao.getTransactionsByAccount(accountId);
  }
  
  Future<List<app_models.Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return _transactionDao.getTransactionsByDateRange(start, end);
  }
}
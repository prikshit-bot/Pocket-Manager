import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocket_manager/services/account_service.dart';
import 'package:pocket_manager/models/account_model.dart';
import 'package:pocket_manager/database/database_helper.dart';
import 'package:pocket_manager/services/category_service.dart';
import 'package:pocket_manager/services/transaction_service.dart';
import 'package:pocket_manager/models/transaction_model.dart' as app_models;
import 'package:pocket_manager/services/transfer_service.dart';
import 'package:pocket_manager/services/goal_service.dart';
import 'package:pocket_manager/services/home_service.dart';
import 'package:pocket_manager/models/transfer_model.dart';
import 'package:pocket_manager/models/goal_model.dart';
import 'package:pocket_manager/services/app_setting_service.dart';
import 'package:pocket_manager/services/backup_service.dart';

import 'package:pocket_manager/services/security_service.dart';
import 'dart:io';
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper().resetForTesting();
  });

  tearDown(() async {
    await DatabaseHelper().resetForTesting();
  });

  group('Database', () {
    test('database creates all required tables', () async {
      final db = await DatabaseHelper().database;

      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' "
        "ORDER BY name",
      );

      final tables = result
          .map((row) => row['name'] as String)
          .toSet();

      expect(
        tables,
        containsAll({
          'accounts',
          'categories',
          'transactions',
          'transfers',
          'goals',
          'goal_contributions',
          'app_settings',
        }),
      );
    });
  });

  group('Accounts', () {
    late AccountService accountService;

    setUp(() {
      accountService = AccountService();
    });

    test('creates and reads an account', () async {
      final id = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      final account = await accountService.getAccount(id);

      expect(account, isNotNull);
      expect(account!.accountId, id);
      expect(account.name, 'Cash');
      expect(account.type, 'Cash');
      expect(account.balance, 10000);
      expect(account.isVisible, true);
      expect(account.isActive, true);
    });

    test('creates multiple accounts and calculates total balance', () async {
      await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      await accountService.createAccount(
        name: 'Bank',
        type: 'Bank',
        openingBalance: 5000,
      );

      expect(await accountService.getTotalBalance(), 15000);
      expect(await accountService.getTotalReserved(), 0);
      expect(await accountService.getLiquidBalance(), 15000);
    });

    test('available balance equals account balance when nothing is reserved', () async {
      final id = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      expect(await accountService.getAvailableBalance(id), 10000);
    });

    test('updates account details without changing balance', () async {
      final id = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      final original = await accountService.getAccount(id);

      final updated = Account(
        accountId: id,
        name: 'My Cash',
        type: 'Cash',
        balance: 99999,
        note: 'Updated account',
        isVisible: false,
        isActive: false,
        createdAt: original!.createdAt,
        updatedAt: DateTime.now(),
      );

      await accountService.updateAccount(updated);

      final result = await accountService.getAccount(id);

      expect(result, isNotNull);
      expect(result!.name, 'My Cash');
      expect(result.note, 'Updated account');
      expect(result.isVisible, false);
      expect(result.isActive, false);

      expect(result.balance, 10000);
    });

    test('gets only visible accounts', () async {
      await accountService.createAccount(
        name: 'Visible',
        type: 'Cash',
        openingBalance: 1000,
      );

      await accountService.createAccount(
        name: 'Hidden',
        type: 'Bank',
        openingBalance: 2000,
        isVisible: false,
      );

      final visible = await accountService.getVisibleAccounts();

      expect(visible.length, 1);
      expect(visible.first.name, 'Visible');
    });

    test('gets only active accounts', () async {
      await accountService.createAccount(
        name: 'Active',
        type: 'Cash',
        openingBalance: 1000,
      );

      await accountService.createAccount(
        name: 'Inactive',
        type: 'Bank',
        openingBalance: 2000,
        isActive: false,
      );

      final active = await accountService.getActiveAccounts();

      expect(active.length, 1);
      expect(active.first.name, 'Active');
    });

    test('rejects invalid account data', () async {
      expect(
        () => accountService.createAccount(
          name: '',
          type: 'Cash',
        ),
        throwsException,
      );

      expect(
        () => accountService.createAccount(
          name: 'Invalid',
          type: 'InvalidType',
        ),
        throwsException,
      );

      expect(
        () => accountService.createAccount(
          name: 'Negative',
          type: 'Cash',
          openingBalance: -100,
        ),
        throwsException,
      );
    });

    test('cannot delete account with non-zero balance', () async {
      final id = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 1000,
      );

      expect(
        () => accountService.deleteAccount(id),
        throwsException,
      );

      expect(await accountService.getAccount(id), isNotNull);
    });

    test('can delete empty account with no financial records', () async {
      final id = await accountService.createAccount(
        name: 'Empty',
        type: 'Cash',
        openingBalance: 0,
      );

      final result = await accountService.deleteAccount(id);

      expect(result, 1);
      expect(await accountService.getAccount(id), isNull);
    });
  });

    group('Categories', () {
    late CategoryService categoryService;

    setUp(() {
      categoryService = CategoryService();
    });

    test('seeds all default categories', () async {
      await categoryService.seedDefaultCategories();

      final income = await categoryService.getIncomeCategories();
      final expense = await categoryService.getExpenseCategories();

      expect(income.length, 6);
      expect(expense.length, 8);

      expect(income.every((c) => c.isDefault), true);
      expect(expense.every((c) => c.isDefault), true);

      expect(income.map((c) => c.name), containsAll([
        'Salary',
        'Allowance',
        'Freelance',
        'Gift',
        'Refund',
        'Other',
      ]));

      expect(expense.map((c) => c.name), containsAll([
        'Food',
        'Travel',
        'Shopping',
        'Bills',
        'Entertainment',
        'Education',
        'Health',
        'Other',
      ]));
    });

    test('seeding defaults multiple times does not create duplicates', () async {
      await categoryService.seedDefaultCategories();
      await categoryService.seedDefaultCategories();

      final all = await categoryService.getAllCategories();

      expect(all.length, 14);
    });

    test('creates a custom income category', () async {
      final id = await categoryService.createCategory(
        name: 'Pocket Money',
        type: CategoryService.income,
        icon: 'money',
      );

      final category = await categoryService.getCategory(id);

      expect(category, isNotNull);
      expect(category!.name, 'Pocket Money');
      expect(category.type, CategoryService.income);
      expect(category.icon, 'money');
      expect(category.isDefault, false);
      expect(category.isDeleted, false);
    });

    test('creates a custom expense category', () async {
      final id = await categoryService.createCategory(
        name: 'Gaming',
        type: CategoryService.expense,
      );

      final category = await categoryService.getCategory(id);

      expect(category, isNotNull);
      expect(category!.name, 'Gaming');
      expect(category.type, CategoryService.expense);
      expect(category.isDefault, false);
      expect(category.isDeleted, false);
    });

    test('rejects invalid category data', () async {
      expect(
        () => categoryService.createCategory(
          name: '',
          type: CategoryService.income,
        ),
        throwsException,
      );

      expect(
        () => categoryService.createCategory(
          name: 'Test',
          type: 'Invalid',
        ),
        throwsException,
      );
    });

    test('prevents duplicate category names within the same type', () async {
      await categoryService.createCategory(
        name: 'Gaming',
        type: CategoryService.expense,
      );

      expect(
        () => categoryService.createCategory(
          name: 'gaming',
          type: CategoryService.expense,
        ),
        throwsException,
      );
    });

    test('allows same category name for different types', () async {
      final incomeId = await categoryService.createCategory(
        name: 'Bonus',
        type: CategoryService.income,
      );

      final expenseId = await categoryService.createCategory(
        name: 'Bonus',
        type: CategoryService.expense,
      );

      expect(incomeId, isNot(expenseId));

      final income = await categoryService.getCategory(incomeId);
      final expense = await categoryService.getCategory(expenseId);

      expect(income!.type, CategoryService.income);
      expect(expense!.type, CategoryService.expense);
    });

    test('updates a custom category', () async {
      final id = await categoryService.createCategory(
        name: 'Old Name',
        type: CategoryService.expense,
      );

      final result = await categoryService.updateCategory(
        categoryId: id,
        name: 'New Name',
        icon: 'new_icon',
      );

      expect(result, 1);

      final category = await categoryService.getCategory(id);

      expect(category!.name, 'New Name');
      expect(category.icon, 'new_icon');
      expect(category.type, CategoryService.expense);
    });

    test('prevents editing default categories', () async {
      await categoryService.seedDefaultCategories();

      final categories = await categoryService.getIncomeCategories();
      final salary = categories.firstWhere((c) => c.name == 'Salary');

      expect(
        () => categoryService.updateCategory(
          categoryId: salary.categoryId!,
          name: 'My Salary',
        ),
        throwsException,
      );
    });

    test('prevents deleting default categories', () async {
      await categoryService.seedDefaultCategories();

      final categories = await categoryService.getExpenseCategories();
      final food = categories.firstWhere((c) => c.name == 'Food');

      expect(
        () => categoryService.deleteCategory(food.categoryId!),
        throwsException,
      );

      final result = await categoryService.getCategory(food.categoryId!);

      expect(result, isNotNull);
      expect(result!.isDeleted, false);
    });

    test('soft deletes a custom category', () async {
      final id = await categoryService.createCategory(
        name: 'Temporary',
        type: CategoryService.expense,
      );

      final result = await categoryService.deleteCategory(id);

      expect(result, 1);

      final category = await categoryService.getCategory(id);

      expect(category, isNotNull);
      expect(category!.isDeleted, true);

      final expenseCategories =
          await categoryService.getExpenseCategories();

      expect(
        expenseCategories.any((c) => c.categoryId == id),
        false,
      );
    });

    test('deleting an already deleted category does nothing', () async {
      final id = await categoryService.createCategory(
        name: 'Temporary',
        type: CategoryService.expense,
      );

      await categoryService.deleteCategory(id);

      final result = await categoryService.deleteCategory(id);

      expect(result, 0);
    });
  });

    group('Transactions', () {
    late AccountService accountService;
    late CategoryService categoryService;
    late TransactionService transactionService;

    late int accountId;
    late int incomeCategoryId;
    late int expenseCategoryId;

    setUp(() async {
      accountService = AccountService();
      categoryService = CategoryService();
      transactionService = TransactionService();

      accountId = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      await categoryService.seedDefaultCategories();

      final incomeCategories =
          await categoryService.getIncomeCategories();
      final expenseCategories =
          await categoryService.getExpenseCategories();

      incomeCategoryId =
          incomeCategories.firstWhere((c) => c.name == 'Salary').categoryId!;

      expenseCategoryId =
          expenseCategories.firstWhere((c) => c.name == 'Food').categoryId!;
    });

    app_models.Transaction makeTransaction({
      required String type,
      required double amount,
      required int categoryId,
      int? accountIdOverride,
      DateTime? date,
      String? note,
    }) {
      final now = DateTime.now();

      return app_models.Transaction(
        type: type,
        amount: amount,
        accountId: accountIdOverride ?? accountId,
        categoryId: categoryId,
        date: date ?? now,
        note: note,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('creates income and increases account balance', () async {
      final id = await transactionService.createTransaction(
        makeTransaction(
          type: 'Income',
          amount: 2000,
          categoryId: incomeCategoryId,
        ),
      );

      expect(id, greaterThan(0));

      final account = await accountService.getAccount(accountId);

      expect(account!.balance, 12000);
    });

    test('creates expense and decreases account balance', () async {
      final id = await transactionService.createTransaction(
        makeTransaction(
          type: 'Expense',
          amount: 2500,
          categoryId: expenseCategoryId,
        ),
      );

      expect(id, greaterThan(0));

      final account = await accountService.getAccount(accountId);

      expect(account!.balance, 7500);
    });

    test('rejects zero and negative amounts', () async {
      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Income',
            amount: 0,
            categoryId: incomeCategoryId,
          ),
        ),
        throwsException,
      );

      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Income',
            amount: -100,
            categoryId: incomeCategoryId,
          ),
        ),
        throwsException,
      );
    });

    test('rejects invalid transaction type', () async {
      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Transfer',
            amount: 100,
            categoryId: incomeCategoryId,
          ),
        ),
        throwsException,
      );
    });

    test('rejects category with wrong transaction type', () async {
      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Expense',
            amount: 100,
            categoryId: incomeCategoryId,
          ),
        ),
        throwsException,
      );
    });

    test('rejects transaction on inactive account', () async {
      await accountService.setActive(accountId, false);

      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Income',
            amount: 100,
            categoryId: incomeCategoryId,
          ),
        ),
        throwsException,
      );
    });

    test('rejects expense greater than available balance', () async {
      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Expense',
            amount: 10001,
            categoryId: expenseCategoryId,
          ),
        ),
        throwsException,
      );

      final account = await accountService.getAccount(accountId);
      expect(account!.balance, 10000);
    });

    test('updates an income transaction and adjusts balance', () async {
      final transaction = makeTransaction(
        type: 'Income',
        amount: 2000,
        categoryId: incomeCategoryId,
      );

      final id = await transactionService.createTransaction(transaction);

      final updated = app_models.Transaction(
        transactionId: id,
        type: 'Income',
        amount: 3500,
        accountId: accountId,
        categoryId: incomeCategoryId,
        date: transaction.date,
        note: 'Updated income',
        createdAt: transaction.createdAt,
        updatedAt: DateTime.now(),
      );

      await transactionService.updateTransaction(updated);

      final account = await accountService.getAccount(accountId);

      expect(account!.balance, 13500);
    });

    test('updates an expense transaction and adjusts balance', () async {
      final transaction = makeTransaction(
        type: 'Expense',
        amount: 2000,
        categoryId: expenseCategoryId,
      );

      final id = await transactionService.createTransaction(transaction);

      final updated = app_models.Transaction(
        transactionId: id,
        type: 'Expense',
        amount: 3500,
        accountId: accountId,
        categoryId: expenseCategoryId,
        date: transaction.date,
        note: 'Updated expense',
        createdAt: transaction.createdAt,
        updatedAt: DateTime.now(),
      );

      await transactionService.updateTransaction(updated);

      final account = await accountService.getAccount(accountId);

      expect(account!.balance, 6500);
    });

    test('moves a transaction to another account when updated', () async {
      final secondAccountId = await accountService.createAccount(
        name: 'Bank',
        type: 'Bank',
        openingBalance: 5000,
      );

      final transaction = makeTransaction(
        type: 'Expense',
        amount: 2000,
        categoryId: expenseCategoryId,
      );

      final id = await transactionService.createTransaction(transaction);

      final updated = app_models.Transaction(
        transactionId: id,
        type: 'Expense',
        amount: 1500,
        accountId: secondAccountId,
        categoryId: expenseCategoryId,
        date: transaction.date,
        note: transaction.note,
        createdAt: transaction.createdAt,
        updatedAt: DateTime.now(),
      );

      await transactionService.updateTransaction(updated);

      final oldAccount = await accountService.getAccount(accountId);
      final newAccount = await accountService.getAccount(secondAccountId);

      expect(oldAccount!.balance, 10000);
      expect(newAccount!.balance, 3500);
    });

    test('deletes income and reverses account balance', () async {
      final id = await transactionService.createTransaction(
        makeTransaction(
          type: 'Income',
          amount: 2000,
          categoryId: incomeCategoryId,
        ),
      );

      expect((await accountService.getAccount(accountId))!.balance, 12000);

      final result = await transactionService.deleteTransaction(id);

      expect(result, 1);
      expect((await accountService.getAccount(accountId))!.balance, 10000);
    });

    test('deletes expense and reverses account balance', () async {
      final id = await transactionService.createTransaction(
        makeTransaction(
          type: 'Expense',
          amount: 2000,
          categoryId: expenseCategoryId,
        ),
      );

      expect((await accountService.getAccount(accountId))!.balance, 8000);

      final result = await transactionService.deleteTransaction(id);

      expect(result, 1);
      expect((await accountService.getAccount(accountId))!.balance, 10000);
    });

    test('transaction on deleted category is rejected', () async {
      final categoryId = await categoryService.createCategory(
        name: 'Temporary',
        type: CategoryService.expense,
      );

      await categoryService.deleteCategory(categoryId);

      expect(
        () => transactionService.createTransaction(
          makeTransaction(
            type: 'Expense',
            amount: 100,
            categoryId: categoryId,
          ),
        ),
        throwsException,
      );
    });

    test('monthly transaction dates are stored correctly', () async {
      final date = DateTime(2026, 9, 15);

      final id = await transactionService.createTransaction(
        makeTransaction(
          type: 'Income',
          amount: 3000,
          categoryId: incomeCategoryId,
          date: date,
        ),
      );

      expect(id, greaterThan(0));
    });
  });

    group('Transfers', () {
    late AccountService accountService;
    late TransferService transferService;

    late int cashId;
    late int bankId;

    setUp(() async {
      accountService = AccountService();
      transferService = TransferService();

      cashId = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      bankId = await accountService.createAccount(
        name: 'Bank',
        type: 'Bank',
        openingBalance: 5000,
      );
    });

    Transfer makeTransfer({
      required double amount,
      int? from,
      int? to,
    }) {
      final now = DateTime.now();

      return Transfer(
        amount: amount,
        fromAccountId: from ?? cashId,
        toAccountId: to ?? bankId,
        date: now,
        note: 'Test transfer',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('creates transfer and updates both balances', () async {
      final id = await transferService.createTransfer(
        makeTransfer(amount: 3000),
      );

      expect(id, greaterThan(0));

      expect(
        (await accountService.getAccount(cashId))!.balance,
        7000,
      );
      expect(
        (await accountService.getAccount(bankId))!.balance,
        8000,
      );
    });

    test('transfer does not change total balance', () async {
      expect(await accountService.getTotalBalance(), 15000);

      await transferService.createTransfer(
        makeTransfer(amount: 3000),
      );

      expect(await accountService.getTotalBalance(), 15000);
    });

    test('rejects invalid transfer amount', () async {
      expect(
        () => transferService.createTransfer(
          makeTransfer(amount: 0),
        ),
        throwsException,
      );

      expect(
        () => transferService.createTransfer(
          makeTransfer(amount: -100),
        ),
        throwsException,
      );
    });

    test('rejects same source and destination', () async {
      expect(
        () => transferService.createTransfer(
          makeTransfer(
            amount: 100,
            from: cashId,
            to: cashId,
          ),
        ),
        throwsException,
      );
    });

    test('rejects insufficient available balance', () async {
      expect(
        () => transferService.createTransfer(
          makeTransfer(amount: 10001),
        ),
        throwsException,
      );

      expect(
        (await accountService.getAccount(cashId))!.balance,
        10000,
      );
    });

    test('rejects inactive account', () async {
      await accountService.setActive(bankId, false);

      expect(
        () => transferService.createTransfer(
          makeTransfer(amount: 1000),
        ),
        throwsException,
      );
    });

    test('updates transfer correctly', () async {
      final id = await transferService.createTransfer(
        makeTransfer(amount: 2000),
      );

      final old = await transferService.getTransfer(id);

      final updated = Transfer(
        transferId: id,
        amount: 3500,
        fromAccountId: cashId,
        toAccountId: bankId,
        date: old!.date,
        note: 'Updated',
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );

      await transferService.updateTransfer(updated);

      expect(
        (await accountService.getAccount(cashId))!.balance,
        6500,
      );
      expect(
        (await accountService.getAccount(bankId))!.balance,
        8500,
      );
    });

    test('deletes transfer and reverses balances', () async {
      final id = await transferService.createTransfer(
        makeTransfer(amount: 3000),
      );

      await transferService.deleteTransfer(id);

      expect(
        (await accountService.getAccount(cashId))!.balance,
        10000,
      );
      expect(
        (await accountService.getAccount(bankId))!.balance,
        5000,
      );
    });
  });

    group('Goals', () {
    late AccountService accountService;
    late GoalService goalService;

    late int accountId;
    late int goalId;

    setUp(() async {
      accountService = AccountService();
      goalService = GoalService();

      accountId = await accountService.createAccount(
        name: 'Savings',
        type: 'Savings',
        openingBalance: 10000,
      );

      goalId = await goalService.createGoal(
        name: 'New Laptop',
        targetAmount: 5000,
      );
    });

    test('creates active goal with zero saved amount', () async {
      final goal = await goalService.getGoal(goalId);

      expect(goal, isNotNull);
      expect(goal!.name, 'New Laptop');
      expect(goal.targetAmount, 5000);
      expect(goal.savedAmount, 0);
      expect(goal.status, GoalService.active);
    });

    test('adds money to goal without changing account balance', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 3000,
      );

      final goal = await goalService.getGoal(goalId);
      final account = await accountService.getAccount(accountId);

      expect(goal!.savedAmount, 3000);
      expect(goal.status, GoalService.active);

      // Reserved money is still part of actual account balance.
      expect(account!.balance, 10000);

      expect(
        await accountService.getAvailableBalance(accountId),
        7000,
      );
    });

    test('shows sufficient money without completing the goal', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 5000,
      );

      final goal = await goalService.getGoal(goalId);

      expect(goal!.savedAmount, 5000);
      expect(goal.status, GoalService.active);
    });

    test('rejects contribution greater than available balance', () async {
      expect(
        () => goalService.addMoney(
          goalId: goalId,
          accountId: accountId,
          amount: 10001,
        ),
        throwsException,
      );

      final goal = await goalService.getGoal(goalId);

      expect(goal!.savedAmount, 0);
    });

    test('withdraws goal money using negative contribution', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 3000,
      );

      final contributionId = await goalService.withdrawMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 1000,
      );

      expect(contributionId, greaterThan(0));

      final goal = await goalService.getGoal(goalId);

      expect(goal!.savedAmount, 2000);

      final contributions =
          await goalService.getContributionsForGoal(goalId);

      expect(
        contributions.any((c) => c.amount == -1000),
        true,
      );

      expect(
        await accountService.getAvailableBalance(accountId),
        8000,
      );
    });

    test('cannot withdraw more than goal saved amount', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 2000,
      );

      expect(
        () => goalService.withdrawMoney(
          goalId: goalId,
          accountId: accountId,
          amount: 2001,
        ),
        throwsException,
      );
    });

    test('sufficient goal remains active after withdrawal below target',
        () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 5000,
      );

      expect(
        (await goalService.getGoal(goalId))!.status,
        GoalService.active,
      );

      await goalService.withdrawMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 1000,
      );

      final goal = await goalService.getGoal(goalId);

      expect(goal!.savedAmount, 4000);
      expect(goal.status, GoalService.active);
    });

    test('completed goal remains reserved', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 5000,
      );

      expect(
        await accountService.getAvailableBalance(accountId),
        5000,
      );
    });

    test('cancelled goal keeps its reserved money', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 3000,
      );

      await goalService.cancelGoal(goalId);

      final goal = await goalService.getGoal(goalId);

      expect(goal!.status, GoalService.cancelled);
      expect(goal.savedAmount, 3000);

      // Option B: cancellation does NOT release money.
      expect(
        await accountService.getAvailableBalance(accountId),
        7000,
      );
    });

    test('explicit withdrawal releases cancelled goal money', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 3000,
      );

      await goalService.cancelGoal(goalId);

      await goalService.withdrawMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 3000,
      );

      final goal = await goalService.getGoal(goalId);

      expect(goal!.savedAmount, 0);

      expect(
        await accountService.getAvailableBalance(accountId),
        10000,
      );
    });

    test('rejects contribution to cancelled goal', () async {
      await goalService.cancelGoal(goalId);

      expect(
        () => goalService.addMoney(
          goalId: goalId,
          accountId: accountId,
          amount: 1000,
        ),
        throwsException,
      );
    });

    test('updates goal details without changing saved amount', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 2000,
      );

      final existing = await goalService.getGoal(goalId);

      await goalService.updateGoal(
        Goal(
          goalId: goalId,
          name: 'Gaming Laptop',
          targetAmount: 6000,
          savedAmount: 99999,
          targetDate: DateTime(2027, 1, 1),
          note: 'Updated goal',
          status: GoalService.active,
          createdAt: existing!.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      final updated = await goalService.getGoal(goalId);

      expect(updated!.name, 'Gaming Laptop');
      expect(updated.targetAmount, 6000);
      expect(updated.savedAmount, 2000);
      expect(updated.note, 'Updated goal');
    });

    test('lowering target to saved amount keeps goal active', () async {
      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 3000,
      );

      final existing = await goalService.getGoal(goalId);

      await goalService.updateGoal(
        Goal(
          goalId: goalId,
          name: existing!.name,
          targetAmount: 3000,
          savedAmount: 0,
          targetDate: existing.targetDate,
          note: existing.note,
          status: GoalService.active,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      final updated = await goalService.getGoal(goalId);

      expect(updated!.status, GoalService.active);
      expect(updated.savedAmount, 3000);
    });
  });

    group('HomeService', () {
    late AccountService accountService;
    late CategoryService categoryService;
    late TransactionService transactionService;
    late GoalService goalService;
    late HomeService homeService;

    late int accountId;
    late int incomeCategoryId;
    late int expenseCategoryId;

    setUp(() async {
      accountService = AccountService();
      categoryService = CategoryService();
      transactionService = TransactionService();
      goalService = GoalService();
      homeService = HomeService();

      accountId = await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 10000,
      );

      await categoryService.seedDefaultCategories();

      final incomeCategories =
          await categoryService.getIncomeCategories();

      final expenseCategories =
          await categoryService.getExpenseCategories();

      incomeCategoryId =
          incomeCategories.firstWhere((c) => c.name == 'Salary').categoryId!;

      expenseCategoryId =
          expenseCategories.firstWhere((c) => c.name == 'Food').categoryId!;
    });

    test('returns correct home summary', () async {
      final now = DateTime.now();

      await transactionService.createTransaction(
        app_models.Transaction(
          type: 'Income',
          amount: 5000,
          accountId: accountId,
          categoryId: incomeCategoryId,
          date: now,
          note: 'Salary',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await transactionService.createTransaction(
        app_models.Transaction(
          type: 'Expense',
          amount: 2000,
          accountId: accountId,
          categoryId: expenseCategoryId,
          date: now,
          note: 'Food',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goalId = await goalService.createGoal(
        name: 'Phone',
        targetAmount: 3000,
      );

      await goalService.addMoney(
        goalId: goalId,
        accountId: accountId,
        amount: 1500,
      );

      final summary = await homeService.getHomeSummary();

      expect(summary.totalBalance, 11500);
      expect(summary.totalReserved, 0);
      expect(summary.availableBalance, 11500);

      expect(summary.monthlyIncome, 5000);
      expect(summary.monthlyExpense, 2000);
      expect(summary.monthlyNet, 3000);

      expect(summary.recentTransactions.length, 2);
      expect(summary.goals.length, 1);
      expect(summary.goals.first.name, 'Phone');
    });

    test('respects recent transaction limit', () async {
      final now = DateTime.now();

      for (var i = 0; i < 5; i++) {
        await transactionService.createTransaction(
          app_models.Transaction(
            type: 'Income',
            amount: 100,
            accountId: accountId,
            categoryId: incomeCategoryId,
            date: now,
            note: 'Transaction $i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final summary = await homeService.getHomeSummary(
        recentTransactionsLimit: 3,
      );

      expect(summary.recentTransactions.length, 3);
    });

    test('respects goal preview limit', () async {
      for (var i = 0; i < 5; i++) {
        await goalService.createGoal(
          name: 'Goal $i',
          targetAmount: 1000,
        );
      }

      final summary = await homeService.getHomeSummary(
        goalsPreviewLimit: 2,
      );

      expect(summary.goals.length, 2);
    });

    test('only active goals appear in home preview', () async {
      final activeGoal = await goalService.createGoal(
        name: 'Active Goal',
        targetAmount: 1000,
      );

      final completedGoal = await goalService.createGoal(
        name: 'Completed Goal',
        targetAmount: 1000,
      );

      await goalService.addMoney(
        goalId: completedGoal,
        accountId: accountId,
        amount: 1000,
      );

      final cancelledGoal = await goalService.createGoal(
        name: 'Cancelled Goal',
        targetAmount: 1000,
      );

      await goalService.cancelGoal(cancelledGoal);

      final summary = await homeService.getHomeSummary();

      expect(
        summary.goals.any((g) => g.goalId == activeGoal),
        true,
      );

      expect(
        summary.goals.any((g) => g.goalId == completedGoal),
        true,
      );

      expect(
        summary.goals.any((g) => g.goalId == cancelledGoal),
        false,
      );
    });
  });

    group('App Settings', () {
    late AppSettingService settingService;

    setUp(() {
      settingService = AppSettingService();
    });

    test('returns default currency', () async {
      expect(await settingService.getCurrency(), 'INR');
    });

    test('returns default theme', () async {
      expect(await settingService.getTheme(), 'system');
    });

    test('stores and retrieves string setting', () async {
      await settingService.setString('test_key', 'test_value');

      expect(
        await settingService.getString('test_key'),
        'test_value',
      );
    });

    test('updates existing string setting', () async {
      await settingService.setString('test_key', 'first');
      await settingService.setString('test_key', 'second');

      expect(
        await settingService.getString('test_key'),
        'second',
      );
    });

    test('stores and retrieves boolean setting', () async {
      await settingService.setBool('test_bool', true);

      expect(
        await settingService.getBool('test_bool'),
        true,
      );

      await settingService.setBool('test_bool', false);

      expect(
        await settingService.getBool('test_bool'),
        false,
      );
    });

    test('returns default value for missing boolean setting', () async {
      expect(
        await settingService.getBool(
          'missing_bool',
          defaultValue: true,
        ),
        true,
      );
    });

    test('updates currency', () async {
      await settingService.setCurrency('USD');

      expect(
        await settingService.getCurrency(),
        'USD',
      );
    });

    test('updates theme', () async {
      await settingService.setTheme('dark');

      expect(
        await settingService.getTheme(),
        'dark',
      );
    });

    test('PIN and biometric settings work', () async {
      expect(await settingService.isPinEnabled(), false);
      expect(await settingService.isBiometricEnabled(), false);

      await settingService.setPinEnabled(true);
      await settingService.setBiometricEnabled(true);

      expect(await settingService.isPinEnabled(), true);
      expect(await settingService.isBiometricEnabled(), true);

      await settingService.setPinEnabled(false);
      await settingService.setBiometricEnabled(false);

      expect(await settingService.isPinEnabled(), false);
      expect(await settingService.isBiometricEnabled(), false);
    });

    test('returns all settings', () async {
      await settingService.setCurrency('USD');
      await settingService.setTheme('dark');

      final settings = await settingService.getAllSettings();

      expect(settings.length, greaterThanOrEqualTo(2));
      expect(
        settings.any((s) => s.key == SettingKeys.currency),
        true,
      );
      expect(
        settings.any((s) => s.key == SettingKeys.theme),
        true,
      );
    });
  });

    group('Security', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    test('PIN is disabled initially', () async {
      expect(
        await securityService.isPinEnabled(),
        false,
      );
    });

    test('sets valid 4 digit PIN', () async {
      await securityService.setPin('1234');

      expect(
        await securityService.isPinEnabled(),
        true,
      );

      expect(
        await securityService.verifyPin('1234'),
        true,
      );

      expect(
        await securityService.verifyPin('4321'),
        false,
      );
    });

    test('sets valid 6 digit PIN', () async {
      await securityService.setPin('123456');

      expect(
        await securityService.verifyPin('123456'),
        true,
      );
    });

    test('rejects invalid PIN formats', () async {
      expect(
        () => securityService.setPin('123'),
        throwsException,
      );

      expect(
        () => securityService.setPin('12345'),
        throwsException,
      );

      expect(
        () => securityService.setPin('1234567'),
        throwsException,
      );

      expect(
        () => securityService.setPin('12ab'),
        throwsException,
      );

      expect(
        () => securityService.setPin(''),
        throwsException,
      );
    });

    test('changing PIN requires correct old PIN', () async {
      await securityService.setPin('1234');

      expect(
        () => securityService.changePin('9999', '5678'),
        throwsException,
      );

      expect(
        await securityService.verifyPin('1234'),
        true,
      );
    });

    test('changes PIN with correct old PIN', () async {
      await securityService.setPin('1234');

      await securityService.changePin(
        '1234',
        '5678',
      );

      expect(
        await securityService.verifyPin('1234'),
        false,
      );

      expect(
        await securityService.verifyPin('5678'),
        true,
      );
    });

    test('disabling PIN disables PIN lock', () async {
      await securityService.setPin('1234');

      await securityService.disablePin();

      expect(
        await securityService.isPinEnabled(),
        false,
      );
    });

    test('disabled PIN cannot be verified', () async {
      await securityService.setPin('1234');

      await securityService.disablePin();

      expect(
        await securityService.verifyPin('1234'),
        false,
      );
    });

    test('biometric cannot be enabled without PIN', () async {
      expect(
        () => securityService.setBiometricEnabled(true),
        throwsException,
      );

      expect(
        await securityService.isBiometricEnabled(),
        false,
      );
    });

    test('biometric can be enabled when PIN is enabled', () async {
      await securityService.setPin('1234');

      await securityService.setBiometricEnabled(true);

      expect(
        await securityService.isBiometricEnabled(),
        true,
      );
    });

    test('biometric can be disabled', () async {
      await securityService.setPin('1234');

      await securityService.setBiometricEnabled(true);
      await securityService.setBiometricEnabled(false);

      expect(
        await securityService.isBiometricEnabled(),
        false,
      );
    });

    test('setting a new PIN replaces the previous PIN', () async {
      await securityService.setPin('1234');
      await securityService.setPin('5678');

      expect(
        await securityService.verifyPin('1234'),
        false,
      );

      expect(
        await securityService.verifyPin('5678'),
        true,
      );
    });
  });

    group('Backup and Restore', () {
    late BackupService backupService;

    late AccountService accountService;

    late String backupPath;

    setUp(() async {
      backupService = BackupService();
      accountService = AccountService();

      final tempDir = Directory.systemTemp.createTempSync('manager_test_');
      backupPath = '${tempDir.path}/manager_backup.json';
    });

    tearDown(() async {
      final file = File(backupPath);

      if (await file.exists()) {
        await file.delete();
      }

      final directory = file.parent;

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('exports database to JSON file', () async {
      await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 5000,
      );

      await backupService.exportToFile(backupPath);

      final file = File(backupPath);

      expect(
        await file.exists(),
        true,
      );

      final content = await file.readAsString();

      expect(content.contains('"version":"1"'), true);
      expect(content.contains('"data"'), true);
      expect(content.contains('accounts'), true);
    });

    test('export contains database tables', () async {
      await backupService.exportToFile(backupPath);

      final content = await File(backupPath).readAsString();

      expect(content.contains('accounts'), true);
      expect(content.contains('categories'), true);
      expect(content.contains('transactions'), true);
      expect(content.contains('transfers'), true);
      expect(content.contains('goals'), true);
      expect(content.contains('goal_contributions'), true);
      expect(content.contains('app_settings'), true);
    });

    test('restore restores account data', () async {
      await accountService.createAccount(
        name: 'Cash',
        type: 'Cash',
        openingBalance: 5000,
      );

      await backupService.exportToFile(backupPath);

      await accountService.createAccount(
        name: 'Bank',
        type: 'Bank',
        openingBalance: 10000,
      );

      expect(
        (await accountService.getAllAccounts()).length,
        2,
      );

      await backupService.restoreFromFile(backupPath);

      final accounts = await accountService.getAllAccounts();

      expect(accounts.length, 1);
      expect(accounts.first.name, 'Cash');
      expect(accounts.first.balance, 5000);
    });

    test('restore replaces existing data', () async {
      await accountService.createAccount(
        name: 'Original',
        type: 'Cash',
        openingBalance: 1000,
      );

      await backupService.exportToFile(backupPath);

      await accountService.createAccount(
        name: 'Extra',
        type: 'Bank',
        openingBalance: 2000,
      );

      await backupService.restoreFromFile(backupPath);

      final accounts = await accountService.getAllAccounts();

      expect(accounts.length, 1);
      expect(accounts.first.name, 'Original');
      expect(accounts.first.balance, 1000);
    });

    test('restore fails when backup file does not exist', () async {
      expect(
        () => backupService.restoreFromFile(
          '${backupPath}_missing',
        ),
        throwsException,
      );
    });

    test('restore rejects unsupported backup version', () async {
      final file = File(backupPath);

      await file.writeAsString(
        '''
{
  "version": "999",
  "exportedAt": "2026-01-01T00:00:00.000",
  "data": {}
}
''',
      );

      expect(
        () => backupService.restoreFromFile(backupPath),
        throwsException,
      );
    });
  });
}

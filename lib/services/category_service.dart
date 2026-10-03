import '../database/database_helper.dart';
import '../database/category_dao.dart';
import '../models/category_model.dart';

class CategoryService {
  static const String income = 'Income';
  static const String expense = 'Expense';

  // name -> icon reference
  static const Map<String, String> _defaultIncome = {
    'Salary': 'payments',
    'Allowance': 'account_balance_wallet',
    'Freelance': 'work',
    'Gift': 'card_giftcard',
    'Refund': 'replay',
    'Other': 'category',
  };

  static const Map<String, String> _defaultExpense = {
    'Food': 'restaurant',
    'Travel': 'flight',
    'Shopping': 'shopping_bag',
    'Bills': 'receipt_long',
    'Entertainment': 'movie',
    'Education': 'school',
    'Health': 'favorite',
    'Other': 'category',
  };

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CategoryDao _categoryDao = CategoryDao();

  // Inserts any missing predefined categories. Safe to call on every app start.
  Future<void> seedDefaultCategories() async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final existing = await _categoryDao.getAllCategories(executor: txn);

      bool hasDefault(String name, String type) {
        return existing.any(
          (c) => c.isDefault && c.name == name && c.type == type,
        );
      }

      final now = DateTime.now();

      Future<void> seed(Map<String, String> defaults, String type) async {
        for (final entry in defaults.entries) {
          if (!hasDefault(entry.key, type)) {
            await _categoryDao.insertCategory(
              Category(
                name: entry.key,
                type: type,
                icon: entry.value,
                isDefault: true,
                isDeleted: false,
                createdAt: now,
                updatedAt: now,
              ),
              executor: txn,
            );
          }
        }
      }

      await seed(_defaultIncome, income);
      await seed(_defaultExpense, expense);
    });
  }

  Future<int> createCategory({
    required String name,
    required String type,
    String? icon,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Category name is required.');
    }
    if (type != income && type != expense) {
      throw Exception('Invalid category type.');
    }

    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final sameType = await _categoryDao.getCategoriesByType(
        type,
        executor: txn,
      );
      final duplicate = sameType.any(
        (c) => c.name.toLowerCase() == trimmedName.toLowerCase(),
      );
      if (duplicate) {
        throw Exception('A $type category with this name already exists.');
      }

      final now = DateTime.now();
      return await _categoryDao.insertCategory(
        Category(
          name: trimmedName,
          type: type,
          icon: icon,
          isDefault: false,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        executor: txn,
      );
    });
  }

  // Only custom (non-default) categories can be edited. Type cannot change.
  Future<int> updateCategory({
    required int categoryId,
    required String name,
    String? icon,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Category name is required.');
    }

    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final existing = await _categoryDao.getCategory(
        categoryId,
        executor: txn,
      );
      if (existing == null) {
        throw Exception('Category not found.');
      }
      if (existing.isDeleted) {
        throw Exception('Category has been deleted.');
      }
      if (existing.isDefault) {
        throw Exception('Predefined categories cannot be renamed.');
      }

      final sameType = await _categoryDao.getCategoriesByType(
        existing.type,
        executor: txn,
      );
      final duplicate = sameType.any(
        (c) =>
            c.categoryId != existing.categoryId &&
            c.name.toLowerCase() == trimmedName.toLowerCase(),
      );
      if (duplicate) {
        throw Exception(
          'A ${existing.type} category with this name already exists.',
        );
      }

      return await _categoryDao.updateCategory(
        Category(
          categoryId: existing.categoryId,
          name: trimmedName,
          type: existing.type,
          icon: icon,
          isDefault: existing.isDefault,
          isDeleted: existing.isDeleted,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
        executor: txn,
      );
    });
  }

  // Soft delete. Existing transactions keep showing the historical category.
  Future<int> deleteCategory(int categoryId) async {
    final db = await _databaseHelper.database;

    return await db.transaction<int>((txn) async {
      final existing = await _categoryDao.getCategory(
        categoryId,
        executor: txn,
      );
      if (existing == null) {
        throw Exception('Category not found.');
      }
      if (existing.isDeleted) {
        return 0;
      }
      if (existing.isDefault) {
        throw Exception('Predefined categories cannot be deleted.');
      }

      return await _categoryDao.deleteCategory(categoryId, executor: txn);
    });
  }

  Future<Category?> getCategory(int categoryId) {
    return _categoryDao.getCategory(categoryId);
  }

  Future<List<Category>> getAllCategories() {
    return _categoryDao.getAllCategories();
  }

  Future<List<Category>> getIncomeCategories() {
    return _categoryDao.getCategoriesByType(income);
  }

  Future<List<Category>> getExpenseCategories() {
    return _categoryDao.getCategoriesByType(expense);
  }
}
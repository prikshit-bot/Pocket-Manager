// category_dao.dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/category_model.dart';

class CategoryDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(Category category) {
    return {
      'category_id': category.categoryId,
      'name': category.name,
      'type': category.type,
      'icon': category.icon,
      'is_default': category.isDefault ? 1 : 0,
      'is_deleted': category.isDeleted ? 1 : 0,
      'created_at': category.createdAt.toIso8601String(),
      'updated_at': category.updatedAt.toIso8601String(),
    };
  }

  Category _fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String?,
      isDefault: (map['is_default'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<int> insertCategory(Category category, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final map = _toMap(category);
    map.remove('category_id');
    return await db.insert('categories', map);
  }

  Future<Category?> getCategory(int categoryId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'categories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  Future<List<Category>> getAllCategories({DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'categories',
      where: 'is_deleted = ?',
      whereArgs: [0],
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<List<Category>> getCategoriesByType(String type, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'categories',
      where: 'type = ? AND is_deleted = ?',
      whereArgs: [type, 0],
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  Future<int> updateCategory(Category category, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'categories',
      _toMap(category),
      where: 'category_id = ?',
      whereArgs: [category.categoryId],
    );
  }

  Future<int> deleteCategory(int categoryId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'categories',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }
}
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/app_setting_model.dart';

class AppSettingDao {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return await _databaseHelper.database;
  }

  Map<String, dynamic> _toMap(AppSetting setting) {
    return {
      'setting_id': setting.settingId,
      'key': setting.key,
      'value': setting.value,
      'updated_at': setting.updatedAt.toIso8601String(),
    };
  }

  AppSetting _fromMap(Map<String, dynamic> map) {
    return AppSetting(
      settingId: map['setting_id'] as int?,
      key: map['key'] as String,
      value: map['value'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<int> insertSetting(AppSetting setting, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final map = _toMap(setting);
    map.remove('setting_id');
    return await db.insert('app_settings', map);
  }

  Future<AppSetting?> getSettingByKey(String key, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) {
      return null;
    }

    return _fromMap(results.first);
  }

  Future<List<AppSetting>> getAllSettings({DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final results = await db.query('app_settings', orderBy: 'key ASC');
    return results.map((map) => _fromMap(map)).toList();
  }

  // Updates the value of an existing key.
  Future<int> updateSetting(AppSetting setting, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.update(
      'app_settings',
      {
        'value': setting.value,
        'updated_at': setting.updatedAt.toIso8601String(),
      },
      where: 'key = ?',
      whereArgs: [setting.key],
    );
  }

  Future<int> deleteSetting(String key, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    return await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}
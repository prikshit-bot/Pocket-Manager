import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

class BackupService {
  static const String backupVersion = '1';

  // Tables in an order safe for restore-time deletion (children first)
  // and the reverse order is safe for insertion (parents first).
  static const List<String> _tablesChildFirst = [
    'goal_contributions',
    'transfers',
    'transactions',
    'goals',
    'categories',
    'accounts',
    'app_settings',
  ];

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<String> getDefaultBackupDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory('${directory.path}/backups');
    await backupDirectory.create(recursive: true);
    return backupDirectory.path;
  }

  // Exports all tables into a single JSON file at [filePath].
  // The caller (UI layer) is responsible for letting the user pick filePath.
  Future<void> exportToFile(String filePath) async {
    final db = await _databaseHelper.database;

    final data = <String, dynamic>{};
    for (final table in _tablesChildFirst.reversed) {
      data[table] = await db.query(table);
    }

    final backup = {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };

    final file = File(filePath);
    await file.writeAsString(jsonEncode(backup));
  }

  // Restores all tables from a backup file, replacing existing data.
  // This is destructive: current data is deleted before the backup is loaded.
  Future<void> restoreFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found.');
    }

    final content = await file.readAsString();
    final backup = jsonDecode(content) as Map<String, dynamic>;

    if (backup['version'] != backupVersion) {
      throw Exception('Unsupported backup file version.');
    }

    final data = backup['data'] as Map<String, dynamic>;
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // Delete existing data, children first, to satisfy foreign keys.
      for (final table in _tablesChildFirst) {
        await txn.delete(table);
      }

      // Insert backup data, parents first.
      for (final table in _tablesChildFirst.reversed) {
        final rows = data[table] as List<dynamic>?;
        if (rows == null) continue;

        for (final row in rows) {
          await txn.insert(
            table,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
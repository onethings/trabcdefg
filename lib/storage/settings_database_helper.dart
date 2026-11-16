import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SettingsDatabaseHelper {
  static Database? _database;
  static const String tableName = 'app_settings';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_settings.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            key TEXT PRIMARY KEY,
            value REAL
          )
        ''');
      },
    );
  }

  static Future<void> saveSetting(String key, double value) async {
    final db = await database;
    await db.insert(
      tableName,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<double?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as double;
    }
    return null;
  }

  // The value column is REAL, so flags ride in as 1.0 and 0.0. Callers hand in
  // a bool and never see this detail.
  static Future<void> saveFlag(String key, bool value) => saveSetting(key, value ? 1.0 : 0.0);

  static Future<bool?> getFlag(String key) async {
    final value = await getSetting(key);
    return value == null ? null : value != 0.0;
  }
}

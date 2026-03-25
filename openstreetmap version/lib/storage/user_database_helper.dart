import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class UserDatabaseHelper {
  static Database? _database;
  static const String tableName = 'favorites';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'user_data.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            device_id INTEGER PRIMARY KEY
          )
        ''');
      },
    );
  }

  static Future<void> addFavorite(int deviceId) async {
    final db = await database;
    await db.insert(
      tableName,
      {'device_id': deviceId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeFavorite(int deviceId) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  static Future<Set<int>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return Set<int>.from(maps.map((m) => m['device_id'] as int));
  }
}

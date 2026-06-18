import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/db_constants.dart';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.dbName);

    final db = await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _applyPragmas(db);
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(DbConstants.createTableSql);
    await db.execute(DbConstants.createIndexSql);

    await db.execute(DbConstants.createCompoundIndexSql);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await _migrate(db, v);
    }
  }

  Future<void> _migrate(Database db, int toVersion) async {
    switch (toVersion) {
      default:
        break;
    }
  }

  Future<void> _applyPragmas(Database db) async {
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous  = NORMAL');
    await db.execute('PRAGMA cache_size   = -4096');
    await db.execute('PRAGMA temp_store   = MEMORY');
  }
}

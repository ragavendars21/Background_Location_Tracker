import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/db_constants.dart';

/// Manages the single SQLite connection for the app.
///
/// Why a static field instead of a singleton constructor?
/// A static `_database` field ensures one connection regardless of how many
/// `DatabaseHelper` instances are created — simple to explain and easy to test.
class DatabaseHelper {
  static Database? _database;

  // ── Public access ──────────────────────────────────────────────────────────

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Closes the connection — call when the app is disposing (e.g. tests).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.dbName);

    final db = await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // sqflite restricts execute() inside all open callbacks (onConfigure, onOpen).
    // Apply PRAGMAs here — after openDatabase() returns the fully-open Database
    // object, execute() works without any restriction.
    await _applyPragmas(db);
    return db;
  }

  // ── Lifecycle callbacks ────────────────────────────────────────────────────

  /// Called once when the database is first created on the device.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(DbConstants.createTableSql);
    await db.execute(DbConstants.createIndexSql);
    // Compound (session_id, timestamp) index — covers both the WHERE filter
    // and the ORDER BY in fetchBySession(), eliminating a sort step.
    await db.execute(DbConstants.createCompoundIndexSql);
  }

  /// Called when [DbConstants.dbVersion] is incremented.
  ///
  /// Migration strategy: sequential version jumps.
  /// Each `case` brings the schema forward by exactly one version.
  /// This means a user upgrading from v1 → v3 runs both v2 and v3 migrations.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await _migrate(db, v);
    }
  }

  Future<void> _migrate(Database db, int toVersion) async {
    switch (toVersion) {
      // Example future migration — uncommenting this and bumping dbVersion to 2
      // would add a speed column to every existing device on next app launch:
      //
      // case 2:
      //   await db.execute(
      //     'ALTER TABLE ${DbConstants.locationsTable} ADD COLUMN speed REAL DEFAULT 0',
      //   );
      //   break;
      default:
        break;
    }
  }

  /// Enables WAL and tunes performance PRAGMAs.
  ///
  /// WHY THESE PRAGMAS (database optimization):
  /// ────────────────────────────────────────────
  ///
  /// journal_mode = WAL
  ///   Write-Ahead Logging: the background GPS service can INSERT a new row
  ///   while the UI simultaneously SELECTs for the history screen — no lock
  ///   contention. Default journal mode (DELETE) serialises reads and writes.
  ///
  /// synchronous = NORMAL
  ///   With WAL mode, NORMAL is safe (SQLite's own documentation confirms this).
  ///   FULL synchronous flushes to disk after every transaction — expensive on
  ///   mobile storage. NORMAL flushes at checkpoints only: ~2× faster writes.
  ///
  /// cache_size = -4096
  ///   Negative value = kilobytes. Gives SQLite a 4 MB page cache in RAM.
  ///   Default is only 2 000 pages (~8 MB on desktop but <1 MB on mobile).
  ///   Repeated reads of the same session rows now hit RAM instead of NAND flash.
  ///
  /// temp_store = MEMORY
  ///   ORDER BY and GROUP BY sort operations use a temporary table.
  ///   Moving that temp table to RAM avoids slow NAND writes for every query.
  ///
  /// NOTE: `PRAGMA journal_mode = WAL` returns a result set ("wal"), so Android's
  /// execSQL() (which sqflite's execute() maps to) rejects it — execSQL() only
  /// accepts statements that return NO data. Use rawQuery() instead.
  /// The other three PRAGMAs are pure setters (no result set) and work with execute().
  Future<void> _applyPragmas(Database db) async {
    await db.rawQuery('PRAGMA journal_mode = WAL'); // returns 'wal' → must use rawQuery
    await db.execute('PRAGMA synchronous  = NORMAL');
    await db.execute('PRAGMA cache_size   = -4096');
    await db.execute('PRAGMA temp_store   = MEMORY');
  }
}

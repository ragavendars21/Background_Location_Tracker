import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/location_model.dart';

/// Owns all raw SQLite operations for the locations table.
///
/// Responsibility: translate between [LocationModel] and SQL.
/// It knows about column names, SQL syntax, and conflict strategies.
/// Nothing above this class (repository, use case, UI) touches SQL directly.
class LocationLocalDatasource {
  final DatabaseHelper _dbHelper;

  LocationLocalDatasource(this._dbHelper);

  // ── CREATE ─────────────────────────────────────────────────────────────────

  /// Inserts one GPS fix.  ConflictAlgorithm.ignore protects against the rare
  /// case where the background service fires twice in the same second.
  Future<void> insertLocation(LocationModel model) async {
    final db = await _dbHelper.database;
    await db.insert(
      DbConstants.locationsTable,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ── READ ───────────────────────────────────────────────────────────────────

  /// Every location across all sessions — newest first.
  Future<List<LocationModel>> fetchAllLocations() async {
    final db   = await _dbHelper.database;
    final maps = await db.query(
      DbConstants.locationsTable,
      orderBy: '${DbConstants.colTimestamp} DESC',
    );
    return maps.map(LocationModel.fromMap).toList();
  }

  /// All points belonging to [sessionId], oldest first (route order).
  Future<List<LocationModel>> fetchBySession(String sessionId) async {
    final db   = await _dbHelper.database;
    final maps = await db.query(
      DbConstants.locationsTable,
      where:     '${DbConstants.colSessionId} = ?',
      whereArgs: [sessionId],
      orderBy:   '${DbConstants.colTimestamp} ASC',
    );
    return maps.map(LocationModel.fromMap).toList();
  }

  /// The single most recently saved location, or null if the table is empty.
  Future<LocationModel?> fetchLatestLocation() async {
    final db   = await _dbHelper.database;
    final maps = await db.query(
      DbConstants.locationsTable,
      orderBy: '${DbConstants.colTimestamp} DESC',
      limit:   1,
    );
    return maps.isEmpty ? null : LocationModel.fromMap(maps.first);
  }

  /// Distinct session IDs ordered by the most recent timestamp in each session.
  ///
  /// Uses a GROUP BY + MAX(timestamp) subquery so that sessions are sorted
  /// by when their last point was recorded — most recent session first.
  Future<List<String>> fetchSessionIds() async {
    final db   = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT   ${DbConstants.colSessionId},
               MAX(${DbConstants.colTimestamp}) AS latest
      FROM     ${DbConstants.locationsTable}
      GROUP BY ${DbConstants.colSessionId}
      ORDER BY latest DESC
    ''');
    return maps
        .map((row) => row[DbConstants.colSessionId] as String)
        .toList();
  }

  /// Total row count across all sessions.
  Future<int> countAll() async {
    final db     = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.locationsTable}',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Row count for a specific session.
  Future<int> countBySession(String sessionId) async {
    final db     = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.locationsTable} '
      'WHERE ${DbConstants.colSessionId} = ?',
      [sessionId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────

  /// Removes every location that belongs to [sessionId].
  Future<void> deleteBySession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DbConstants.locationsTable,
      where:     '${DbConstants.colSessionId} = ?',
      whereArgs: [sessionId],
    );
  }

  /// Drops all rows — effectively a factory reset for location data.
  Future<void> deleteAllLocations() async {
    final db = await _dbHelper.database;
    await db.delete(DbConstants.locationsTable);
  }
}

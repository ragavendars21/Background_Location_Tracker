import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/location_model.dart';

class LocationLocalDatasource {
  final DatabaseHelper _dbHelper;

  LocationLocalDatasource(this._dbHelper);

  Future<void> insertLocation(LocationModel model) async {
    final db = await _dbHelper.database;
    await db.insert(
      DbConstants.locationsTable,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<LocationModel>> fetchAllLocations() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DbConstants.locationsTable,
      orderBy: '${DbConstants.colTimestamp} DESC',
    );
    return maps.map(LocationModel.fromMap).toList();
  }

  Future<List<LocationModel>> fetchBySession(String sessionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DbConstants.locationsTable,
      where: '${DbConstants.colSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: '${DbConstants.colTimestamp} ASC',
    );
    return maps.map(LocationModel.fromMap).toList();
  }

  Future<LocationModel?> fetchLatestLocation() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DbConstants.locationsTable,
      orderBy: '${DbConstants.colTimestamp} DESC',
      limit: 1,
    );
    return maps.isEmpty ? null : LocationModel.fromMap(maps.first);
  }

  Future<List<String>> fetchSessionIds() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT   ${DbConstants.colSessionId},
               MAX(${DbConstants.colTimestamp}) AS latest
      FROM     ${DbConstants.locationsTable}
      GROUP BY ${DbConstants.colSessionId}
      ORDER BY latest DESC
    ''');
    return maps.map((row) => row[DbConstants.colSessionId] as String).toList();
  }

  Future<int> countAll() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.locationsTable}',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> countBySession(String sessionId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.locationsTable} '
      'WHERE ${DbConstants.colSessionId} = ?',
      [sessionId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> deleteBySession(String sessionId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DbConstants.locationsTable,
      where: '${DbConstants.colSessionId} = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteAllLocations() async {
    final db = await _dbHelper.database;
    await db.delete(DbConstants.locationsTable);
  }
}

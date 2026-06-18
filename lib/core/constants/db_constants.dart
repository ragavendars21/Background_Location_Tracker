class DbConstants {
  DbConstants._();

  static const String dbName = 'location_tracker.db';
  static const int dbVersion = 1;

  static const String locationsTable = 'locations';

  static const String colId = 'id';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colAccuracy = 'accuracy';
  static const String colTimestamp = 'timestamp';
  static const String colSessionId = 'session_id';

  static const String indexSessionId = 'idx_locations_session_id';
  static const String indexSessionIdAndTs = 'idx_locations_session_id_ts';

  static const int kMaxLocationsInMemory = 5000;

  static const String createTableSql =
      '''
    CREATE TABLE $locationsTable (
      $colId        INTEGER PRIMARY KEY AUTOINCREMENT,
      $colLatitude  REAL    NOT NULL,
      $colLongitude REAL    NOT NULL,
      $colAccuracy  REAL    NOT NULL,
      $colTimestamp TEXT    NOT NULL,
      $colSessionId TEXT    NOT NULL
    )
  ''';

  static const String createIndexSql =
      '''
    CREATE INDEX $indexSessionId ON $locationsTable ($colSessionId)
  ''';

  static const String createCompoundIndexSql =
      '''
    CREATE INDEX $indexSessionIdAndTs
    ON $locationsTable ($colSessionId, $colTimestamp)
  ''';
}

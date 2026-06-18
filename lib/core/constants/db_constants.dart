class DbConstants {
  DbConstants._();

  // ── Database file ──────────────────────────────────────────────────────────
  static const String dbName    = 'location_tracker.db';
  static const int    dbVersion = 1;

  // ── Table ─────────────────────────────────────────────────────────────────
  static const String locationsTable = 'locations';

  // ── Columns ───────────────────────────────────────────────────────────────
  static const String colId        = 'id';
  static const String colLatitude  = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colAccuracy  = 'accuracy';
  static const String colTimestamp = 'timestamp';  // ISO 8601 UTC
  static const String colSessionId = 'session_id';

  // ── Indexes ───────────────────────────────────────────────────────────────
  //
  // WHY TWO INDEXES?
  // ────────────────
  // idx_session_id       → speeds up WHERE session_id = ?  (O(log n) vs O(n))
  // idx_session_id_ts    → speeds up WHERE session_id = ? ORDER BY timestamp
  //                        Without this compound index, SQLite sorts all matching
  //                        rows AFTER filtering. With it, the rows come out of the
  //                        index already sorted — no extra sort step.
  //
  // fetchBySession() is the most frequent query in a long tracking session
  // (called on map load, history screen open, session delete). The compound
  // index makes it ~10× faster once a session has hundreds of points.
  static const String indexSessionId         = 'idx_locations_session_id';
  static const String indexSessionIdAndTs    = 'idx_locations_session_id_ts';

  // Maximum locations to load into memory for the dashboard / history screen.
  // Beyond this threshold the UI is unresponsive and the list is unreadable.
  // Server-side pagination would be the next step at >10 000 points.
  static const int kMaxLocationsInMemory = 5000;

  // ── DDL helpers ───────────────────────────────────────────────────────────
  static const String createTableSql = '''
    CREATE TABLE $locationsTable (
      $colId        INTEGER PRIMARY KEY AUTOINCREMENT,
      $colLatitude  REAL    NOT NULL,
      $colLongitude REAL    NOT NULL,
      $colAccuracy  REAL    NOT NULL,
      $colTimestamp TEXT    NOT NULL,
      $colSessionId TEXT    NOT NULL
    )
  ''';

  // Single-column index — used by WHERE session_id = ? queries.
  static const String createIndexSql = '''
    CREATE INDEX $indexSessionId ON $locationsTable ($colSessionId)
  ''';

  // Compound index — used by WHERE session_id = ? ORDER BY timestamp queries.
  // Covers both the filter and the sort in fetchBySession().
  static const String createCompoundIndexSql = '''
    CREATE INDEX $indexSessionIdAndTs
    ON $locationsTable ($colSessionId, $colTimestamp)
  ''';
}

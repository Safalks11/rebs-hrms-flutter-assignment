import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Future<Database>? _database;

  AppDatabase();

  Future<Database> get db => _database ??= _open();

  Future<Database> _open() async {
    try {
      final location = path.join(await getDatabasesPath(), 'rebs_hrms.db');
      return await openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE office_profile (id INTEGER PRIMARY KEY, latitude REAL NOT NULL, longitude REAL NOT NULL)',
            );
            await _createAttendance(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) await _createAttendance(db);
          },
        ),
      );
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  static Future<void> _createAttendance(Database db) => db.execute('''
    CREATE TABLE attendance_events (
      event_id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      company_date TEXT NOT NULL,
      event_type TEXT NOT NULL CHECK(event_type IN ('checkIn', 'checkOut')),
      timestamp_utc TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      sync_status TEXT NOT NULL CHECK(sync_status IN ('pending', 'synced', 'rejected')),
      UNIQUE(employee_id, company_date, event_type)
    )
  ''');

  Future<void> close() async {
    final pending = _database;
    _database = null;
    if (pending != null) await (await pending).close();
  }
}

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:rebs_hrms_assignment/features/office_profile/models/office_location.dart';

class OfficeProfileStore {
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _open();

  Future<Database> _open() async {
    final databasePath = path.join(await getDatabasesPath(), 'rebs_hrms.db');
    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE office_profile (id INTEGER PRIMARY KEY, latitude REAL NOT NULL, longitude REAL NOT NULL)',
        );
      },
    );
  }

  Future<OfficeLocation?> load() async {
    final rows = await (await _db).query(
      'office_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OfficeLocation(
      latitude: rows.first['latitude'] as double,
      longitude: rows.first['longitude'] as double,
    );
  }

  Future<void> save(OfficeLocation location) async {
    if (!location.isValid) {
      throw ArgumentError('Office coordinates are invalid.');
    }
    await (await _db).insert('office_profile', {
      'id': 1,
      'latitude': location.latitude,
      'longitude': location.longitude,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

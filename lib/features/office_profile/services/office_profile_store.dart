import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/features/office_profile/models/office_location.dart';
import 'package:sqflite/sqflite.dart';

class OfficeProfileStore {
  final AppDatabase database;
  OfficeProfileStore(this.database);

  Future<OfficeLocation?> load() async {
    final rows = await (await database.db).query(
      'office_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OfficeLocation(
      latitude: (rows.first['latitude'] as num).toDouble(),
      longitude: (rows.first['longitude'] as num).toDouble(),
    );
  }

  Future<void> save(OfficeLocation location) async {
    if (!location.isValid) {
      throw ArgumentError('Office coordinates are invalid.');
    }
    await (await database.db).insert('office_profile', {
      'id': 1,
      'latitude': location.latitude,
      'longitude': location.longitude,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

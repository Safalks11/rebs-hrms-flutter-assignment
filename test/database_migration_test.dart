import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  for (final version in [1, 2, 3, 4]) {
    test('upgrade from version $version preserves existing records', () async {
      final directory = await Directory.systemTemp.createTemp(
        'hrms-migration-',
      );
      final location = '${directory.path}/hrms.db';
      final old = await databaseFactoryFfi.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE office_profile (id INTEGER PRIMARY KEY, latitude REAL NOT NULL, longitude REAL NOT NULL)',
            );
            await db.insert('office_profile', {
              'id': 1,
              'latitude': 12.0,
              'longitude': 77.0,
            });
            if (version >= 2) {
              await db.execute(
                'CREATE TABLE attendance_events (event_id TEXT PRIMARY KEY, employee_id TEXT NOT NULL, company_date TEXT NOT NULL, event_type TEXT NOT NULL, timestamp_utc TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, sync_status TEXT NOT NULL, UNIQUE(employee_id, company_date, event_type))',
              );
              await db.insert('attendance_events', {
                'event_id': 'saved-id',
                'employee_id': 'EMP001',
                'company_date': '2026-11-20',
                'event_type': 'checkIn',
                'timestamp_utc': '2026-11-20T04:00:00Z',
                'latitude': 12.0,
                'longitude': 77.0,
                'sync_status': 'pending',
              });
            }
            if (version >= 3) {
              await db.execute(
                'CREATE TABLE leave_cache (employee_id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
              );
            }
            if (version >= 4) {
              await db.execute(
                'CREATE TABLE employee_cache (employee_id TEXT PRIMARY KEY, name TEXT NOT NULL, department TEXT NOT NULL)',
              );
            }
          },
        ),
      );
      await old.close();
      final upgraded = AppDatabase(databasePath: location);
      try {
        final db = await upgraded.db;
        expect(await db.getVersion(), 5);
        final columns = await db.rawQuery(
          'PRAGMA table_info(attendance_events)',
        );
        expect(
          columns.where((row) => row['name'] == 'rejection_reason').length,
          1,
        );
        expect((await db.query('office_profile')).single['latitude'], 12.0);
        if (version >= 2) {
          expect(
            (await db.query('attendance_events')).single['event_id'],
            'saved-id',
          );
        }
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    });
  }
}

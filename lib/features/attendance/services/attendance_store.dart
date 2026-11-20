import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/core/utils/company_time.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';

class AttendanceStoreException implements Exception {
  final String message;
  const AttendanceStoreException(this.message);
}

class AttendanceStore {
  final AppDatabase database;
  AttendanceStore(this.database);

  Future<int> countPendingEvents(String employeeId) async {
    final rows = await (await database.db).rawQuery(
      'SELECT COUNT(*) AS total FROM attendance_events WHERE employee_id = ? AND sync_status = ?',
      [employeeId, 'pending'],
    );
    return rows.single['total'] as int;
  }

  Future<List<AttendanceEvent>> pendingEvents(String employeeId) async {
    final rows = await (await database.db).query(
      'attendance_events',
      where: 'employee_id = ? AND sync_status = ?',
      whereArgs: [employeeId, 'pending'],
      orderBy: 'company_date ASC, timestamp_utc ASC, event_type ASC',
    );
    final events = rows.map(AttendanceEvent.fromMap).toList();
    events.sort((a, b) {
      final date = a.companyDate.compareTo(b.companyDate);
      if (date != 0) return date;
      if (a.type != b.type) {
        return a.type == AttendanceEventType.checkIn ? -1 : 1;
      }
      return a.timestamp.compareTo(b.timestamp);
    });
    return events;
  }

  Future<void> setSyncStatus(
    String id,
    AttendanceSyncStatus status, {
    String? rejectionReason,
  }) async {
    await (await database.db).update(
      'attendance_events',
      {'sync_status': status.name, 'rejection_reason': rejectionReason},
      where: 'event_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> mergeServerEvents(List<AttendanceEvent> events) async {
    final db = await database.db;
    await db.transaction((tx) async {
      for (final event in events) {
        final byId = await tx.query(
          'attendance_events',
          where: 'event_id = ?',
          whereArgs: [event.id],
        );
        if (byId.isNotEmpty) {
          await tx.update(
            'attendance_events',
            {
              'sync_status': AttendanceSyncStatus.synced.name,
              'rejection_reason': null,
            },
            where: 'event_id = ?',
            whereArgs: [event.id],
          );
          continue;
        }
        final sameAction = await tx.query(
          'attendance_events',
          where: 'employee_id = ? AND company_date = ? AND event_type = ?',
          whereArgs: [event.employeeId, event.companyDate, event.type.name],
        );
        if (sameAction.isEmpty) {
          await tx.insert('attendance_events', event.toMap());
        }
      }
    });
  }

  Future<void> saveEvent(AttendanceEvent event) async {
    if (event.companyDate != CompanyTime.attendanceDateKey(event.timestamp) ||
        !event.latitude.isFinite ||
        event.latitude.abs() > 90 ||
        !event.longitude.isFinite ||
        event.longitude.abs() > 180) {
      throw const AttendanceStoreException(
        'Invalid attendance date or location.',
      );
    }
    final connection = await database.db;
    await connection.transaction((transaction) async {
      final rows = await transaction.query(
        'attendance_events',
        where: 'employee_id = ? AND company_date = ?',
        whereArgs: [event.employeeId, event.companyDate],
      );
      final events = rows.map(AttendanceEvent.fromMap).toList();
      if (events.any((savedEvent) => savedEvent.type == event.type)) {
        throw const AttendanceStoreException(
          'This attendance action is already saved.',
        );
      }
      if (event.type == AttendanceEventType.checkOut) {
        final checkIns = events.where(
          (event) => event.type == AttendanceEventType.checkIn,
        );
        if (checkIns.isEmpty ||
            checkIns.first.syncStatus == AttendanceSyncStatus.rejected) {
          throw const AttendanceStoreException('Check in before checking out.');
        }

        if (event.timestamp.isBefore(checkIns.first.timestamp)) {
          throw const AttendanceStoreException(
            'Check-out time cannot be earlier than check-in time.',
          );
        }
      }
      await transaction.insert('attendance_events', event.toMap());
    });
  }

  Future<AttendanceModel> loadAttendanceForDay(
    String employeeId,
    DateTime now,
  ) async {
    final connection = await database.db;
    final rows = await connection.query(
      'attendance_events',
      where: 'employee_id = ? AND company_date = ?',
      whereArgs: [employeeId, CompanyTime.attendanceDateKey(now)],
    );
    return _buildAttendanceRecord(
      CompanyTime.attendanceDate(now),
      rows.map(AttendanceEvent.fromMap).toList(),
    );
  }

  Future<List<AttendanceModel>> loadRecentAttendance(String employeeId) async {
    final connection = await database.db;
    final rows = await connection.rawQuery(
      '''
      SELECT * FROM attendance_events
      WHERE employee_id = ? AND company_date IN (
        SELECT DISTINCT company_date FROM attendance_events
        WHERE employee_id = ? ORDER BY company_date DESC LIMIT 5
      ) ORDER BY company_date DESC, timestamp_utc ASC, event_type ASC
    ''',
      [employeeId, employeeId],
    );
    final eventsByDate = <String, List<AttendanceEvent>>{};
    for (final row in rows) {
      final event = AttendanceEvent.fromMap(row);
      eventsByDate.putIfAbsent(event.companyDate, () => []).add(event);
    }
    return eventsByDate.entries
        .map(
          (entry) => _buildAttendanceRecord(
            DateTime.parse('${entry.key}T00:00:00Z'),
            entry.value,
          ),
        )
        .toList();
  }

  AttendanceModel _buildAttendanceRecord(
    DateTime date,
    List<AttendanceEvent> events,
  ) {
    AttendanceEvent? checkIn;
    AttendanceEvent? checkOut;
    for (final event in events) {
      if (event.type == AttendanceEventType.checkIn) {
        checkIn = event;
      } else {
        checkOut = event;
      }
    }
    return AttendanceModel(
      date: date,
      checkInTime: checkIn?.timestamp,
      checkOutTime: checkOut?.timestamp,
      checkInLatitude: checkIn?.latitude,
      checkInLongitude: checkIn?.longitude,
      checkOutLatitude: checkOut?.latitude,
      checkOutLongitude: checkOut?.longitude,
      rejectionMessages: [
        for (final event in events.where(
          (event) => event.syncStatus == AttendanceSyncStatus.rejected,
        ))
          '${event.type == AttendanceEventType.checkIn ? 'Check-in' : 'Check-out'}: '
              '${event.rejectionReason ?? 'Reason unavailable for earlier rejection.'}',
      ],
      syncStatus: events.isEmpty
          ? null
          : events.any(
              (event) => event.syncStatus == AttendanceSyncStatus.rejected,
            )
          ? AttendanceSyncStatus.rejected
          : events.any(
              (event) => event.syncStatus == AttendanceSyncStatus.pending,
            )
          ? AttendanceSyncStatus.pending
          : AttendanceSyncStatus.synced,
    );
  }
}

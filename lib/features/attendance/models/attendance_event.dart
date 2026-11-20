enum AttendanceEventType { checkIn, checkOut }

enum AttendanceSyncStatus { pending, synced, rejected }

class AttendanceEvent {
  final String id;
  final String employeeId;
  final String companyDate;
  final AttendanceEventType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final AttendanceSyncStatus syncStatus;
  final String? rejectionReason;

  const AttendanceEvent({
    required this.id,
    required this.employeeId,
    required this.companyDate,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.syncStatus = AttendanceSyncStatus.pending,
    this.rejectionReason,
  });

  Map<String, Object?> toMap() => {
    'event_id': id,
    'employee_id': employeeId,
    'company_date': companyDate,
    'event_type': type.name,
    'timestamp_utc': timestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'sync_status': syncStatus.name,
    'rejection_reason': rejectionReason,
  };

  factory AttendanceEvent.fromMap(Map<String, Object?> row) => AttendanceEvent(
    id: row['event_id'] as String,
    employeeId: row['employee_id'] as String,
    companyDate: row['company_date'] as String,
    type: AttendanceEventType.values.byName(row['event_type'] as String),
    timestamp: DateTime.parse(row['timestamp_utc'] as String).toUtc(),
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    syncStatus: AttendanceSyncStatus.values.byName(
      row['sync_status'] as String,
    ),
    rejectionReason: row['rejection_reason'] as String?,
  );
}

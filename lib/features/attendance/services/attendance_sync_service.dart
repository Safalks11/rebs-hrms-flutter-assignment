import 'package:dio/dio.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../models/attendance_event.dart';
import 'attendance_store.dart';

class AttendanceSyncService {
  final AttendanceStore store;
  final ApiService api;
  final ConnectivityService connectivity;
  bool _running = false;
  AttendanceSyncService(this.store, this.api, this.connectivity);

  Future<String> sync(String employeeId) async {
    if (_running) return 'Synchronization is already running.';
    _running = true;
    var synced = 0;
    var rejected = 0;
    String? firstRejectionReason;
    try {
      if (await connectivity.checkNow() != NetworkStatus.connected) {
        return 'Connect to a network to sync attendance.';
      }
      final events = await store.pendingEvents(employeeId);
      if (events.isEmpty) return 'No pending attendance events.';
      final rejectedIds = <String>{};
      for (final event in events) {
        if (rejectedIds.contains(event.id)) continue;
        try {
          await api.dio.post<Map<String, dynamic>>(
            '/attendance/events',
            data: {
              'id': event.id,
              'employeeId': event.employeeId,
              'companyDate': event.companyDate,
              'type': event.type.name,
              'timestamp': event.timestamp.toUtc().toIso8601String(),
              'latitude': event.latitude,
              'longitude': event.longitude,
            },
          );
          await store.setSyncStatus(event.id, AttendanceSyncStatus.synced);
          synced++;
        } on DioException catch (error) {
          final code = error.response?.statusCode;
          if (code == 400 || code == 409 || code == 422) {
            final reason = api.message(error);
            firstRejectionReason ??= reason;
            await store.setSyncStatus(
              event.id,
              AttendanceSyncStatus.rejected,
              rejectionReason: reason,
            );
            rejected++;
            if (event.type == AttendanceEventType.checkIn) {
              for (final dependent in events.where(
                (item) =>
                    item.companyDate == event.companyDate &&
                    item.type == AttendanceEventType.checkOut,
              )) {
                await store.setSyncStatus(
                  dependent.id,
                  AttendanceSyncStatus.rejected,
                  rejectionReason: 'Check-in rejected: $reason',
                );
                rejected++;
                rejectedIds.add(dependent.id);
              }
            }
          } else {
            break;
          }
        }
      }
      if (rejected > 0) {
        return '$synced synced, $rejected rejected. $firstRejectionReason';
      }
      if (synced < events.length) {
        return '$synced synced. Remaining events are still pending.';
      }
      return '$synced attendance events synced.';
    } catch (error) {
      return api.message(error);
    } finally {
      _running = false;
    }
  }
}

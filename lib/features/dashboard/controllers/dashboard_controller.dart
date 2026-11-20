import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/core/utils/company_time.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';
import 'package:rebs_hrms_assignment/features/dashboard/models/employee_model.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../attendance/services/attendance_sync_service.dart';
import '../../leave/services/leave_repository.dart';
import '../../office_profile/services/office_profile_store.dart';
import '../services/employee_store.dart';

class DashboardController extends GetxController with WidgetsBindingObserver {
  final AttendanceLocationService _locationService;
  final AttendanceStore _attendanceStore;
  final DateTime Function() _now;
  final ConnectivityService connectivity;
  final AttendanceSyncService syncService;
  final ApiService api;
  final EmployeeStore employeeStore;
  final LeaveRepository leaveRepository;
  final OfficeProfileStore officeStore;
  final pendingCount = RxnInt();
  final checkingSync = false.obs;
  final syncMessage = RxnString();
  final serverMessage = RxnString();

  DashboardController(
    this._locationService,
    this._attendanceStore,
    this.connectivity,
    this.syncService,
    this.api,
    this.employeeStore,
    this.leaveRepository,
    this.officeStore, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final employee = const EmployeeModel(
    id: 'EMP001',
    name: 'Alex Johnson',
    department: 'Engineering',
  ).obs;

  late final Rx<AttendanceModel> attendance;
  final recentAttendanceRecords = <AttendanceModel>[].obs;
  final currentTime = DateTime.now().obs;
  final isLoading = true.obs;
  final isMarkingAttendance = false.obs;
  final storageError = RxnString();
  final actionMessage = RxnString();
  final locationFailure = Rxn<AttendanceLocationFailure>();
  Timer? _workingDurationTimer;
  Worker? _connectionWorker;
  bool _isRefreshingAttendance = false;
  bool _refreshingDashboard = false;

  @override
  void onInit() {
    super.onInit();
    currentTime.value = _now();
    attendance = AttendanceModel(date: CompanyTime.attendanceDate(_now())).obs;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
    _connectionWorker = ever<NetworkStatus>(connectivity.status, (status) {
      if (status == NetworkStatus.connected) {
        unawaited(refreshDashboard());
      }
    });
    _workingDurationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      currentTime.value = _now();
      if (attendance.value.date != CompanyTime.attendanceDate(_now())) {
        unawaited(refreshAttendance());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      currentTime.value = _now();
      unawaited(refreshDashboard());
    }
  }

  Future<void> _initialize() async {
    try {
      final cached = await employeeStore.load();
      if (cached != null && !isClosed) employee.value = cached;
      await leaveRepository.loadCache();
    } catch (_) {
      // Saved attendance remains available independently.
    }
    await refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    if (isClosed || _refreshingDashboard) return;
    _refreshingDashboard = true;
    try {
      await refreshAttendance();
      if (isClosed) return;
      await syncNow();
      await refreshFromServer();
      await _refreshLeave();
    } catch (error) {
      if (!isClosed) serverMessage.value = api.message(error);
    } finally {
      _refreshingDashboard = false;
    }
  }

  Future<void> _refreshLeave() async {
    if (await connectivity.checkNow() != NetworkStatus.connected) return;
    try {
      await leaveRepository.refresh();
    } catch (_) {
      // Keep cached balances visible.
    }
  }

  Future<void> refreshAttendance() async {
    if (isClosed || _isRefreshingAttendance || isMarkingAttendance.value) {
      return;
    }
    _isRefreshingAttendance = true;
    isLoading.value = true;
    try {
      await _loadAttendance();
      if (!isClosed) storageError.value = null;
    } catch (_) {
      if (!isClosed) {
        storageError.value =
            'We could not load your saved attendance. Please try again.';
      }
    } finally {
      _isRefreshingAttendance = false;
      if (!isClosed) {
        await refreshPendingCount();
        isLoading.value = false;
      }
    }
  }

  Future<void> _loadAttendance() async {
    final now = _now();
    final todayAttendance = await _attendanceStore.loadAttendanceForDay(
      employee.value.id,
      now,
    );
    final recentRecords = await _attendanceStore.loadRecentAttendance(
      employee.value.id,
    );
    if (isClosed) return;
    attendance.value = todayAttendance;
    recentAttendanceRecords.assignAll(recentRecords);
    currentTime.value = now;
  }

  Future<void> refreshFromServer() async {
    if (await connectivity.checkNow() != NetworkStatus.connected) {
      if (!isClosed) serverMessage.value = 'Offline. Showing saved data.';
      return;
    }
    try {
      await officeStore.refresh(api);
      final response = await api.dio.get<Map<String, dynamic>>('/employee/me');
      final data = response.data!;
      final loadedEmployee = EmployeeModel(
        id: data['id'] as String,
        name: data['name'] as String,
        department: data['department'] as String,
      );
      await employeeStore.save(loadedEmployee);
      if (!isClosed) employee.value = loadedEmployee;
      final company = CompanyTime.toCompanyTime(_now());
      for (final month in [
        DateTime.utc(company.year, company.month),
        DateTime.utc(company.year, company.month - 1),
      ]) {
        final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        final response = await api.dio.get<Map<String, dynamic>>(
          '/attendance',
          queryParameters: {'month': key},
        );
        final events = (response.data!['events'] as List).map((item) {
          final row = Map<String, dynamic>.from(item as Map);
          return AttendanceEvent(
            id: row['id'] as String,
            employeeId: row['employeeId'] as String,
            companyDate: row['companyDate'] as String,
            type: AttendanceEventType.values.byName(row['type'] as String),
            timestamp: DateTime.parse(row['timestamp'] as String),
            latitude: (row['latitude'] as num).toDouble(),
            longitude: (row['longitude'] as num).toDouble(),
            syncStatus: AttendanceSyncStatus.synced,
          );
        }).toList();
        await _attendanceStore.mergeServerEvents(events);
      }
      await _loadAttendance();
      if (!isClosed) serverMessage.value = null;
    } catch (error) {
      if (!isClosed) serverMessage.value = api.message(error);
    }
  }

  Duration get workingDuration =>
      attendance.value.workingDurationAt(currentTime.value);

  Future<void> checkIn() => _markAttendance(checkingIn: true);
  Future<void> checkOut() => _markAttendance(checkingIn: false);

  Future<void> _markAttendance({required bool checkingIn}) async {
    if (isClosed ||
        isLoading.value ||
        isMarkingAttendance.value ||
        storageError.value != null) {
      return;
    }
    isMarkingAttendance.value = true;
    actionMessage.value = null;
    locationFailure.value = null;
    var attendanceSaved = false;
    try {
      // Refresh before validating so state never relies only on the UI guard.
      await _loadAttendance();
      if (isClosed) return;
      final startedAt = _now();
      final requiredStatus = checkingIn
          ? AttendanceStatus.notCheckedIn
          : AttendanceStatus.checkedIn;
      if (attendance.value.status != requiredStatus) {
        actionMessage.value = checkingIn
            ? 'Attendance is already marked for today.'
            : 'Check in today before checking out.';
        return;
      }
      final location = await _locationService.validate();
      if (isClosed) return;
      final now = _now();
      if (CompanyTime.attendanceDateKey(startedAt) !=
          CompanyTime.attendanceDateKey(now)) {
        actionMessage.value = 'The attendance day changed. Please try again.';
        return;
      }
      await _attendanceStore.saveEvent(
        AttendanceEvent(
          id: const Uuid().v4(),
          employeeId: employee.value.id,
          companyDate: CompanyTime.attendanceDateKey(now),
          type: checkingIn
              ? AttendanceEventType.checkIn
              : AttendanceEventType.checkOut,
          timestamp: now.toUtc(),
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );
      attendanceSaved = true;
      await refreshPendingCount();
      await _loadAttendance();
      if (!isClosed) {
        actionMessage.value = checkingIn
            ? 'Check-in saved.'
            : 'Check-out saved.';
      }
    } on AttendanceLocationException catch (error) {
      if (!isClosed) {
        actionMessage.value = error.message;
        locationFailure.value = error.reason;
      }
    } on AttendanceStoreException catch (error) {
      if (!isClosed) actionMessage.value = error.message;
    } catch (_) {
      if (!isClosed) {
        storageError.value = attendanceSaved
            ? 'Your attendance was saved, but we could not update the screen. Please try again.'
            : 'We could not open your saved attendance. Please try again before checking in or out.';
      }
    } finally {
      if (!isClosed) {
        isMarkingAttendance.value = false;
        if (attendanceSaved) unawaited(syncNow());
        if (attendance.value.date != CompanyTime.attendanceDate(_now())) {
          unawaited(refreshAttendance());
        }
      }
    }
  }

  Future<void> refreshPendingCount() async {
    try {
      final count = await _attendanceStore.countPendingEvents(
        employee.value.id,
      );
      if (!isClosed) {
        pendingCount.value = count;
        syncMessage.value = null;
      }
    } catch (_) {
      if (!isClosed) {
        pendingCount.value = null;
        syncMessage.value = 'Could not read pending attendance. Please retry.';
      }
    }
  }

  Future<void> syncNow() async {
    if (isClosed ||
        checkingSync.value ||
        isLoading.value ||
        isMarkingAttendance.value) {
      return;
    }
    checkingSync.value = true;
    try {
      await refreshPendingCount();
      if (isClosed || pendingCount.value == null) return;
      if (pendingCount.value == 0) {
        syncMessage.value = 'No pending attendance events.';
        return;
      }
      if (await connectivity.checkNow() == NetworkStatus.connected) {
        try {
          await officeStore.refresh(api);
        } catch (_) {
          // Sync still sends events using their saved coordinates.
        }
      }
      final result = await syncService.sync(employee.value.id);
      await refreshPendingCount();
      await _loadAttendance();
      if (!isClosed) syncMessage.value = result;
    } catch (error) {
      if (!isClosed) syncMessage.value = api.message(error);
    } finally {
      if (!isClosed) checkingSync.value = false;
    }
  }

  String? get resolutionLabel {
    switch (locationFailure.value) {
      case AttendanceLocationFailure.servicesDisabled:
      case AttendanceLocationFailure.permissionDeniedForever:
        return 'Settings';
      default:
        return null;
    }
  }

  Future<void> resolveLocationFailure() async {
    final reason = locationFailure.value;
    if (reason != null) {
      await _locationService.openSettings(reason);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _workingDurationTimer?.cancel();
    _connectionWorker?.dispose();
    super.onClose();
  }
}

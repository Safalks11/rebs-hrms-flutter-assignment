import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/core/utils/company_time.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';
import 'package:rebs_hrms_assignment/features/dashboard/models/employee_model.dart';
import 'package:uuid/uuid.dart';

class DashboardController extends GetxController with WidgetsBindingObserver {
  final AttendanceLocationService _locationService;
  final AttendanceStore _attendanceStore;
  final DateTime Function() _now;

  DashboardController(
    this._locationService,
    this._attendanceStore, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final EmployeeModel employee = const EmployeeModel(
    id: 'EMP001',
    name: 'Alex Johnson',
    department: 'Engineering',
  );
  final int casualLeaveBalance = 8;
  final int sickLeaveBalance = 5;

  late final Rx<AttendanceModel> attendance;
  final recentAttendanceRecords = <AttendanceModel>[].obs;
  final currentTime = DateTime.now().obs;
  final isLoading = true.obs;
  final isMarkingAttendance = false.obs;
  final storageError = RxnString();
  final actionMessage = RxnString();
  final locationFailure = Rxn<AttendanceLocationFailure>();
  Timer? _workingDurationTimer;
  bool _isRefreshingAttendance = false;

  @override
  void onInit() {
    super.onInit();
    currentTime.value = _now();
    attendance = AttendanceModel(date: CompanyTime.attendanceDate(_now())).obs;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshAttendance());
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
      unawaited(refreshAttendance());
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
      if (!isClosed) isLoading.value = false;
    }
  }

  Future<void> _loadAttendance() async {
    final now = _now();
    final todayAttendance = await _attendanceStore.loadAttendanceForDay(
      employee.id,
      now,
    );
    final recentRecords = await _attendanceStore.loadRecentAttendance(
      employee.id,
    );
    if (isClosed) return;
    attendance.value = todayAttendance;
    recentAttendanceRecords.assignAll(recentRecords);
    currentTime.value = now;
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
          employeeId: employee.id,
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
      await _loadAttendance();
      if (!isClosed) {
        actionMessage.value = checkingIn
            ? 'Check-in saved. Pending Sync.'
            : 'Check-out saved. Pending Sync.';
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
        if (attendance.value.date != CompanyTime.attendanceDate(_now())) {
          unawaited(refreshAttendance());
        }
      }
    }
  }

  String? get resolutionLabel {
    switch (locationFailure.value) {
      case AttendanceLocationFailure.officeNotConfigured:
        return 'Office Profile';
      case AttendanceLocationFailure.servicesDisabled:
      case AttendanceLocationFailure.permissionDeniedForever:
        return 'Settings';
      default:
        return null;
    }
  }

  Future<void> resolveLocationFailure() async {
    final reason = locationFailure.value;
    if (reason == AttendanceLocationFailure.officeNotConfigured) {
      await Get.toNamed(AppRoutes.officeProfile);
    } else if (reason != null) {
      await _locationService.openSettings(reason);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _workingDurationTimer?.cancel();
    super.onClose();
  }
}

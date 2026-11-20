import 'dart:async';

import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/dashboard/models/employee_model.dart';

class DashboardController extends GetxController {
  final AttendanceLocationService _locationService;

  DashboardController(this._locationService);

  final EmployeeModel employee = const EmployeeModel(
    id: 'EMP001',
    name: 'Alex Johnson',
    department: 'Engineering',
  );

  final int casualLeaveBalance = 8;
  final int sickLeaveBalance = 5;

  late final Rx<AttendanceModel> attendance;
  late final List<AttendanceModel> _demoHistory;
  final Rx<DateTime> currentTime = DateTime.now().obs;
  final RxBool isCheckingLocation = false.obs;
  final RxnString actionMessage = RxnString();
  final Rxn<AttendanceLocationFailure> locationFailure =
      Rxn<AttendanceLocationFailure>();
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();

    final now = DateTime.now();
    attendance = AttendanceModel(date: DateTime(now.year, now.month, now.day))
        .obs;
    _demoHistory = List.generate(5, (index) {
      final date = DateTime(now.year, now.month, now.day - index - 1);
      return AttendanceModel(
        date: date,
        checkInTime: DateTime(date.year, date.month, date.day, 9),
        checkOutTime: DateTime(date.year, date.month, date.day, 17),
      );
    });

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => currentTime.value = DateTime.now(),
    );
  }

  List<AttendanceModel> get recentAttendanceRecords => [
    if (attendance.value.status != AttendanceStatus.notCheckedIn)
      attendance.value,
    ..._demoHistory,
  ].take(5).toList();

  Duration get getWorkingDuration =>
      attendance.value.workingDurationAt(currentTime.value);

  Future<void> checkIn() => _markAttendance(checkingIn: true);

  Future<void> checkOut() => _markAttendance(checkingIn: false);

  Future<void> _markAttendance({required bool checkingIn}) async {
    if (isCheckingLocation.value) return;

    final startedAt = DateTime.now();
    if (!_sameDay(attendance.value.date, startedAt)) {
      if (!checkingIn) {
        actionMessage.value = 'Check-out must happen on the check-in day.';
        locationFailure.value = null;
        return;
      }
      if (attendance.value.status != AttendanceStatus.notCheckedIn) {
        _demoHistory.insert(0, attendance.value);
        if (_demoHistory.length > 5) _demoHistory.removeLast();
      }
      attendance.value = AttendanceModel(
        date: DateTime(startedAt.year, startedAt.month, startedAt.day),
      );
    }

    final expected = checkingIn
        ? AttendanceStatus.notCheckedIn
        : AttendanceStatus.checkedIn;
    if (attendance.value.status != expected) return;

    isCheckingLocation.value = true;
    actionMessage.value = null;
    locationFailure.value = null;
    try {
      final location = await _locationService.validate();
      if (isClosed || attendance.value.status != expected) return;
      final now = DateTime.now();
      if (!_sameDay(attendance.value.date, now)) {
        actionMessage.value = 'The attendance day changed. Please try again.';
        return;
      }
      currentTime.value = now;
      if (checkingIn) {
        attendance.value = AttendanceModel(
          date: DateTime(now.year, now.month, now.day),
          checkInTime: now,
          checkInLatitude: location.latitude,
          checkInLongitude: location.longitude,
        );
        actionMessage.value = 'Checked in successfully.';
      } else {
        final record = attendance.value;
        attendance.value = AttendanceModel(
          date: record.date,
          checkInTime: record.checkInTime,
          checkInLatitude: record.checkInLatitude,
          checkInLongitude: record.checkInLongitude,
          checkOutTime: now,
          checkOutLatitude: location.latitude,
          checkOutLongitude: location.longitude,
        );
        actionMessage.value = 'Checked out successfully.';
      }
    } on AttendanceLocationException catch (error) {
      if (!isClosed) {
        actionMessage.value = error.message;
        locationFailure.value = error.reason;
      }
    } finally {
      if (!isClosed) isCheckingLocation.value = false;
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

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

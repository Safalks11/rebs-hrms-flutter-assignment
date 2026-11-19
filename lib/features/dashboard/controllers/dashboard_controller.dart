import 'dart:async';

import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/dashboard/models/employee_model.dart';

class DashboardController extends GetxController {
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
      Duration(seconds: 10),
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

  void checkIn() {
    if (attendance.value.status != AttendanceStatus.notCheckedIn) {
      return;
    }

    final now = DateTime.now();

    currentTime.value = now;

    attendance.value = AttendanceModel(
      date: DateTime(now.year, now.month, now.day),
      checkInTime: now,
    );
  }

  void checkOut() {
    if (attendance.value.status != AttendanceStatus.checkedIn) {
      return;
    }

    final now = DateTime.now();

    currentTime.value = now;

    attendance.value = AttendanceModel(
      date: attendance.value.date,
      checkInTime: attendance.value.checkInTime,
      checkOutTime: now,
    );
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

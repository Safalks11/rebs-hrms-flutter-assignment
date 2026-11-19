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

  late final Rx<AttendanceModel> attendance;
  final Rx<DateTime> currentTime = DateTime.now().obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();

    final now = DateTime.now();

    attendance = AttendanceModel(
      date: DateTime(now.year, now.month, now.day),
      checkInTime: DateTime(now.year, now.month, now.day, 1),
    ).obs;

    _timer = Timer.periodic(
      Duration(seconds: 10),
      (_) => currentTime.value = DateTime.now(),
    );
  }

  Duration get getWorkingDuration {
    final now = currentTime.value;
    final record = attendance.value;

    if (record.checkInTime == null) {
      return Duration.zero;
    }

    final duration = (record.checkOutTime ?? now).difference(
      record.checkInTime!,
    );

    return duration.isNegative ? Duration.zero : duration;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

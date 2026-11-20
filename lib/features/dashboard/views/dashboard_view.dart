import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/features/dashboard/controllers/dashboard_controller.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/attendance_card.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/employee_card.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/leave_balance_card.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/recent_attendance_card.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Office Profile',
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () => Get.toNamed(AppRoutes.officeProfile),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeCard(employee: controller.employee),
            const SizedBox(height: 16),
            Obx(
              () => AttendanceCard(
                attendance: controller.attendance.value,
                duration: controller.getWorkingDuration,
                onCheckIn: controller.checkIn,
                onCheckOut: controller.checkOut,
                isCheckingLocation: controller.isCheckingLocation.value,
                actionMessage: controller.actionMessage.value,
                resolutionLabel: controller.resolutionLabel,
                onResolveIssue: controller.resolveLocationFailure,
              ),
            ),
            const SizedBox(height: 16),
            LeaveBalanceCard(
              casualDays: controller.casualLeaveBalance,
              sickDays: controller.sickLeaveBalance,
            ),
            const SizedBox(height: 16),
            Obx(
              () => RecentAttendanceCard(
                records: controller.recentAttendanceRecords,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

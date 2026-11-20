import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/features/dashboard/controllers/dashboard_controller.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/attendance_card.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/employee_card.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/leave_balance_card.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/recent_attendance_card.dart';

import '../../leave/models/leave_request.dart';
import '../../leave/services/leave_repository.dart';

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
            Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.storageError.value != null) {
                return Column(
                  children: [
                    Text(controller.storageError.value!),
                    TextButton(
                      onPressed: controller.refreshAttendance,
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              return AttendanceCard(
                attendance: controller.attendance.value,
                duration: controller.workingDuration,
                onCheckIn: controller.checkIn,
                onCheckOut: controller.checkOut,
                isMarkingAttendance: controller.isMarkingAttendance.value,
                actionMessage: controller.actionMessage.value,
                resolutionLabel: controller.resolutionLabel,
                onResolveIssue: controller.resolveLocationFailure,
              );
            }),
            const SizedBox(height: 16),
            Obx(() {
              final balances = Get.find<LeaveRepository>().balances;
              return balances.isEmpty
                  ? const Text('Leave balance unavailable')
                  : LeaveBalanceCard(
                      casualDays: balances[LeaveType.casual]!,
                      sickDays: balances[LeaveType.sick]!,
                    );
            }),
            TextButton(
              onPressed: () async {
                await Get.toNamed(AppRoutes.leave);
                try {
                  await Get.find<LeaveRepository>().refresh();
                } catch (_) {}
              },
              child: const Text('Manage leave'),
            ),
            const SizedBox(height: 16),
            Obx(
              () => RecentAttendanceCard(
                records: controller.recentAttendanceRecords.toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

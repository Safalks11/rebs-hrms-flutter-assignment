import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../attendance/utils/attendance_formatters.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/attendance_card.dart';
import '../widgets/dashboard_status.dart';
import '../widgets/dashboard_sync_banner.dart';
import '../widgets/employee_card.dart';
import '../widgets/leave_balance_card.dart';
import '../widgets/recent_attendance_card.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  Future<void> _manageLeave() async {
    await Get.toNamed(AppRoutes.leave);
    if (!controller.isClosed) await controller.refreshLeaveBalances();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dashboard(Theme.of(context)),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            Obx(
              () => IconButton(
                key: const ValueKey('refresh-dashboard'),
                tooltip: 'Refresh dashboard',
                onPressed: !controller.canRefreshDashboard
                    ? null
                    : controller.refreshFromUser,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: controller.refreshFromUser,
            child: SingleChildScrollView(
              key: const PageStorageKey('dashboard-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTheme.dashboardMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.dashboardPadding,
                      8,
                      AppTheme.dashboardPadding,
                      AppTheme.dashboardSectionGap,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Obx(
                          () => Text(
                            '${AttendanceFormatters.formatDate(controller.companyDate)} · IST',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.secondaryText),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Obx(
                          () =>
                              EmployeeCard(employee: controller.employee.value),
                        ),
                        const SizedBox(height: 16),
                        Obx(
                          () => DashboardSyncBanner(
                            network: controller.connectivity.status.value,
                            pendingCount: controller.pendingCount.value,
                            syncing: controller.checkingSync.value,
                            loading: controller.isInitialLoading,
                            actionsEnabled: controller.canUseSyncActions,
                            hasRejections: controller.hasRejectedAttendance,
                            syncMessage: controller.syncMessage.value,
                            serverMessage: controller.serverMessage.value,
                            onSync: controller.syncFromUser,
                            onRetry: controller.refreshFromUser,
                            onCheckNetwork: controller.connectivity.checkNow,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Obx(
                          () => SizedBox(
                            height: 4,
                            child: controller.showRefreshProgress
                                ? const LinearProgressIndicator(
                                    semanticsLabel: 'Refreshing dashboard',
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(() {
                          if (controller.isInitialLoading) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    SizedBox(height: 24),
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text("Loading today's attendance…"),
                                    SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (controller.storageError.value != null) {
                            return DashboardMessage(
                              message: controller.storageError.value!,
                              tone: StatusTone.error,
                              action: TextButton(
                                key: const ValueKey('retry-attendance'),
                                onPressed: controller.isLoading.value
                                    ? null
                                    : controller.retryAttendance,
                                child: const Text('Retry'),
                              ),
                            );
                          }
                          return AttendanceCard(
                            attendance: controller.attendance.value,
                            durationDisplay: Obx(
                              () => Text(
                                AttendanceFormatters.formatDuration(
                                  controller.workingDuration,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                            ),
                            onCheckIn: controller.checkIn,
                            onCheckOut: controller.checkOut,
                            isMarkingAttendance:
                                controller.isMarkingAttendance.value,
                            actionsEnabled: controller.canMarkAttendance,
                            actionSucceeded: controller.actionSucceeded.value,
                            actionMessage: controller.actionMessage.value,
                            resolutionLabel: controller.resolutionLabel,
                            onResolveIssue: controller.resolveLocationFailure,
                          );
                        }),
                        const SizedBox(height: AppTheme.dashboardSectionGap),
                        Obx(
                          () => LeaveBalanceCard(
                            casualDays: controller.casualLeaveBalance,
                            sickDays: controller.sickLeaveBalance,
                            onManageLeave: _manageLeave,
                          ),
                        ),
                        const SizedBox(height: AppTheme.dashboardSectionGap),
                        Obx(
                          () => RecentAttendanceCard(
                            records: controller.recentAttendanceRecords
                                .toList(),
                            loading: controller.isInitialLoading,
                            error: controller.storageError.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

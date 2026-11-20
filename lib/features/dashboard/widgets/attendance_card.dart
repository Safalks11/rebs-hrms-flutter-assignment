import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/utils/attendance_formatters.dart';
import 'dashboard_status.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceModel attendance;
  final Duration? duration;
  final Widget? durationDisplay;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final bool isMarkingAttendance;
  final bool actionsEnabled;
  final bool actionSucceeded;
  final String? actionMessage;
  final String? resolutionLabel;
  final VoidCallback onResolveIssue;

  const AttendanceCard({
    super.key,
    required this.attendance,
    this.duration,
    this.durationDisplay,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.isMarkingAttendance,
    this.actionsEnabled = true,
    this.actionSucceeded = false,
    required this.actionMessage,
    required this.resolutionLabel,
    required this.onResolveIssue,
  });

  @override
  Widget build(BuildContext context) {
    final status = attendance.status;
    final checkedOut = status == AttendanceStatus.checkedOut;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.dashboardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text("Today's attendance", style: text.titleMedium),
                StatusBadge(
                  label: AttendanceFormatters.statusText(status),
                  tone: status == AttendanceStatus.notCheckedIn
                      ? StatusTone.neutral
                      : StatusTone.info,
                  icon: checkedOut ? Icons.task_alt : Icons.access_time,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child:
                  durationDisplay ??
                  Text(
                    AttendanceFormatters.formatDuration(
                      duration ?? attendance.workingDuration,
                    ),
                    style: text.headlineLarge,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Working today',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final times = [
                  _TimeInfo(
                    label: 'Check-in',
                    value: AttendanceFormatters.formatTime(
                      attendance.checkInTime,
                    ),
                  ),
                  _TimeInfo(
                    label: 'Check-out',
                    value: AttendanceFormatters.formatTime(
                      attendance.checkOutTime,
                    ),
                  ),
                ];
                if (constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [times[0], const SizedBox(height: 12), times[1]],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: times[0]),
                    const SizedBox(width: 12),
                    Expanded(child: times[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            if (checkedOut)
              const DashboardMessage(
                message: 'Attendance completed',
                tone: StatusTone.info,
              )
            else
              FilledButton.icon(
                key: ValueKey(
                  status == AttendanceStatus.notCheckedIn
                      ? 'attendance-check-in'
                      : 'attendance-check-out',
                ),
                onPressed: isMarkingAttendance || !actionsEnabled
                    ? null
                    : status == AttendanceStatus.notCheckedIn
                    ? onCheckIn
                    : onCheckOut,
                icon: isMarkingAttendance
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        status == AttendanceStatus.notCheckedIn
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                      ),
                label: Text(
                  isMarkingAttendance
                      ? 'Saving attendance…'
                      : status == AttendanceStatus.notCheckedIn
                      ? 'Check In'
                      : 'Check Out',
                ),
              ),
            if (!checkedOut) ...[
              const SizedBox(height: 12),
              Text(
                'Attendance requires being within 200 metres of the office.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.secondaryText),
              ),
            ],
            if (attendance.syncStatus != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: AttendanceSyncBadge(status: attendance.syncStatus!),
              ),
            ],
            for (final message in attendance.rejectionMessages) ...[
              const SizedBox(height: 12),
              DashboardMessage(message: message, tone: StatusTone.error),
            ],
            if (actionMessage != null &&
                (!actionSucceeded || attendance.rejectionMessages.isEmpty)) ...[
              const SizedBox(height: 12),
              DashboardMessage(
                message: actionMessage!,
                tone: actionSucceeded ? StatusTone.info : StatusTone.error,
                action: resolutionLabel == null
                    ? null
                    : TextButton(
                        onPressed: onResolveIssue,
                        child: Text(resolutionLabel!),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  const _TimeInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

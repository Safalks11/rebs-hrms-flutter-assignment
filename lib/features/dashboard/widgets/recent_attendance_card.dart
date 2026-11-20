import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/utils/attendance_formatters.dart';
import 'dashboard_status.dart';

class RecentAttendanceCard extends StatelessWidget {
  final List<AttendanceModel> records;
  final bool loading;
  final String? error;

  const RecentAttendanceCard({
    super.key,
    required this.records,
    this.loading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Recent attendance', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Latest 5 records',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.secondaryText),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.dashboardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Loading attendance history',
                )
              else if (error != null && records.isEmpty)
                Text(
                  'Saved attendance history is unavailable.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else if (records.isEmpty) ...[
                const Icon(
                  Icons.event_note_outlined,
                  color: AppColors.secondaryText,
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No attendance records yet.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your records will appear here after check-in.',
                  textAlign: TextAlign.center,
                ),
              ],
              for (var index = 0; index < records.length; index++) ...[
                if (index > 0) const Divider(height: 32),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      AttendanceFormatters.formatDate(records[index].date),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (records[index].syncStatus != null)
                      AttendanceSyncBadge(status: records[index].syncStatus!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(AttendanceFormatters.statusText(records[index].status)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      'In  ${AttendanceFormatters.formatTime(records[index].checkInTime)}',
                    ),
                    Text(
                      'Out  ${AttendanceFormatters.formatTime(records[index].checkOutTime)}',
                    ),
                  ],
                ),
                for (final message in records[index].rejectionMessages) ...[
                  const SizedBox(height: 8),
                  DashboardMessage(message: message, tone: StatusTone.error),
                ],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

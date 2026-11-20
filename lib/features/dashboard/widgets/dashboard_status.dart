import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../attendance/models/attendance_event.dart';
import '../../attendance/utils/attendance_formatters.dart';

enum StatusTone {
  neutral(AppColors.secondaryText, AppColors.background, Icons.info_outline),
  info(AppColors.primary, AppColors.blueSurface, Icons.info_outline),
  success(
    AppColors.positive,
    AppColors.positiveSurface,
    Icons.check_circle_outline,
  ),
  warning(AppColors.warning, AppColors.warningSurface, Icons.schedule),
  error(AppColors.negative, AppColors.negativeSurface, Icons.error_outline);

  const StatusTone(this.foreground, this.background, this.icon);
  final Color foreground;
  final Color background;
  final IconData icon;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });
  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? tone.icon, size: 16, color: tone.foreground),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: tone.foreground, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class AttendanceSyncBadge extends StatelessWidget {
  const AttendanceSyncBadge({super.key, required this.status});
  final AttendanceSyncStatus status;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: AttendanceFormatters.syncStatusText(status),
    tone: switch (status) {
      AttendanceSyncStatus.pending => StatusTone.warning,
      AttendanceSyncStatus.synced => StatusTone.success,
      AttendanceSyncStatus.rejected => StatusTone.error,
    },
  );
}

class DashboardMessage extends StatelessWidget {
  const DashboardMessage({
    super.key,
    required this.message,
    this.tone = StatusTone.info,
    this.action,
  });
  final String message;
  final StatusTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(tone.icon, size: 20, color: tone.foreground),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tone.foreground),
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    ),
  );
}

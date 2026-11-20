import 'package:intl/intl.dart';
import 'package:rebs_hrms_assignment/core/utils/company_time.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';

class AttendanceFormatters {
  AttendanceFormatters._();

  static String formatDate(DateTime date) =>
      DateFormat('d MMM yyyy').format(date);

  static String formatTime(DateTime? time) => time == null
      ? '--:--'
      : DateFormat('hh:mm a').format(CompanyTime.toCompanyTime(time));

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  static String syncStatusText(AttendanceSyncStatus status) => switch (status) {
    AttendanceSyncStatus.pending => 'Pending Sync',
    AttendanceSyncStatus.synced => 'Synced',
    AttendanceSyncStatus.rejected => 'Rejected',
  };

  static String statusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.notCheckedIn:
        return 'Not Checked In';
      case AttendanceStatus.checkedIn:
        return 'Checked In';
      case AttendanceStatus.checkedOut:
        return 'Checked Out';
    }
  }
}

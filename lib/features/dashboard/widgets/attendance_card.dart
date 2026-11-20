import 'package:flutter/material.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/attendance/utils/attendance_formatters.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceModel attendance;
  final Duration? duration;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final bool isMarkingAttendance;
  final String? actionMessage;
  final String? resolutionLabel;
  final VoidCallback onResolveIssue;

  const AttendanceCard({
    super.key,
    required this.attendance,
    this.duration,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.isMarkingAttendance,
    required this.actionMessage,
    required this.resolutionLabel,
    required this.onResolveIssue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Attendance",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Text(
              'Status: ${AttendanceFormatters.statusText(attendance.status)}',
            ),
            if (attendance.syncStatus != null)
              Text(AttendanceFormatters.syncStatusText(attendance.syncStatus!)),
            for (final message in attendance.rejectionMessages) Text(message),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Check In',
                    AttendanceFormatters.formatTime(attendance.checkInTime),
                  ),
                ),
                Expanded(
                  child: _buildTimeInfo(
                    'Check Out',
                    AttendanceFormatters.formatTime(attendance.checkOutTime),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            Text(
              'Working Duration: '
              '${AttendanceFormatters.formatDuration(duration ?? attendance.workingDuration)}',
            ),

            const SizedBox(height: 16),

            if (attendance.status == AttendanceStatus.notCheckedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isMarkingAttendance ? null : onCheckIn,
                  child: Text(
                    isMarkingAttendance ? 'Saving attendance...' : 'Check In',
                  ),
                ),
              )
            else if (attendance.status == AttendanceStatus.checkedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isMarkingAttendance ? null : onCheckOut,
                  child: Text(
                    isMarkingAttendance ? 'Saving attendance...' : 'Check Out',
                  ),
                ),
              )
            else
              const SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: Text('Checked Out'),
                ),
              ),
            if (actionMessage != null) ...[
              const SizedBox(height: 12),
              Text(actionMessage!),
              if (resolutionLabel != null)
                TextButton(
                  onPressed: onResolveIssue,
                  child: Text(resolutionLabel!),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

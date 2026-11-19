import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceModel attendance;
  final Duration? duration;

  const AttendanceCard({super.key, required this.attendance, this.duration});

  String formatTime(DateTime? time) {
    if (time == null) return '--:--';
    return DateFormat('hh:mm a').format(time);
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  String getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.notCheckedIn:
        return 'Not Checked In';
      case AttendanceStatus.checkedIn:
        return 'Checked In';
      case AttendanceStatus.checkedOut:
        return 'Checked Out';
    }
  }

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

            Text('Status: ${getStatusText(attendance.status)}'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Check In',
                    formatTime(attendance.checkInTime),
                  ),
                ),
                Expanded(
                  child: _buildTimeInfo(
                    'Check Out',
                    formatTime(attendance.checkOutTime),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            Text(
              'Working Duration: '
              '${formatDuration(duration ?? attendance.workingDuration)}',
            ),
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

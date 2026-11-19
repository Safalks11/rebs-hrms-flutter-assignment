import 'package:flutter/material.dart';
import 'package:rebs_hrms_assignment/core/helper/attendance_formatters.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceModel attendance;
  final Duration? duration;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const AttendanceCard({
    super.key,
    required this.attendance,
    this.duration,
    required this.onCheckIn,
    required this.onCheckOut,
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
                  onPressed: onCheckIn,
                  child: const Text('Check In'),
                ),
              )
            else if (attendance.status == AttendanceStatus.checkedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCheckOut,
                  child: const Text('Check Out'),
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

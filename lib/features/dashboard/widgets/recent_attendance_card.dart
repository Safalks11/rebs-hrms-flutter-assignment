import 'package:flutter/material.dart';
import 'package:rebs_hrms_assignment/core/helper/attendance_formatters.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';

class RecentAttendanceCard extends StatelessWidget {
  final List<AttendanceModel> records;

  const RecentAttendanceCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest 5 Attendance Records',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (records.isEmpty) const Text('No attendance records yet.'),
            for (var index = 0; index < records.length; index++) ...[
              if (index > 0) const Divider(height: 24),
              Text(
                AttendanceFormatters.formatDate(records[index].date),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(AttendanceFormatters.statusText(records[index].status)),
              Text(
                'Check In: ${AttendanceFormatters.formatTime(records[index].checkInTime)}',
              ),
              Text(
                'Check Out: ${AttendanceFormatters.formatTime(records[index].checkOutTime)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/company_time.dart';
import '../../../core/widgets/network_indicator.dart';
import '../controllers/leave_controller.dart';
import '../models/leave_request.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});
  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final controller = Get.find<LeaveController>();
  final reason = TextEditingController();
  LeaveType type = LeaveType.casual;
  DateTime? start, end;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> pick(bool first) async {
    final today = CompanyTime.attendanceDate(DateTime.now());
    final value = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
      initialDate: today,
    );
    if (value != null && mounted) {
      setState(() {
        final d = DateTime.utc(value.year, value.month, value.day);
        if (first) {
          start = d;
        } else {
          end = d;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Leave')),
    body: Obx(
      () => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NetworkIndicator(),
          if (controller.loading.value) const LinearProgressIndicator(),
          Text(
            'Available Casual: ${controller.repository.balances[LeaveType.casual] ?? 'Unavailable'} • Sick: ${controller.repository.balances[LeaveType.sick] ?? 'Unavailable'}',
          ),
          if (controller.message.value != null) Text(controller.message.value!),
          TextButton(
            onPressed: controller.submitting.value ? null : controller.refresh,
            child: const Text('Refresh'),
          ),
          const Text('Apply Leave'),
          DropdownButton<LeaveType>(
            value: type,
            items: LeaveType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                      t == LeaveType.casual ? 'Casual Leave' : 'Sick Leave',
                    ),
                  ),
                )
                .toList(),
            onChanged: controller.submitting.value
                ? null
                : (v) => setState(() => type = v!),
          ),
          TextButton(
            onPressed: () => pick(true),
            child: Text(
              start == null
                  ? 'Select start date'
                  : LeaveRequest.dateKey(start!),
            ),
          ),
          TextButton(
            onPressed: () => pick(false),
            child: Text(
              end == null ? 'Select end date' : LeaveRequest.dateKey(end!),
            ),
          ),
          TextField(
            controller: reason,
            enabled: !controller.submitting.value,
            decoration: const InputDecoration(labelText: 'Reason'),
            maxLines: 3,
          ),
          FilledButton(
            onPressed: controller.submitting.value
                ? null
                : () async {
                    if (start == null || end == null) {
                      controller.message.value = 'Select both dates.';
                      return;
                    }
                    final ok = await controller.submit(
                      LeaveRequest(
                        id: '',
                        employeeId: controller.repository.employeeId,
                        type: type,
                        startDate: start!,
                        endDate: end!,
                        reason: reason.text.trim(),
                      ),
                    );
                    if (ok && mounted) {
                      setState(() {
                        start = null;
                        end = null;
                        reason.clear();
                      });
                    }
                  },
            child: Text(
              controller.submitting.value ? 'Submitting…' : 'Submit leave',
            ),
          ),
          const Text('Leave history'),
          if (controller.repository.requests.isEmpty)
            const Text('No saved leave requests.'),
          ...controller.repository.requests.map(
            (r) => ListTile(
              title: Text(
                '${r.type.name.capitalizeFirst} Leave • ${r.status.name.capitalizeFirst}',
              ),
              subtitle: Text(
                '${LeaveRequest.dateKey(r.startDate)} – ${LeaveRequest.dateKey(r.endDate)}\n${r.reason}',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
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
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> pick(bool first) async {
    final range = controller.datePickerRange(isStart: first);
    final value = await showDatePicker(
      context: context,
      firstDate: range.firstDate,
      lastDate: range.lastDate,
      initialDate: range.initialDate,
    );
    if (value != null && mounted) {
      controller.selectDate(value, isStart: first);
    }
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    final accepted = await controller.submitForm(reason.text);
    if (accepted && mounted) reason.clear();
  }

  Widget section(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  Widget dateButton(bool first) {
    final value = first ? controller.startDate.value : controller.endDate.value;
    return OutlinedButton.icon(
      onPressed: controller.submitting.value ? null : () => pick(first),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.calendar_today_outlined, size: 20),
      label: Text(
        value == null
            ? first
                  ? 'Select start date'
                  : 'Select end date'
            : '${first ? 'From' : 'To'}  ${DateFormat('d MMM yyyy').format(value)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dashboard(Theme.of(context)),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Leave'),
          actions: [
            Obx(
              () => IconButton(
                tooltip: 'Refresh leave',
                onPressed: !controller.canRefresh ? null : controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Plan your time away',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'View your balances, request leave and track approvals.',
                      ),
                      const SizedBox(height: 12),
                      const NetworkIndicator(),
                      Obx(
                        () => controller.loading.value
                            ? const LinearProgressIndicator(
                                semanticsLabel: 'Loading leave',
                              )
                            : const SizedBox(height: 4),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => section(context, 'Available balance', [
                          Row(
                            spacing: 24,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final t in LeaveType.values)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        t == LeaveType.casual
                                            ? Icons.wb_sunny_outlined
                                            : Icons.favorite_border,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        t == LeaveType.casual
                                            ? 'Casual Leave'
                                            : 'Sick Leave',
                                      ),
                                      Text(
                                        controller.repository.balances[t] ==
                                                null
                                            ? 'Unavailable'
                                            : '${controller.repository.balances[t]} days',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      Obx(
                        () => section(context, 'Apply Leave', [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in LeaveType.values)
                                ChoiceChip(
                                  label: Text(
                                    t == LeaveType.casual
                                        ? 'Casual Leave'
                                        : 'Sick Leave',
                                  ),
                                  selected: controller.selectedType.value == t,
                                  onSelected: controller.submitting.value
                                      ? null
                                      : (_) => controller.selectType(t),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          dateButton(true),
                          const SizedBox(height: 12),
                          dateButton(false),
                          const SizedBox(height: 12),
                          Text(
                            controller.requestedDays != null
                                ? '${controller.requestedDays} calendar days requested'
                                : 'All calendar days count, including weekends and holidays.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: reason,
                            enabled: !controller.submitting.value,
                            minLines: 3,
                            maxLines: 6,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Reason',
                              hintText: 'Tell us why you need time away',
                              helperText:
                                  'At least 10 non-whitespace characters.',
                              helperMaxLines: 3,
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (controller.message.value != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.blueSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(controller.message.value!),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (!controller.isConnected) ...[
                            const Text(
                              'Connect to a network to submit. Your saved requests are available below.',
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            onPressed: !controller.canSubmit ? null : submit,
                            child: Text(
                              controller.submitting.value
                                  ? 'Submitting…'
                                  : 'Submit leave',
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Leave history',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (controller.repository.requests.isEmpty &&
                                !controller.loading.value)
                              section(context, 'No saved leave requests.', [
                                const Text(
                                  'Your requests and their approval status will appear here.',
                                ),
                              ]),
                            for (final r in controller.repository.requests) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${r.type.name.capitalizeFirst} Leave • ${r.status.name.capitalizeFirst}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: switch (r.status) {
                                                LeaveStatus.pending =>
                                                  AppColors.warning,
                                                LeaveStatus.approved =>
                                                  AppColors.positive,
                                                LeaveStatus.rejected =>
                                                  AppColors.negative,
                                              },
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${DateFormat('d MMM yyyy').format(r.startDate)} – ${DateFormat('d MMM yyyy').format(r.endDate)}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${r.days} calendar days',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const Divider(height: 24),
                                      Text(r.reason),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
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
  );
}

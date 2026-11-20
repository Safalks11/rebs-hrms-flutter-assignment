import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';

class LeaveBalanceCard extends StatelessWidget {
  final int? casualDays;
  final int? sickDays;
  final VoidCallback onManageLeave;

  const LeaveBalanceCard({
    super.key,
    required this.casualDays,
    required this.sickDays,
    required this.onManageLeave,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text('Leave balance', style: Theme.of(context).textTheme.titleMedium),
          TextButton(
            key: const ValueKey('manage-leave'),
            onPressed: onManageLeave,
            child: const Text('Manage leave'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.dashboardPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final casual = _Balance(
                label: 'Casual Leave',
                days: casualDays,
                icon: Icons.wb_sunny_outlined,
              );
              final sick = _Balance(
                label: 'Sick Leave',
                days: sickDays,
                icon: Icons.favorite_border,
              );
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [casual, const Divider(height: 32), sick],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: casual),
                  const SizedBox(width: 24),
                  Expanded(child: sick),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}

class _Balance extends StatelessWidget {
  const _Balance({required this.label, required this.days, required this.icon});
  final String label;
  final int? days;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.primary, size: 22),
      const SizedBox(height: 12),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      Text(
        days?.toString() ?? 'Unavailable',
        style: days == null
            ? Theme.of(context).textTheme.bodyMedium
            : Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
      ),
      if (days != null)
        Text(
          'days available',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.secondaryText),
        ),
    ],
  );
}

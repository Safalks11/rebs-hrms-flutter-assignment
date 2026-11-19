import 'package:flutter/material.dart';

class LeaveBalanceCard extends StatelessWidget {
  final int casualDays;
  final int sickDays;

  const LeaveBalanceCard({
    super.key,
    required this.casualDays,
    required this.sickDays,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Leave Balance', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Casual Leave: $casualDays days'),
            const SizedBox(height: 8),
            Text('Sick Leave: $sickDays days'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  const EmployeeCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final initials = employee.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.blueSurface,
            foregroundColor: AppColors.primary,
            child: Text(
              initials,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${employee.id} · ${employee.department}',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

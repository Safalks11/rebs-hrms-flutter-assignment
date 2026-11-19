import 'package:flutter/material.dart';

import '../models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;

  const EmployeeCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${employee.id}'),
                  Text(employee.department),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

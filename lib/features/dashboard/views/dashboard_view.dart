import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/dashboard/controllers/dashboard_controller.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/employee_card.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: EmployeeCard(employee: controller.employee),
        ),
      ),
    );
  }
}

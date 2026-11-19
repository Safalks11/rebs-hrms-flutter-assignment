import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/dashboard/models/employee_model.dart';

class DashboardController extends GetxController {
  final EmployeeModel employee = const EmployeeModel(
    id: 'EMP001',
    name: 'Alex Johnson',
    department: 'Engineering',
  );
}

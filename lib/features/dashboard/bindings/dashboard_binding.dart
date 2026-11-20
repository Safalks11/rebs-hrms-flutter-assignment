import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/dashboard/controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(
      () => DashboardController(Get.find<AttendanceLocationService>()),
    );
  }
}

import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../attendance/services/attendance_location_service.dart';
import '../../attendance/services/attendance_store.dart';
import '../../attendance/services/attendance_sync_service.dart';
import '../../leave/services/leave_repository.dart';
import '../../office_profile/services/office_profile_store.dart';
import '../controllers/dashboard_controller.dart';
import '../services/employee_store.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(
      () => DashboardController(
        Get.find<AttendanceLocationService>(),
        Get.find<AttendanceStore>(),
        Get.find<ConnectivityService>(),
        Get.find<AttendanceSyncService>(),
        Get.find<ApiService>(),
        Get.find<EmployeeStore>(),
        Get.find<LeaveRepository>(),
        Get.find<OfficeProfileStore>(),
      ),
    );
  }
}

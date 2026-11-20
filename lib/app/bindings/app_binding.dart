import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';

import '../../core/services/api_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../features/attendance/services/attendance_sync_service.dart';
import '../../features/dashboard/services/employee_store.dart';
import '../../features/leave/services/leave_repository.dart';
import '../../features/office_profile/services/office_profile_store.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ConnectivityService(), permanent: true);
    Get.put(ApiService(), permanent: true);
    Get.put<AppDatabase>(AppDatabase(), permanent: true);
    Get.put(
      LeaveRepository(Get.find<AppDatabase>(), Get.find<ApiService>()),
      permanent: true,
    );
    Get.put(AttendanceStore(Get.find<AppDatabase>()), permanent: true);
    Get.put(OfficeProfileStore(Get.find<AppDatabase>()), permanent: true);
    Get.put(EmployeeStore(Get.find<AppDatabase>()), permanent: true);
    Get.put(
      AttendanceSyncService(
        Get.find<AttendanceStore>(),
        Get.find<ApiService>(),
        Get.find<ConnectivityService>(),
      ),
      permanent: true,
    );
    Get.put(
      AttendanceLocationService(Get.find<OfficeProfileStore>()),
      permanent: true,
    );
  }
}

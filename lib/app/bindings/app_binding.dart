import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';
import 'package:rebs_hrms_assignment/features/office_profile/services/office_profile_store.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppDatabase>(AppDatabase(), permanent: true);
    Get.put<OfficeProfileStore>(
      OfficeProfileStore(Get.find<AppDatabase>()),
      permanent: true,
    );
    Get.put<AttendanceStore>(
      AttendanceStore(Get.find<AppDatabase>()),
      permanent: true,
    );
    Get.put<AttendanceLocationService>(
      AttendanceLocationService(Get.find<OfficeProfileStore>()),
      permanent: true,
    );
  }
}

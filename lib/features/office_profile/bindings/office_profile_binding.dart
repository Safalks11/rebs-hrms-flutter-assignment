import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/office_profile/controllers/office_profile_controller.dart';
import 'package:rebs_hrms_assignment/features/office_profile/services/office_profile_store.dart';

class OfficeProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OfficeProfileController>(
      () => OfficeProfileController(Get.find<OfficeProfileStore>()),
    );
  }
}

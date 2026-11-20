import 'package:get/get.dart';

import '../../../core/services/connectivity_service.dart';

import '../controllers/leave_controller.dart';
import '../services/leave_repository.dart';

class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => LeaveController(
        Get.find<LeaveRepository>(),
        Get.find<ConnectivityService>(),
      ),
    );
  }
}

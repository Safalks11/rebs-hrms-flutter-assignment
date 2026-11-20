import 'package:get/get.dart';

import '../../../core/services/connectivity_service.dart';

import '../models/leave_request.dart';
import '../services/leave_repository.dart';

class LeaveController extends GetxController {
  final LeaveRepository repository;
  final ConnectivityService connectivity;
  LeaveController(this.repository, this.connectivity);
  final loading = false.obs, submitting = false.obs;
  final message = RxnString(
    'Leave submission is unavailable until API integration is added.',
  );

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  @override
  Future<void> refresh() async {
    if (loading.value) return;
    loading.value = true;
    try {
      await repository.refresh();
      message.value =
          'Showing saved data. Leave submission awaits API integration.';
    } catch (_) {
      message.value = 'Could not load saved leave data. Please retry.';
    } finally {
      loading.value = false;
    }
  }

  Future<bool> submit(LeaveRequest request) async {
    if (loading.value || submitting.value) return false;
    final error = validateLeave(
      request,
      repository.balances,
      repository.requests,
      DateTime.now(),
    );
    if (error != null) {
      message.value = error;
      return false;
    }
    submitting.value = true;
    try {
      final status = await connectivity.checkNow();
      if (isClosed) return false;
      message.value = switch (status) {
        NetworkStatus.disconnected =>
          'Connect to a network before submitting leave.',
        NetworkStatus.unknown =>
          'Could not determine network status. Retry the connection check.',
        NetworkStatus.connected =>
          'Leave submission is unavailable until API integration is added.',
      };
      return false;
    } finally {
      if (!isClosed) submitting.value = false;
    }
  }
}

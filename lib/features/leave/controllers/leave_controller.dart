import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/connectivity_service.dart';
import '../models/leave_request.dart';
import '../services/leave_repository.dart';

class LeaveController extends GetxController {
  final LeaveRepository repository;
  final ConnectivityService connectivity;
  LeaveController(this.repository, this.connectivity);

  final loading = false.obs;
  final submitting = false.obs;
  final message = RxnString();
  LeaveRequest? _uncertain;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  @override
  Future<void> refresh() async {
    if (isClosed || loading.value || submitting.value) return;
    loading.value = true;
    try {
      await repository.loadCache();
      if (await connectivity.checkNow() == NetworkStatus.connected) {
        await repository.refresh();
        if (!isClosed) message.value = null;
      } else if (!isClosed) {
        message.value = 'Offline. Showing saved leave data.';
      }
    } catch (error) {
      if (!isClosed) message.value = repository.api.message(error);
    } finally {
      if (!isClosed) loading.value = false;
    }
  }

  Future<bool> submit(LeaveRequest draft) async {
    if (isClosed || loading.value || submitting.value) return false;
    submitting.value = true;
    LeaveRequest? request;
    try {
      if (await connectivity.checkNow() != NetworkStatus.connected) {
        message.value = 'Connect to a network before submitting leave.';
        return false;
      }
      final previous = _uncertain;
      final sameDraft =
          previous != null &&
          previous.type == draft.type &&
          previous.startDate == draft.startDate &&
          previous.endDate == draft.endDate &&
          previous.reason == draft.reason;
      if (sameDraft) {
        await repository.refresh();
        if (repository.requests.any((item) => item.id == previous.id)) {
          _uncertain = null;
          message.value = 'Leave submitted.';
          return true;
        }
      }
      final error = validateLeave(
        draft,
        repository.balances,
        repository.requests,
        DateTime.now(),
      );
      if (error != null) {
        message.value = error;
        return false;
      }
      request = LeaveRequest(
        id: sameDraft ? previous.id : const Uuid().v4(),
        employeeId: repository.employeeId,
        type: draft.type,
        startDate: draft.startDate,
        endDate: draft.endDate,
        reason: draft.reason,
      );
      _uncertain = request;
      final created = await repository.submit(request);
      final balances = Map<LeaveType, int>.from(repository.balances);
      if (created.status != LeaveStatus.rejected &&
          !repository.requests.any((item) => item.id == created.id)) {
        balances[created.type] = balances[created.type]! - created.days;
      }
      await repository.saveCache(
        balances: balances,
        requests: [
          ...repository.requests.where((item) => item.id != created.id),
          created,
        ],
      );
      _uncertain = null;
      try {
        await repository.refresh();
      } catch (_) {
        // The confirmed response is already saved locally.
      }
      message.value = 'Leave submitted.';
      return true;
    } on DioException catch (error) {
      if (error.response == null && request != null) {
        _uncertain = request;
        message.value =
            'Submission may have succeeded. Refresh history before retrying.';
      } else {
        message.value = repository.api.message(error);
        try {
          await repository.refresh();
        } catch (_) {
          // Keep the saved history visible.
        }
      }
      return false;
    } catch (error) {
      message.value = repository.api.message(error);
      return false;
    } finally {
      if (!isClosed) submitting.value = false;
    }
  }
}

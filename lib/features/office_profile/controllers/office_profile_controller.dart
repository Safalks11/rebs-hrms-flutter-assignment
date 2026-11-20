import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/office_profile/models/office_location.dart';
import 'package:rebs_hrms_assignment/features/office_profile/services/office_profile_store.dart';

class OfficeProfileController extends GetxController {
  final OfficeProfileStore _store;

  OfficeProfileController(this._store);

  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();
  final isLoading = true.obs;
  final isSaving = false.obs;
  final message = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final office = await _store.load();
      if (isClosed) return;
      if (office != null) {
        latitudeController.text = office.latitude.toString();
        longitudeController.text = office.longitude.toString();
      }
    } catch (_) {
      if (!isClosed) {
        message.value = 'Could not load the saved office location.';
      }
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  Future<void> save() async {
    if (isLoading.value || isSaving.value || isClosed) return;
    final latitude = double.tryParse(latitudeController.text.trim());
    final longitude = double.tryParse(longitudeController.text.trim());
    if (latitude == null || longitude == null) {
      message.value = 'Enter valid numbers for both coordinates.';
      return;
    }
    final office = OfficeLocation(latitude: latitude, longitude: longitude);
    if (!office.isValid) {
      message.value = 'Latitude must be -90 to 90 and longitude -180 to 180.';
      return;
    }
    isSaving.value = true;
    message.value = null;
    try {
      await _store.save(office);
      if (!isClosed) message.value = 'Office location saved.';
    } catch (_) {
      if (!isClosed) message.value = 'Could not save the office location.';
    } finally {
      if (!isClosed) isSaving.value = false;
    }
  }

  @override
  void onClose() {
    latitudeController.dispose();
    longitudeController.dispose();
    super.onClose();
  }
}

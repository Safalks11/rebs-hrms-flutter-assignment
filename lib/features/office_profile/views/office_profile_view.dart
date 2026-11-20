import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/features/office_profile/controllers/office_profile_controller.dart';

class OfficeProfileScreen extends GetView<OfficeProfileController> {
  const OfficeProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Office Profile')),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Set the office location used for attendance validation on this device.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller.latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller.longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: controller.isSaving.value
                          ? null
                          : controller.save,
                      child: Text(
                        controller.isSaving.value
                            ? 'Saving...'
                            : 'Save Office Location',
                      ),
                    ),
                    if (controller.message.value != null) ...[
                      const SizedBox(height: 12),
                      Text(controller.message.value!),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

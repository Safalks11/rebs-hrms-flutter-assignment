import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/connectivity_service.dart';

class NetworkIndicator extends StatelessWidget {
  const NetworkIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    final service = Get.find<ConnectivityService>();
    return Obx(() {
      final status = service.status.value;
      final label = switch (status) {
        NetworkStatus.connected => 'Network connected',
        NetworkStatus.disconnected => 'Offline — saved data remains available',
        NetworkStatus.unknown => 'Network status unavailable',
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              status == NetworkStatus.connected ? Icons.wifi : Icons.wifi_off,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            if (status == NetworkStatus.unknown)
              TextButton(
                onPressed: service.checkNow,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    });
  }
}

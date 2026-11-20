import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/core/services/connectivity_service.dart';
import 'package:rebs_hrms_assignment/core/widgets/network_indicator.dart';

void main() {
  testWidgets('offline indicator keeps saved-data message visible', (
    tester,
  ) async {
    final service = ConnectivityService(
      check: () async => [ConnectivityResult.none],
      changes: const Stream<List<ConnectivityResult>>.empty(),
    );
    Get.put<ConnectivityService>(service);
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: NetworkIndicator())),
    );
    await service.checkNow();
    await tester.pump();
    expect(find.text('Offline — saved data remains available'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();
  });
}

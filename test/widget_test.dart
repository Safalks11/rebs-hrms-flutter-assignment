import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/core/services/app_feedback.dart';
import 'package:rebs_hrms_assignment/core/services/api_service.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/features/leave/controllers/leave_controller.dart';
import 'package:rebs_hrms_assignment/features/leave/services/leave_repository.dart';
import 'package:rebs_hrms_assignment/core/services/connectivity_service.dart';
import 'package:rebs_hrms_assignment/core/widgets/network_indicator.dart';

void main() {
  testWidgets('success and repeated validation failures show snackbars', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: AppFeedback.messengerKey,
        home: const Scaffold(body: Text('Leave')),
      ),
    );
    AppFeedback.show('Saved successfully.', kind: FeedbackKind.success);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Saved successfully.'),
      ),
      findsOneWidget,
    );
    final connectivity = ConnectivityService(
      check: () async => [ConnectivityResult.none],
      changes: const Stream<List<ConnectivityResult>>.empty(),
    );
    final controller = LeaveController(
      LeaveRepository(AppDatabase(), ApiService()),
      connectivity,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(await controller.submitForm('Family appointment'), isFalse);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Select both dates.'),
        ),
        findsOneWidget,
      );
      expect(controller.message.value, 'Select both dates.');
      AppFeedback.messengerKey.currentState!.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    AppFeedback.show('No mounted screen');
  });

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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rebs_hrms_assignment/core/services/api_service.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/core/services/connectivity_service.dart';
import 'package:rebs_hrms_assignment/core/utils/company_time.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';
import 'package:rebs_hrms_assignment/features/dashboard/controllers/dashboard_controller.dart';
import 'package:rebs_hrms_assignment/features/leave/controllers/leave_controller.dart';
import 'package:rebs_hrms_assignment/features/leave/models/leave_request.dart';
import 'package:rebs_hrms_assignment/features/leave/services/leave_repository.dart';
import 'package:rebs_hrms_assignment/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('QA_PHASE', defaultValue: 'suite');
  testWidgets('isolated live QA: $phase', (tester) async {
    expect(
      const String.fromEnvironment('API_BASE_URL'),
      'http://10.0.2.2:8081',
    );
    app.main();
    await tester.pump();
    final controller = Get.find<DashboardController>();
    final database = Get.find<AppDatabase>();
    final api = Get.find<ApiService>();
    final leave = Get.find<LeaveRepository>();
    final store = Get.find<AttendanceStore>();
    Future<void> waitFor(bool Function() ready, String label) async {
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (!ready() && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }
      if (!ready()) {
        await tester.runAsync(() async {
          final health = await api.dio.get('/health');
          debugPrint(
            'QA clock: device=${DateTime.now().toUtc()} server=${health.headers.value('date')} events=${await (await database.db).query('attendance_events')}',
          );
        });
      }
      expect(
        ready(),
        isTrue,
        reason:
            '$label: action=${controller.actionMessage.value}, sync=${controller.syncMessage.value}, server=${controller.serverMessage.value}, rejected=${controller.attendance.value.rejectionMessages}',
      );
      expect(tester.takeException(), isNull, reason: label);
    }

    Future<void> run(Future<void> Function() work) async {
      await tester.runAsync(work);
      await tester.pump();
    }

    Future<List<dynamic>> serverEvents() async {
      final month = CompanyTime.attendanceDateKey(DateTime.now())
          .substring(0, 7);
      final result = await api.dio.get<Map<String, dynamic>>(
        '/attendance',
        queryParameters: {'month': month},
      );
      return result.data!['events'] as List;
    }

    Future<void> reset() async {
      await run(() async {
        await api.dio.post<void>('/__qa/reset');
        await (await database.db).delete('attendance_events');
        await controller.refreshDashboard();
      });
      expect(controller.attendance.value.status, AttendanceStatus.notCheckedIn);
    }

    await waitFor(() => !controller.isLoading.value, 'local startup');
    if (phase == 'offline_seed') {
      await run(() async {
        expect(
          await Get.find<ConnectivityService>().checkNow(),
          NetworkStatus.disconnected,
        );
        await controller.checkIn();
      });
      await waitFor(() => !controller.checkingSync.value, 'offline check-in');
      expect(
        controller.attendance.value.status,
        AttendanceStatus.checkedIn,
        reason: controller.actionMessage.value,
      );
      await run(controller.checkOut);
      await waitFor(() => !controller.checkingSync.value, 'offline check-out');
      expect(
        controller.pendingCount.value,
        2,
        reason:
            '${controller.actionMessage.value}; ${controller.storageError.value}; ${controller.attendance.value.rejectionMessages}',
      );
      expect(leave.requests, isNotEmpty);
    } else if (phase == 'offline_verify') {
      await run(() async {
        expect(
          await Get.find<ConnectivityService>().checkNow(),
          NetworkStatus.disconnected,
        );
        expect(await store.countPendingEvents('EMP001'), 2);
      });
      expect(controller.attendance.value.status, AttendanceStatus.checkedOut);
      expect(leave.requests, isNotEmpty);
    } else if (phase == 'online_verify') {
      await waitFor(
        () =>
            controller.pendingCount.value == 0 &&
            controller.attendance.value.syncStatus ==
                AttendanceSyncStatus.synced,
        'restart synchronization',
      );
      await run(() async {
        final events = await serverEvents();
        expect(events.length, 2);
        expect(events.map((e) => (e as Map)['type']), ['checkIn', 'checkOut']);
      });
    } else {
      await waitFor(
        () =>
            leave.balances.isNotEmpty && controller.serverMessage.value == null,
        'API startup',
      );
      await run(controller.refreshDashboard);
      await reset();
      if (phase == 'prepare') {
        expect(leave.requests.length, 3);
      } else {
        // Real device GPS and real HTTP; quick repeated taps must create one event.
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Check In'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Check In'));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Check In'));
        await waitFor(
          () =>
              controller.attendance.value.syncStatus ==
              AttendanceSyncStatus.synced,
          'online check-in',
        );
        await run(() async {
          expect((await serverEvents()).length, 1);
        });
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Check Out'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Check Out'));
        await waitFor(
          () =>
              controller.attendance.value.status ==
                  AttendanceStatus.checkedOut &&
              controller.attendance.value.syncStatus ==
                  AttendanceSyncStatus.synced,
          'online check-out',
        );
        final attendance = controller.attendance.value;
        expect(
          attendance.workingDurationAt(
            DateTime.now().add(const Duration(hours: 1)),
          ),
          attendance.workingDurationAt(DateTime.now()),
        );

        await reset();
        String? scenario = 'server-error';
        final interceptor = InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST' &&
                !options.path.startsWith('/__qa') &&
                scenario != null) {
              options.headers['X-Mock-Scenario'] = scenario;
            }
            handler.next(options);
          },
        );
        api.dio.interceptors.add(interceptor);
        await run(controller.checkIn);
        await waitFor(() => !controller.checkingSync.value, 'server failure');
        expect(controller.pendingCount.value, 1);
        scenario = null;
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await waitFor(
          () => controller.pendingCount.value == 0,
          'resume retries pending events',
        );

        await reset();
        scenario = 'timeout-after-commit';
        api.dio.options.receiveTimeout = const Duration(milliseconds: 500);
        await run(controller.checkIn);
        await waitFor(
          () => !controller.checkingSync.value,
          'ambiguous timeout',
        );
        expect(controller.pendingCount.value, 1);
        await run(() async {
          expect((await serverEvents()).length, 1);
          await Future<void>.delayed(const Duration(seconds: 2));
        });
        scenario = null;
        api.dio.options.receiveTimeout = const Duration(seconds: 12);
        await run(controller.syncNow);
        expect(controller.pendingCount.value, 0);
        await run(() async {
          expect((await serverEvents()).length, 1);
        });

        await reset();
        scenario = 'attendance-conflict';
        await run(controller.checkIn);
        await waitFor(() => !controller.checkingSync.value, 'server conflict');
        expect(
          controller.attendance.value.rejectionMessages.single,
          contains('Simulated rejection.'),
        );
        scenario = null;
        await reset();

        await tester.ensureVisible(find.text('Manage leave'));
        await tester.tap(find.text('Manage leave'));
        await tester.pumpAndSettle();
        final leaveController = Get.find<LeaveController>();
        await waitFor(() => !leaveController.loading.value, 'leave loading');
        await tester.ensureVisible(find.text('Submit leave'));
        await tester.tap(find.text('Submit leave'));
        await tester.pump();
        expect(find.text('Select both dates.'), findsOneWidget);
        final today = CompanyTime.attendanceDate(DateTime.now());
        LeaveRequest request({
          DateTime? start,
          DateTime? end,
          String reason = 'Family appointment',
        }) => LeaveRequest(
          id: '',
          employeeId: 'EMP001',
          type: LeaveType.casual,
          startDate: start ?? today,
          endDate: end ?? today,
          reason: reason,
        );
        await run(() async {
          expect(
            await leaveController.submit(
              request(start: today.subtract(const Duration(days: 1))),
            ),
            isFalse,
          );
          expect(
            await leaveController.submit(
              request(end: today.subtract(const Duration(days: 1))),
            ),
            isFalse,
          );
          expect(
            await leaveController.submit(request(reason: '12345 6789')),
            isFalse,
          );
          expect(
            await leaveController.submit(
              request(end: today.add(const Duration(days: 8))),
            ),
            isFalse,
          );
          expect(
            await leaveController.submit(
              request(
                start: today.add(const Duration(days: 7)),
                end: today.add(const Duration(days: 7)),
              ),
            ),
            isFalse,
          );
          scenario = 'leave-rejection';
          expect(await leaveController.submit(request()), isFalse);
          expect(leaveController.message.value, 'Simulated rejection.');
          scenario = 'timeout-after-commit';
          api.dio.options.receiveTimeout = const Duration(milliseconds: 500);
          expect(await leaveController.submit(request()), isFalse);
          scenario = null;
          api.dio.options.receiveTimeout = const Duration(seconds: 12);
          await Future<void>.delayed(const Duration(seconds: 2));
          expect(await leaveController.submit(request()), isTrue);
          expect(leave.requests.length, 4);
          expect(leave.balances[LeaveType.casual], 6);
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('Casual Leave • Pending'), findsWidgets);
        api.dio.interceptors.remove(interceptor);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await run(() async {
      Get.reset();
      await database.close();
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}

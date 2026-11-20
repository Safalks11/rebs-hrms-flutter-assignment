import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms_assignment/app/routes/app_routes.dart';
import 'package:rebs_hrms_assignment/app/theme/app_theme.dart';
import 'package:rebs_hrms_assignment/core/services/api_service.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/core/services/connectivity_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_model.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_sync_service.dart';
import 'package:rebs_hrms_assignment/features/dashboard/controllers/dashboard_controller.dart';
import 'package:rebs_hrms_assignment/features/dashboard/models/employee_model.dart';
import 'package:rebs_hrms_assignment/features/dashboard/services/employee_store.dart';
import 'package:rebs_hrms_assignment/features/dashboard/views/dashboard_view.dart';
import 'package:rebs_hrms_assignment/features/dashboard/widgets/attendance_card.dart';
import 'package:rebs_hrms_assignment/features/leave/bindings/leave_binding.dart';
import 'package:rebs_hrms_assignment/features/leave/controllers/leave_controller.dart';
import 'package:rebs_hrms_assignment/features/leave/models/leave_request.dart';
import 'package:rebs_hrms_assignment/features/leave/services/leave_repository.dart';
import 'package:rebs_hrms_assignment/features/leave/views/leave_view.dart';
import 'package:rebs_hrms_assignment/features/office_profile/services/office_profile_store.dart';

final _day = DateTime.utc(2026, 11, 20);
final _checkIn = DateTime.utc(2026, 11, 20, 4);
final _checkOut = DateTime.utc(2026, 11, 20, 8, 32);

class _TestLeaveRepository extends LeaveRepository {
  _TestLeaveRepository(super.database, super.api);
  @override
  Future<void> loadCache() async {}
  @override
  Future<void> refresh() async {}
}

class _TestDashboardController extends DashboardController {
  _TestDashboardController(
    AppDatabase database,
    ApiService api,
    ConnectivityService connectivity,
    LeaveRepository repository,
  ) : super(
        AttendanceLocationService(OfficeProfileStore(database)),
        AttendanceStore(database),
        connectivity,
        AttendanceSyncService(AttendanceStore(database), api, connectivity),
        api,
        EmployeeStore(database),
        repository,
        OfficeProfileStore(database),
      );
  int checkInCalls = 0;
  int checkOutCalls = 0;
  int syncCalls = 0;
  int refreshCalls = 0;
  int retryCalls = 0;
  int settingsCalls = 0;

  // Keep this widget harness independent of production timers and startup I/O.
  @override
  // ignore: must_call_super
  void onInit() {
    attendance = AttendanceModel(date: _day).obs;
    currentTime.value = _checkOut;
    pendingCount.value = 0;
    isLoading.value = false;
    hasLoadedAttendance.value = true;
  }

  @override
  Future<void> checkIn() async {
    checkInCalls++;
    isMarkingAttendance.value = true;
  }

  @override
  Future<void> checkOut() async {
    checkOutCalls++;
    isMarkingAttendance.value = true;
  }

  @override
  Future<void> syncNow() async {
    syncCalls++;
    checkingSync.value = true;
  }

  @override
  Future<void> refreshDashboard() async {
    refreshCalls++;
  }

  @override
  Future<void> refreshAttendance() async {
    retryCalls++;
    storageError.value = null;
  }

  @override
  Future<void> resolveLocationFailure() async {
    settingsCalls++;
  }
}

void main() {
  late _TestDashboardController controller;
  late ConnectivityService connectivity;
  late _TestLeaveRepository leave;

  setUp(() async {
    Get.testMode = true;
    final database = AppDatabase();
    final api = ApiService();
    connectivity = ConnectivityService(
      check: () async => [ConnectivityResult.wifi],
      changes: const Stream<List<ConnectivityResult>>.empty(),
    );
    Get.put<ConnectivityService>(connectivity);
    await connectivity.checkNow();
    leave = _TestLeaveRepository(database, api);
    leave.balances.assignAll({LeaveType.casual: 7, LeaveType.sick: 4});
    Get.put<LeaveRepository>(leave);
    controller = _TestDashboardController(database, api, connectivity, leave);
    Get.put<DashboardController>(controller);
  });
  tearDown(() {
    Get.reset();
  });

  Future<void> showDashboard(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const DashboardScreen(),
        getPages: [
          GetPage(
            name: AppRoutes.leave,
            page: () => const LeaveScreen(),
            binding: LeaveBinding(),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  for (final status in AttendanceStatus.values) {
    testWidgets('attendance action matches ${status.name}', (tester) async {
      controller.attendance.value = AttendanceModel(
        date: _day,
        checkInTime: status == AttendanceStatus.notCheckedIn ? null : _checkIn,
        checkOutTime: status == AttendanceStatus.checkedOut ? _checkOut : null,
      );
      await showDashboard(tester);
      if (status == AttendanceStatus.checkedOut) {
        expect(find.text('Attendance completed'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('4h 32m'), findsOneWidget);
        controller.currentTime.value = _checkOut.add(const Duration(hours: 2));
        await tester.pump();
        expect(find.text('4h 32m'), findsOneWidget);
      } else {
        final key = status == AttendanceStatus.notCheckedIn
            ? 'attendance-check-in'
            : 'attendance-check-out';
        await tapKey(tester, key);
        await tapKey(tester, key);
        expect(controller.checkInCalls + controller.checkOutCalls, 1);
        expect(find.text('Saving attendance…'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('offline pending is distinct from synchronized attendance', (
    tester,
  ) async {
    connectivity.status.value = NetworkStatus.disconnected;
    controller.pendingCount.value = 1;
    controller.attendance.value = AttendanceModel(
      date: _day,
      checkInTime: _checkIn,
      syncStatus: AttendanceSyncStatus.pending,
    );
    await showDashboard(tester);
    expect(find.text('Offline — saved data remains available'), findsOneWidget);
    expect(
      find.text('Saved on this device. Reconnect to sync.'),
      findsOneWidget,
    );
    expect(find.text('Pending Sync'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('sync-now')))
          .onPressed,
      isNull,
    );
    connectivity.status.value = NetworkStatus.connected;
    await tester.pump();
    await tapKey(tester, 'sync-now');
    expect(controller.syncCalls, 1);
    expect(find.text('Synchronizing attendance…'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('sync-now')))
          .onPressed,
      isNull,
    );
    controller.checkingSync.value = false;
    controller.pendingCount.value = 0;
    controller.attendance.value = AttendanceModel(
      date: _day,
      checkInTime: _checkIn,
      syncStatus: AttendanceSyncStatus.synced,
    );
    await tester.pump();
    expect(find.text('Synced'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-now')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero pending does not hide a rejection', (tester) async {
    const rejection = 'Check-in: Attendance already exists on the server.';
    controller.attendance.value = AttendanceModel(
      date: _day,
      syncStatus: AttendanceSyncStatus.rejected,
      rejectionMessages: const [rejection],
    );
    controller.actionMessage.value = 'Check-in saved.';
    controller.actionSucceeded.value = true;
    await showDashboard(tester);
    expect(find.text('Attendance needs attention'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text(rejection), findsOneWidget);
    expect(find.text('Check-in saved.'), findsNothing);
  });

  testWidgets('loading and storage errors do not expose attendance actions', (
    tester,
  ) async {
    controller.hasLoadedAttendance.value = false;
    controller.isLoading.value = true;
    await showDashboard(tester);
    expect(find.text("Loading today's attendance…"), findsOneWidget);
    expect(find.byType(AttendanceCard), findsNothing);
    controller.isLoading.value = false;
    controller.storageError.value = 'Unable to load saved attendance.';
    await tester.pump();
    expect(find.text('Unable to load saved attendance.'), findsOneWidget);
    expect(find.byType(AttendanceCard), findsNothing);
    await tapKey(tester, 'retry-attendance');
    expect(controller.retryCalls, 1);
  });

  testWidgets(
    'refresh retains attendance and unavailable balances are explicit',
    (tester) async {
      leave.balances.clear();
      await showDashboard(tester);
      expect(find.text('Unavailable'), findsNWidgets(2));
      expect(find.text('No attendance records yet.'), findsOneWidget);
      await tapKey(tester, 'refresh-dashboard');
      expect(controller.refreshCalls, 1);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(controller.refreshCalls, 2);
      controller.isLoading.value = true;
      controller.isRefreshing.value = true;
      await tester.pump();
      expect(find.byType(AttendanceCard), findsOneWidget);
      expect(find.text("Loading today's attendance…"), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('attendance-check-in')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('location settings recovery remains available', (tester) async {
    controller.actionMessage.value = 'Turn on location services to continue.';
    controller.locationFailure.value =
        AttendanceLocationFailure.servicesDisabled;
    await showDashboard(tester);
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(controller.settingsCalls, 1);
  });

  testWidgets(
    'Manage leave opens the existing screen with its original theme',
    (tester) async {
      await showDashboard(tester);
      await tapKey(tester, 'manage-leave');
      await tester.pumpAndSettle();
      expect(find.byType(LeaveScreen), findsOneWidget);
      expect(find.text('Submit leave'), findsOneWidget);
      final leaveContext = tester.element(find.byType(LeaveScreen));
      expect(Theme.of(leaveContext).cardTheme, AppTheme.light.cardTheme);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
    },
  );

  testWidgets('server errors retain cached attendance and provide retry', (
    tester,
  ) async {
    controller.serverMessage.value =
        'The server is unavailable. Please try again.';
    controller.attendance.value = AttendanceModel(
      date: _day,
      checkInTime: _checkIn,
      syncStatus: AttendanceSyncStatus.synced,
    );
    await showDashboard(tester);
    expect(find.text('Could not refresh dashboard'), findsOneWidget);
    expect(find.text('Network connected'), findsOneWidget);
    expect(find.text('4h 32m'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(controller.refreshCalls, 1);
  });

  test('leave form counts calendar days and clears an invalid end date', () {
    final form = LeaveController(leave, connectivity);
    final start = DateTime.utc(2030, 1, 4);
    form.selectDate(start, isStart: true);
    form.selectDate(start.add(const Duration(days: 2)), isStart: false);
    expect(form.requestedDays, 3);
    form.selectDate(start.add(const Duration(days: 3)), isStart: true);
    expect(form.endDate.value, isNull);
    expect(form.requestedDays, isNull);
    final range = form.datePickerRange(isStart: false);
    expect(range.firstDate, form.startDate.value);
    expect(range.initialDate, range.firstDate);
  });

  test(
    'leave form rejects missing dates and disables offline submission',
    () async {
      final form = LeaveController(leave, connectivity);
      expect(await form.submitForm('Family appointment'), isFalse);
      expect(form.message.value, 'Select both dates.');
      expect(form.canSubmit, isTrue);
      connectivity.status.value = NetworkStatus.disconnected;
      expect(form.canSubmit, isFalse);
      form.submitting.value = true;
      form.selectType(LeaveType.sick);
      expect(form.selectedType.value, LeaveType.casual);
      expect(form.canRefresh, isFalse);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('leave form is usable at narrow width and scale $scale', (
      tester,
    ) async {
      await showDashboard(tester, width: 320, scale: scale);
      await tapKey(tester, 'manage-leave');
      await tester.pumpAndSettle();
      expect(find.text('Plan your time away'), findsOneWidget);
      await tester.ensureVisible(find.text('Submit leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit leave'));
      await tester.pumpAndSettle();
      expect(find.text('Select both dates.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      connectivity.status.value = NetworkStatus.disconnected;
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit leave'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('No saved leave requests.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('dashboard fits width $width with text scale $scale', (
        tester,
      ) async {
        controller.employee.value = const EmployeeModel(
          id: 'EMP001',
          name: 'Alexandra Johnson-Ramachandran',
          department: 'Engineering and Employee Experience',
        );
        controller.pendingCount.value = 1;
        controller.attendance.value = AttendanceModel(
          date: _day,
          checkInTime: _checkIn,
          syncStatus: AttendanceSyncStatus.pending,
        );
        controller.actionMessage.value = 'Location could not be verified. Please enable precise location and try again.';
        controller.recentAttendanceRecords.add(
          AttendanceModel(
            date: _day.subtract(const Duration(days: 1)),
            syncStatus: AttendanceSyncStatus.rejected,
            rejectionMessages: const [
              'Check-in: This attendance record was rejected because its coordinates are outside the permitted office radius.',
            ],
          ),
        );
        await showDashboard(tester, width: width, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Recent attendance'));
        await tester.pump();
        expect(find.text('Rejected'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

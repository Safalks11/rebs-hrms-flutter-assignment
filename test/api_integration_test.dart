import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rebs_hrms_assignment/core/services/api_service.dart';
import 'package:rebs_hrms_assignment/core/services/app_database.dart';
import 'package:rebs_hrms_assignment/core/services/connectivity_service.dart';
import 'package:rebs_hrms_assignment/core/utils/company_time.dart';
import 'package:rebs_hrms_assignment/features/attendance/models/attendance_event.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_location_service.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_store.dart';
import 'package:rebs_hrms_assignment/features/attendance/services/attendance_sync_service.dart';
import 'package:rebs_hrms_assignment/features/leave/models/leave_request.dart';
import 'package:rebs_hrms_assignment/features/office_profile/services/office_profile_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryDatabase extends AppDatabase {
  final Database connection;
  MemoryDatabase(this.connection);
  @override
  Future<Database> get db async => connection;
}

class FakeLocationGateway implements LocationGateway {
  AttendanceLocation location = const AttendanceLocation(
    latitude: 12.9716,
    longitude: 77.5946,
    accuracy: 10,
  );
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<AttendanceLocation> currentLocation() async => location;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database connection;
  late AttendanceStore store;
  final now = DateTime.now().toUtc();
  final day = CompanyTime.attendanceDateKey(now);

  AttendanceEvent event(String id, AttendanceEventType type) => AttendanceEvent(
    id: id,
    employeeId: 'EMP001',
    companyDate: day,
    type: type,
    timestamp: now,
    latitude: 12.9716,
    longitude: 77.5946,
  );

  setUp(() async {
    connection = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await connection.execute('''
      CREATE TABLE attendance_events (
        event_id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        company_date TEXT NOT NULL,
        event_type TEXT NOT NULL,
        timestamp_utc TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sync_status TEXT NOT NULL,
        rejection_reason TEXT,
        UNIQUE(employee_id, company_date, event_type)
      )
    ''');
    await connection.execute(
      'CREATE TABLE office_profile (id INTEGER PRIMARY KEY, latitude REAL NOT NULL, longitude REAL NOT NULL)',
    );
    store = AttendanceStore(MemoryDatabase(connection));
  });
  tearDown(() => connection.close());

  test(
    'check-out requires check-in and duplicate check-in is rejected',
    () async {
      await expectLater(
        store.saveEvent(event('out', AttendanceEventType.checkOut)),
        throwsA(isA<AttendanceStoreException>()),
      );
      await store.saveEvent(event('in', AttendanceEventType.checkIn));
      await expectLater(
        store.saveEvent(event('another', AttendanceEventType.checkIn)),
        throwsA(isA<AttendanceStoreException>()),
      );
      expect(await store.countPendingEvents('EMP001'), 1);
    },
  );

  test('pending events survive a new store and sync in order', () async {
    await store.saveEvent(event('in', AttendanceEventType.checkIn));
    await store.saveEvent(event('out', AttendanceEventType.checkOut));
    final reopened = AttendanceStore(MemoryDatabase(connection));
    final sent = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent.add((options.data as Map)['id'] as String);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: <String, dynamic>{},
            ),
          );
        },
      ),
    );
    final connectivity = ConnectivityService(
      check: () async => [ConnectivityResult.wifi],
      changes: const Stream<List<ConnectivityResult>>.empty(),
    );
    final sync = AttendanceSyncService(
      reopened,
      ApiService(dio: dio),
      connectivity,
    );
    await sync.sync('EMP001');
    expect(sent, ['in', 'out']);
    expect(await reopened.countPendingEvents('EMP001'), 0);
  });

  test('server rejection message survives a new store', () async {
    await store.saveEvent(event('in', AttendanceEventType.checkIn));
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 422,
              data: {'message': 'Attendance is outside the office.'},
            ),
          ),
        ),
      ),
    );
    final connectivity = ConnectivityService(
      check: () async => [ConnectivityResult.wifi],
      changes: const Stream<List<ConnectivityResult>>.empty(),
    );
    await AttendanceSyncService(
      store,
      ApiService(dio: dio),
      connectivity,
    ).sync('EMP001');
    final reopened = AttendanceStore(MemoryDatabase(connection));
    final attendance = await reopened.loadAttendanceForDay('EMP001', now);
    expect(attendance.syncStatus, AttendanceSyncStatus.rejected);
    expect(attendance.rejectionMessages, [
      'Check-in: Attendance is outside the office.',
    ]);
  });

  test('office coordinates are cached and used while offline', () async {
    final officeStore = OfficeProfileStore(MemoryDatabase(connection));
    final gateway = FakeLocationGateway();
    final validator = AttendanceLocationService(officeStore, gateway: gateway);
    await expectLater(
      validator.validate(),
      throwsA(isA<AttendanceLocationException>()),
    );
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{'latitude': 12.9716, 'longitude': 77.5946},
          ),
        ),
      ),
    );
    await officeStore.refresh(ApiService(dio: dio));
    final reopened = OfficeProfileStore(MemoryDatabase(connection));
    final offlineValidator = AttendanceLocationService(
      reopened,
      gateway: gateway,
    );
    expect((await offlineValidator.validate()).latitude, 12.9716);
    gateway.location = const AttendanceLocation(
      latitude: 12.98,
      longitude: 77.5946,
      accuracy: 10,
    );
    await expectLater(
      offlineValidator.validate(),
      throwsA(
        isA<AttendanceLocationException>().having(
          (error) => error.reason,
          'reason',
          AttendanceLocationFailure.outsideOffice,
        ),
      ),
    );
  });

  test('leave validation rejects overlapping pending request', () {
    final start = CompanyTime.attendanceDate(DateTime.now())
        .add(const Duration(days: 2));
    LeaveRequest request(String id) => LeaveRequest(
      id: id,
      employeeId: 'EMP001',
      type: LeaveType.casual,
      startDate: start,
      endDate: start.add(const Duration(days: 1)),
      reason: 'Family appointment',
    );
    expect(
      validateLeave(
        request('new'),
        {LeaveType.casual: 8},
        [request('old')],
        DateTime.now(),
      ),
      'Dates overlap an existing leave request.',
    );
  });
}

import 'dart:convert';

import '../../../core/services/api_service.dart';

import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../models/leave_request.dart';

class LeaveRepository {
  final AppDatabase database;
  final ApiService api;
  final String employeeId;
  final balances = <LeaveType, int>{}.obs;
  final requests = <LeaveRequest>[].obs;

  LeaveRepository(this.database, this.api, {this.employeeId = 'EMP001'});

  Future<void> saveCache({
    required Map<LeaveType, int> balances,
    required List<LeaveRequest> requests,
  }) async {
    final balance = Map<LeaveType, int>.of(balances);
    final history = List<LeaveRequest>.of(requests);
    _validate(balance, history);
    final payload = jsonEncode({
      'balance': {
        for (final entry in balance.entries) entry.key.name: entry.value,
      },
      'requests': history.map((request) => request.toJson()).toList(),
    });
    await (await database.db).insert('leave_cache', {
      'employee_id': employeeId,
      'payload': payload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _apply(balance, history);
  }

  Future<void> loadCache() async {
    final rows = await (await database.db).query(
      'leave_cache',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    if (rows.isEmpty) return;
    final data =
        jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    final rawBalance = data['balance'] as Map<String, dynamic>;
    final balance = {
      for (final type in LeaveType.values) type: rawBalance[type.name] as int,
    };
    final history = (data['requests'] as List)
        .map(
          (item) =>
              LeaveRequest.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _validate(balance, history);
    _apply(balance, history);
  }

  void _validate(Map<LeaveType, int> balance, List<LeaveRequest> history) {
    if (LeaveType.values.any(
      (type) => !balance.containsKey(type) || balance[type]! < 0,
    )) {
      throw const FormatException(
        'Both available leave balances must be nonnegative.',
      );
    }
    final ids = <String>{};
    for (final request in history) {
      if (request.employeeId != employeeId ||
          request.id.isEmpty ||
          !ids.add(request.id)) {
        throw const FormatException(
          'Leave requests must belong to this employee and have unique IDs.',
        );
      }
    }
  }

  void _apply(Map<LeaveType, int> balance, List<LeaveRequest> history) {
    balances.assignAll(balance);
    requests.assignAll(
      history..sort((a, b) => b.startDate.compareTo(a.startDate)),
    );
  }

  Future<void> refresh() async {
    final responseBalance = await api.dio.get<Map<String, dynamic>>(
      '/leave/balance',
      queryParameters: {'employeeId': employeeId},
    );
    final responseRequests = await api.dio.get<Map<String, dynamic>>(
      '/leave/requests',
      queryParameters: {'employeeId': employeeId},
    );
    final rawBalance = responseBalance.data!;
    final parsedBalance = {
      for (final type in LeaveType.values) type: rawBalance[type.name] as int,
    };
    final parsedRequests = (responseRequests.data!['requests'] as List)
        .map(
          (item) =>
              LeaveRequest.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    await saveCache(balances: parsedBalance, requests: parsedRequests);
  }

  Future<LeaveRequest> submit(LeaveRequest request) async {
    final response = await api.dio.post<Map<String, dynamic>>(
      '/leave/requests',
      data: request.toJson()..remove('status'),
    );
    return LeaveRequest.fromJson(response.data!);
  }
}

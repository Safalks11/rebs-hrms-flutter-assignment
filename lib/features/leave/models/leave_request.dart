import '../../../core/utils/company_time.dart';

enum LeaveType { casual, sick }

enum LeaveStatus { pending, approved, rejected }

class LeaveRequest {
  final String id, employeeId, reason;
  final LeaveType type;
  final LeaveStatus status;
  final DateTime startDate, endDate;
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = LeaveStatus.pending,
  });
  int get days => endDate.difference(startDate).inDays + 1;
  static String dateKey(DateTime date) =>
      date.toIso8601String().substring(0, 10);
  Map<String, Object?> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'type': type.name,
    'startDate': dateKey(startDate),
    'endDate': dateKey(endDate),
    'reason': reason,
    'status': status.name,
  };
  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as String,
    employeeId: json['employeeId'] as String,
    type: LeaveType.values.byName(json['type'] as String),
    startDate: DateTime.parse('${json['startDate']}T00:00:00Z'),
    endDate: DateTime.parse('${json['endDate']}T00:00:00Z'),
    reason: json['reason'] as String,
    status: LeaveStatus.values.byName(json['status'] as String),
  );
}

// ignore_for_file: curly_braces_in_flow_control_structures

String? validateLeave(
  LeaveRequest request,
  Map<LeaveType, int> balances,
  List<LeaveRequest> history,
  DateTime now,
) {
  if (request.startDate.isBefore(CompanyTime.attendanceDate(now)))
    return 'Start date cannot be in the past.';
  if (request.endDate.isBefore(request.startDate))
    return 'End date must follow the start date.';
  if (request.reason.replaceAll(RegExp(r'\s'), '').length < 10)
    return 'Enter at least 10 non-whitespace characters.';
  if (!balances.containsKey(request.type))
    return 'Load your leave balance before applying.';
  if (request.days > balances[request.type]!)
    return 'Insufficient available leave.';
  if (history.any(
    (item) =>
        item.employeeId == request.employeeId &&
        item.status != LeaveStatus.rejected &&
        !request.startDate.isAfter(item.endDate) &&
        !request.endDate.isBefore(item.startDate),
  ))
    return 'Dates overlap an existing leave request.';
  return null;
}

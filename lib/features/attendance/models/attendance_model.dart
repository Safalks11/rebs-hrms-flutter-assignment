enum AttendanceStatus { notCheckedIn, checkedIn, checkedOut }

class AttendanceModel {
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  const AttendanceModel({
    required this.date,
    this.checkInTime,
    this.checkOutTime,
  });

  AttendanceStatus get status {
    if (checkOutTime != null) {
      return AttendanceStatus.checkedOut;
    }

    if (checkInTime != null) {
      return AttendanceStatus.checkedIn;
    }

    return AttendanceStatus.notCheckedIn;
  }

  Duration get workingDuration => workingDurationAt(DateTime.now());

  Duration workingDurationAt(DateTime now) {
    if (checkInTime == null) {
      return Duration.zero;
    }

    final duration = (checkOutTime ?? now).difference(checkInTime!);
    return duration.isNegative ? Duration.zero : duration;
  }
}

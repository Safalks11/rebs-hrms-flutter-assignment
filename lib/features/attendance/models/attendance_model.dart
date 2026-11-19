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

  Duration get workingDuration {
    if (checkInTime == null) {
      return Duration.zero;
    }

    return (checkOutTime ?? DateTime.now()).difference(checkInTime!);
  }
}

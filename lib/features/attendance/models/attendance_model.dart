enum AttendanceStatus { notCheckedIn, checkedIn, checkedOut }

class AttendanceModel {
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;

  const AttendanceModel({
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
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

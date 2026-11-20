class CompanyTime {
  CompanyTime._();

  // Central company configuration until supplied by the API.
  static const timezoneName = 'Asia/Kolkata';
  static const utcOffset = Duration(hours: 5, minutes: 30);

  // UTC-marked values here represent company wall-clock components only.
  static DateTime toCompanyTime(DateTime instant) =>
      instant.toUtc().add(utcOffset);

  static DateTime attendanceDate(DateTime instant) {
    final companyTime = toCompanyTime(instant);
    return DateTime.utc(companyTime.year, companyTime.month, companyTime.day);
  }

  static String attendanceDateKey(DateTime instant) =>
      attendanceDate(instant).toIso8601String().substring(0, 10);

  static DateTime endOfDayUtc(DateTime companyDate) => DateTime.utc(
    companyDate.year,
    companyDate.month,
    companyDate.day + 1,
  ).subtract(utcOffset);
}

import 'package:flutter/material.dart';

/// A student's attendance record for "today", as returned by `GET /attendances`
/// (the endpoint defaults to the current server date when no range is given).
class TodayAttendance {
  final bool checkedIn;
  final bool isLate;
  final TimeOfDay? checkinTime;

  const TodayAttendance({
    required this.checkedIn,
    required this.isLate,
    this.checkinTime,
  });

  /// Builds from a raw `/attendances` record. `check_in` is a nullable
  /// `HH:mm:ss` time string -- its presence is what "checked in" means
  /// (the backend leaves it null for auto-marked-absent records).
  static TodayAttendance fromJson(Map<String, dynamic> json) {
    final checkinTime = _parseTime(json['check_in']);
    final type = json['type']?.toString().trim().toUpperCase();
    final remark = json['remark']?.toString().trim().toUpperCase();
    return TodayAttendance(
      checkedIn: checkinTime != null,
      isLate: type == 'LATE' || remark == 'LATE',
      checkinTime: checkinTime,
    );
  }

  static TimeOfDay? _parseTime(dynamic value) {
    if (value is! String) return null;

    final parts = value.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }
}

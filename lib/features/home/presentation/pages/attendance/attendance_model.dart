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

class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.type,
    this.reason,
    this.note,
    this.checkIn,
  });

  final DateTime date;
  final String type;
  final String? reason;
  final String? note;
  final TimeOfDay? checkIn;

  bool get isPresent => type == 'PRESENT' || type == 'LATE';
  bool get isLate => type == 'LATE';

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      date:
          DateTime.tryParse(json['attendance_date']?.toString() ?? '') ??
          DateTime.now(),
      type: json['type']?.toString().toUpperCase() ?? 'ABSENT',
      reason:
          _clean(json['reason']) ??
          (json['type']?.toString().toUpperCase() == 'LATE' ? 'Late' : null),
      note: _clean(json['remark']),
      checkIn: TodayAttendance._parseTime(json['check_in']),
    );
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

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
      reason: _clean(json['reason']),
      note: _clean(json['remark']),
      checkIn: TodayAttendance._parseTime(json['check_in']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendance_date': _date(date),
      'type': type,
      if (reason != null) 'reason': reason,
      if (note != null) 'remark': note,
      if (checkIn != null) 'check_in': _time(checkIn!),
    };
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}

class StaffAttendanceScanRecord {
  const StaffAttendanceScanRecord({
    required this.studentName,
    required this.studentCode,
    required this.className,
    required this.checkIn,
    required this.type,
    required this.remark,
  });

  final String studentName;
  final String studentCode;
  final String className;
  final TimeOfDay checkIn;
  final String type;
  final String remark;

  bool get isLate => type == 'LATE' || remark == 'LATE';
  bool get isEarly => remark == 'EARLY';
  bool get isOnTime => !isLate && !isEarly;

  factory StaffAttendanceScanRecord.fromJson(Map<String, dynamic> json) {
    final studentJson = json['student'];
    final student = studentJson is Map ? studentJson : const {};
    final firstNameLao = _clean(student['first_name_lao']);
    final lastNameLao = _clean(student['last_name_lao']);
    final firstName = _clean(student['first_name']);
    final lastName = _clean(student['last_name']);
    final laoName = [
      firstNameLao,
      lastNameLao,
    ].where((item) => item != null && item.isNotEmpty).join(' ');
    final englishName = [
      firstName,
      lastName,
    ].where((item) => item != null && item.isNotEmpty).join(' ');

    return StaffAttendanceScanRecord(
      studentName: laoName.isNotEmpty
          ? laoName
          : englishName.isNotEmpty
          ? englishName
          : _clean(json['student_name']) ?? '-',
      studentCode:
          _clean(student['student_id']) ?? _clean(json['student_code']) ?? '',
      className: _className(student),
      checkIn:
          TodayAttendance._parseTime(json['check_in']) ??
          const TimeOfDay(hour: 0, minute: 0),
      type: json['type']?.toString().trim().toUpperCase() ?? 'PRESENT',
      remark: json['remark']?.toString().trim().toUpperCase() ?? '',
    );
  }

  static String _className(Map<dynamic, dynamic> student) {
    final enrollments = student['enrollments'];
    if (enrollments is List && enrollments.isNotEmpty) {
      final enrollment = enrollments.first;
      if (enrollment is Map) {
        final classJson = enrollment['class'];
        if (classJson is Map) {
          return _clean(classJson['name']) ??
              _clean(classJson['class_name']) ??
              '-';
        }
      }
    }

    final classJson = student['class'];
    if (classJson is Map) {
      return _clean(classJson['name']) ??
          _clean(classJson['class_name']) ??
          '-';
    }

    return _clean(student['class_name']) ?? '-';
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

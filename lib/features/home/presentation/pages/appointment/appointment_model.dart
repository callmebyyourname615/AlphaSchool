import 'package:flutter/material.dart';

enum AppointmentStatus { pending, confirmed, postponed, cancelled }

class AdminModel {
  final String id;
  final String name;
  final String role;
  final String branchId;

  const AdminModel({
    required this.id,
    required this.name,
    this.role = '',
    this.branchId = '',
  });

  static AdminModel fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? '').toString().trim();
    final last = (json['last_name'] ?? '').toString().trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');

    String role = '';
    final roles = json['roles'];
    if (roles is List && roles.isNotEmpty) {
      final r = roles.first;
      role = (r is Map ? r['name']?.toString() : r?.toString()) ?? '';
    }

    return AdminModel(
      id: json['id']?.toString() ?? '',
      name: full.isNotEmpty
          ? full
          : (json['username']?.toString() ?? 'Unknown'),
      role: role,
      branchId:
          (json['branch_id'] ??
                  json['branchId'] ??
                  (json['branch'] is Map ? json['branch']['id'] : null) ??
                  '')
              .toString(),
    );
  }
}

class AppointmentModel {
  final String id;
  final String appointmentPersonId;
  final String title;
  final String? note;

  DateTime date;
  TimeOfDay start;
  TimeOfDay end;

  AppointmentStatus status;
  int rescheduleCount;
  List<String> participantIds;
  List<String> parentIds;
  Map<String, String> participantTypes;
  final String branchId;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? rescheduledAt;
  final DateTime? originalDate;
  final TimeOfDay? originalStart;
  final TimeOfDay? originalEnd;
  final DateTime? previousRescheduledDate;
  final TimeOfDay? previousRescheduledStart;
  final TimeOfDay? previousRescheduledEnd;
  final List<AppointmentParticipantModel> participants;

  static const int maxReschedule = 3;

  AppointmentModel({
    required this.id,
    this.appointmentPersonId = '',
    required this.title,
    this.note,
    required this.date,
    required this.start,
    required this.end,
    this.status = AppointmentStatus.pending,
    this.rescheduleCount = 0,
    this.participantIds = const [],
    this.parentIds = const [],
    this.participantTypes = const {},
    this.branchId = '',
    this.createdBy = '',
    this.createdByName = '',
    this.createdAt,
    this.updatedAt,
    this.rescheduledAt,
    this.originalDate,
    this.originalStart,
    this.originalEnd,
    this.previousRescheduledDate,
    this.previousRescheduledStart,
    this.previousRescheduledEnd,
    this.participants = const [],
  });

  bool get canReschedule => rescheduleCount < maxReschedule;
  int get rescheduleRemaining => maxReschedule - rescheduleCount;

  AppointmentModel copyWith({
    String? createdByName,
    List<AppointmentParticipantModel>? participants,
  }) {
    return AppointmentModel(
      id: id,
      appointmentPersonId: appointmentPersonId,
      title: title,
      note: note,
      date: date,
      start: start,
      end: end,
      status: status,
      rescheduleCount: rescheduleCount,
      participantIds: participantIds,
      parentIds: parentIds,
      participantTypes: participantTypes,
      branchId: branchId,
      createdBy: createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      rescheduledAt: rescheduledAt,
      originalDate: originalDate,
      originalStart: originalStart,
      originalEnd: originalEnd,
      previousRescheduledDate: previousRescheduledDate,
      previousRescheduledStart: previousRescheduledStart,
      previousRescheduledEnd: previousRescheduledEnd,
      participants: participants ?? this.participants,
    );
  }
}

class AppointmentParticipantModel {
  final String id;
  final String personId;
  final String name;
  final String personType;
  final String roleLabel;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String responseNote;
  final int rescheduleCount;
  final List<ParticipantResponseHistoryModel> responseHistory;

  const AppointmentParticipantModel({
    required this.id,
    required this.personId,
    required this.name,
    required this.personType,
    required this.roleLabel,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.responseNote = '',
    this.rescheduleCount = 0,
    this.responseHistory = const [],
  });

  AppointmentParticipantModel copyWith({String? name}) {
    return AppointmentParticipantModel(
      id: id,
      personId: personId,
      name: name ?? this.name,
      personType: personType,
      roleLabel: roleLabel,
      status: status,
      createdAt: createdAt,
      respondedAt: respondedAt,
      responseNote: responseNote,
      rescheduleCount: rescheduleCount,
      responseHistory: responseHistory,
    );
  }
}

class ParticipantResponseHistoryModel {
  final String status;
  final DateTime? eventAt;
  final String note;
  final DateTime? proposedDate;
  final TimeOfDay? proposedStart;
  final TimeOfDay? proposedEnd;
  final int rescheduleCount;

  const ParticipantResponseHistoryModel({
    required this.status,
    this.eventAt,
    this.note = '',
    this.proposedDate,
    this.proposedStart,
    this.proposedEnd,
    this.rescheduleCount = 0,
  });
}

class ParentInviteModel {
  final String id;
  final String name;
  final String gradeName;
  final String className;
  final String contact;

  const ParentInviteModel({
    required this.id,
    required this.name,
    this.gradeName = '',
    this.className = '',
    this.contact = '',
  });

  static ParentInviteModel fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? json['firstName'] ?? '')
        .toString()
        .trim();
    final last = (json['last_name'] ?? json['lastName'] ?? '')
        .toString()
        .trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    final students = json['students'] ?? json['children'];
    Map<String, dynamic>? firstStudent;
    if (students is List && students.isNotEmpty) {
      for (final student in students.whereType<Map<String, dynamic>>()) {
        firstStudent = student;
        break;
      }
    }

    return ParentInviteModel(
      id: (json['id'] ?? json['parent_id'] ?? json['parentId'] ?? '')
          .toString(),
      name: full.isNotEmpty
          ? full
          : (json['username'] ?? json['email'] ?? json['id'] ?? 'Parent')
                .toString(),
      gradeName: _nestedName(firstStudent?['grade'] ?? json['grade']),
      className: _nestedName(firstStudent?['class'] ?? json['class']),
      contact: (json['phone'] ?? json['phone_number'] ?? json['email'] ?? '')
          .toString()
          .trim(),
    );
  }
}

class StudentInviteModel {
  final String id;
  final String name;
  final String className;
  final List<ParentInviteModel> parents;

  const StudentInviteModel({
    required this.id,
    required this.name,
    this.className = '',
    this.parents = const [],
  });

  static StudentInviteModel fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? json['firstName'] ?? '')
        .toString()
        .trim();
    final last = (json['last_name'] ?? json['lastName'] ?? '')
        .toString()
        .trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    final parents = json['parents'];

    return StudentInviteModel(
      id: (json['id'] ?? json['student_id'] ?? json['studentId'] ?? '')
          .toString(),
      name: full.isNotEmpty
          ? full
          : (json['student_id'] ?? json['studentId'] ?? json['id'] ?? 'Student')
                .toString(),
      className: _nestedName(
        json['class'] ?? json['classroom'] ?? _firstEnrollmentClass(json),
      ),
      parents: parents is List
          ? parents
                .whereType<Map<String, dynamic>>()
                .map(ParentInviteModel.fromJson)
                .where((p) => p.id.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class AppointmentConflict {
  final String personId;
  final String title;
  final DateTime? date;
  final TimeOfDay? start;
  final TimeOfDay? end;

  const AppointmentConflict({
    required this.personId,
    this.title = 'Appointment',
    this.date,
    this.start,
    this.end,
  });

  String get timeLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    if (start == null || end == null) return '';
    return '${two(start!.hour)}:${two(start!.minute)} - ${two(end!.hour)}:${two(end!.minute)}';
  }
}

String _nestedName(dynamic value) {
  if (value is Map) {
    return (value['name'] ?? value['title'] ?? '').toString().trim();
  }
  return (value ?? '').toString().trim();
}

dynamic _firstEnrollmentClass(Map<String, dynamic> json) {
  final enrollments = json['enrollments'];
  if (enrollments is! List) return null;
  for (final enrollment in enrollments.whereType<Map<String, dynamic>>()) {
    return enrollment['class'];
  }
  return null;
}

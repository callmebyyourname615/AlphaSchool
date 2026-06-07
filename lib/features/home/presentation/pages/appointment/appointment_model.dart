import 'package:flutter/material.dart';

enum AppointmentStatus { pending, confirmed, postponed, cancelled }

class AdminModel {
  final String id;
  final String name;
  final String role;

  const AdminModel({required this.id, required this.name, this.role = ''});

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
  final String createdBy;

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
    this.createdBy = '',
  });

  bool get canReschedule => rescheduleCount < maxReschedule;
  int get rescheduleRemaining => maxReschedule - rescheduleCount;
}

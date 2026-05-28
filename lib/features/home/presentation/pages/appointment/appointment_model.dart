import 'package:flutter/material.dart';

enum AppointmentStatus { pending, confirmed, postponed, cancelled }

class AppointmentModel {
  final String id;
  final String title;
  final String? note;

  DateTime date;
  TimeOfDay start;
  TimeOfDay end;

  AppointmentStatus status;

  AppointmentModel({
    required this.id,
    required this.title,
    this.note,
    required this.date,
    required this.start,
    required this.end,
    this.status = AppointmentStatus.pending,
  });
}

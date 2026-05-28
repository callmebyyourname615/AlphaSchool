import 'package:flutter/material.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/services/session_service.dart';
import 'appointment_model.dart';

class AppointmentService {
  AppointmentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AppointmentModel>> fetchAppointments() async {
    final session = await SessionService().load();
    final response = await _apiClient.get('/appointments');
    final rawItems = _extractItems(response);

    final appointments =
        rawItems
            .whereType<Map<String, dynamic>>()
            .where((item) => item['is_deleted'] != true)
            .where((item) => item['is_active'] != false)
            .where((item) => session == null || _belongsToUser(item, session))
            .map(_fromJson)
            .whereType<AppointmentModel>()
            .toList()
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return _toMinutes(a.start).compareTo(_toMinutes(b.start));
          });

    return appointments;
  }

  Future<void> createAppointment(AppointmentModel model) async {
    String _pad(int n) => n.toString().padLeft(2, '0');
    await _apiClient.post('/appointments', body: {
      'title': model.title,
      'date': '${model.date.year}-${_pad(model.date.month)}-${_pad(model.date.day)}',
      'from_time': '${_pad(model.start.hour)}:${_pad(model.start.minute)}',
      'to_time': '${_pad(model.end.hour)}:${_pad(model.end.minute)}',
      if (model.note != null && model.note!.isNotEmpty) 'description': model.note,
      'status': 'PENDING',
    });
  }

  bool _belongsToUser(Map<String, dynamic> json, SessionData session) {
    // Check direct scalar ID fields
    for (final key in const [
      'admin_id',
      'user_id',
      'created_by',
      'created_by_id',
      'organizer_id',
      'owner_id',
    ]) {
      final val = json[key]?.toString();
      if (val != null && val.isNotEmpty) {
        if (session.id.isNotEmpty && val == session.id) return true;
      }
    }

    // Check nested single-object fields (e.g. "admin": { "id": "...", "email": "..." })
    for (final key in const ['admin', 'user', 'created_by', 'organizer', 'owner']) {
      final obj = json[key];
      if (obj is Map<String, dynamic>) {
        if (_objectMatchesSession(obj, session)) return true;
      }
    }

    // Check array fields (e.g. "participants": [...], "admins": [...])
    for (final key in const [
      'participants',
      'admins',
      'users',
      'attendees',
      'members',
    ]) {
      final list = json[key];
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            if (_objectMatchesSession(item, session)) return true;
          } else if (item != null && session.id.isNotEmpty) {
            if (item.toString() == session.id) return true;
          }
        }
      }
    }

    return false;
  }

  bool _objectMatchesSession(Map<String, dynamic> obj, SessionData session) {
    final id = obj['id']?.toString() ?? '';
    final username = obj['username']?.toString() ?? '';
    final email = obj['email']?.toString() ?? '';

    if (session.id.isNotEmpty && id == session.id) return true;
    if (session.username.isNotEmpty &&
        username.toLowerCase() == session.username.toLowerCase()) return true;
    if (session.email.isNotEmpty &&
        email.toLowerCase() == session.email.toLowerCase()) return true;

    return false;
  }

  List<dynamic> _extractItems(dynamic response) {
    return switch (response) {
      List<dynamic>() => response,
      {'data': final List<dynamic> data} => data,
      {'appointments': final List<dynamic> appointments} => appointments,
      {'results': final List<dynamic> results} => results,
      _ => const <dynamic>[],
    };
  }

  AppointmentModel? _fromJson(Map<String, dynamic> json) {
    final status = _statusFromJson(json['status']);
    final useRescheduled = status == AppointmentStatus.postponed;

    final date = _parseDate(
      useRescheduled ? json['rescheduled_date'] : json['date'],
    );
    final start = _parseTime(
      useRescheduled ? json['rescheduled_from_time'] : json['from_time'],
    );
    final end = _parseTime(
      useRescheduled ? json['rescheduled_to_time'] : json['to_time'],
    );

    if (date == null || start == null) return null;

    final place = _readString(json['appointment_place']);
    final description = _readString(json['description']);

    return AppointmentModel(
      id: _readString(
        json['id'],
      ).ifEmpty('appointment_${date.millisecondsSinceEpoch}'),
      title: _readString(json['title']).ifEmpty('Appointment'),
      note: [
        description,
        if (place.isNotEmpty) place,
      ].where((e) => e.isNotEmpty).join(' • '),
      date: date,
      start: start,
      end: end ?? _addMinutes(start, 30),
      status: status,
    );
  }

  AppointmentStatus _statusFromJson(dynamic value) {
    final status = _readString(value).toUpperCase();
    return switch (status) {
      'CONFIRMED' || 'APPROVED' || 'ACCEPTED' => AppointmentStatus.confirmed,
      'CANCELLED' || 'CANCELED' || 'DECLINED' => AppointmentStatus.cancelled,
      'RESCHEDULED' || 'POSTPONED' => AppointmentStatus.postponed,
      _ => AppointmentStatus.pending,
    };
  }

  DateTime? _parseDate(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  TimeOfDay? _parseTime(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _readString(dynamic value) => value?.toString().trim() ?? '';
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

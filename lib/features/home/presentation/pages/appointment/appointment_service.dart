import 'package:flutter/material.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/services/session_service.dart';
import 'appointment_model.dart';

class AppointmentService {
  AppointmentService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AppointmentModel>> fetchAppointments() async {
    final response = await _apiClient.get('/appointments');
    final rawItems = _extractItems(response);

    final appointments =
        rawItems
            .whereType<Map<String, dynamic>>()
            .where((item) => item['is_deleted'] != true)
            .where((item) => item['is_active'] != false)
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

    final session = await SessionService().load();

    // Use branchId from session; fall back to fetching from /admins if missing
    String branchId = session?.branchId ?? '';
    if (branchId.isEmpty && session != null && session.id.isNotEmpty) {
      branchId = await _fetchBranchId(session.id);
    }

    final academicYearId = await _fetchActiveAcademicYearId(branchId);

    await _apiClient.post('/appointments', body: {
      'title': model.title,
      'date': '${model.date.year}-${_pad(model.date.month)}-${_pad(model.date.day)}',
      'from_time': '${_pad(model.start.hour)}:${_pad(model.start.minute)}',
      'to_time': '${_pad(model.end.hour)}:${_pad(model.end.minute)}',
      if (model.note != null && model.note!.isNotEmpty) 'description': model.note,
      'status': 'PENDING',
      if (branchId.isNotEmpty) 'branch_id': branchId,
      if (academicYearId.isNotEmpty) 'academic_year_id': academicYearId,
      if (session?.id.isNotEmpty == true) 'created_by': session!.id,
      if (model.participantIds.isNotEmpty)
        'participants': model.participantIds
            .map((id) => {'person_id': id, 'person_type': 'TEACHER'})
            .toList(),
    });
  }

  Future<String> _fetchBranchId(String userId) async {
    try {
      final response = await _apiClient.get('/admins');
      final List<dynamic> admins = response is List ? response : [];
      for (final admin in admins) {
        if (admin is Map && admin['id']?.toString() == userId) {
          final branch = admin['branch'];
          if (branch is Map) return branch['id']?.toString() ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  Future<String> _fetchActiveAcademicYearId(String branchId) async {
    if (branchId.isEmpty) return '';
    try {
      final response = await _apiClient.get(
        '/academic-years',
        queryParameters: {'branch_id': branchId},
      );
      final List<dynamic> items = response is List
          ? response
          : (response is Map
              ? ((response['data'] ?? response['results']) as List? ?? [])
              : []);
      for (final item in items) {
        if (item is Map<String, dynamic> && item['is_active'] == true) {
          return item['id']?.toString() ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  Future<List<AdminModel>> fetchAdmins() async {
    final response = await _apiClient.get('/admins');
    final List<dynamic> raw = response is List ? response : [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((j) => j['is_active'] != false)
        .map(AdminModel.fromJson)
        .toList();
  }

  Future<void> confirmAppointment(String id) async {
    await _apiClient.put('/appointments/$id', body: {'status': 'CONFIRMED'});
  }

  Future<void> rescheduleAppointment(
    String id,
    DateTime date,
    TimeOfDay start,
    TimeOfDay end,
  ) async {
    String _pad(int n) => n.toString().padLeft(2, '0');
    await _apiClient.put('/appointments/$id', body: {
      'status': 'RESCHEDULED',
      'rescheduled_date': '${date.year}-${_pad(date.month)}-${_pad(date.day)}',
      'rescheduled_from_time': '${_pad(start.hour)}:${_pad(start.minute)}',
      'rescheduled_to_time': '${_pad(end.hour)}:${_pad(end.minute)}',
    });
  }

  Future<void> deleteAppointment(String id) async {
    await _apiClient.delete('/appointments/$id');
  }

  List<dynamic> _extractItems(dynamic response) {
    if (response is List) return response;
    if (response is Map) {
      for (final key in ['data', 'appointments', 'results']) {
        final val = response[key];
        if (val is List) return val;
      }
    }
    return const <dynamic>[];
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

    // Max reschedule_count across all participants
    int rescheduleCount = 0;
    final participants = json['participants'];
    if (participants is List) {
      for (final p in participants) {
        if (p is Map<String, dynamic>) {
          final c = int.tryParse(p['reschedule_count']?.toString() ?? '0') ?? 0;
          if (c > rescheduleCount) rescheduleCount = c;
        }
      }
    }

    return AppointmentModel(
      id: _readString(
        json['id'],
      ).ifEmpty('appointment_${date.millisecondsSinceEpoch}'),
      title: _readString(json['title']).ifEmpty('Appointment'),
      rescheduleCount: rescheduleCount,
      createdBy: _readString(json['created_by']),
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

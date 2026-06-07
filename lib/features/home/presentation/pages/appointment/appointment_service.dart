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
    final userId = session?.id.trim() ?? '';
    if (userId.isEmpty) return const [];

    final response = await _apiClient.get('/appointments');
    final rawItems = _extractItems(response);

    final appointments =
        rawItems
            .whereType<Map<String, dynamic>>()
            .where((item) => item['is_deleted'] != true)
            .where((item) => item['is_active'] != false)
            .where((item) => _isAssignedToUser(item, userId))
            .map((item) => _fromJson(item, userId))
            .whereType<AppointmentModel>()
            .toList()
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return _toMinutes(a.start).compareTo(_toMinutes(b.start));
          });

    return appointments;
  }

  bool _isAssignedToUser(Map<String, dynamic> appointment, String userId) {
    final participants = appointment['participants'];
    if (participants is! List) return false;

    return participants.whereType<Map<String, dynamic>>().any((participant) {
      if (participant['is_deleted'] == true) return false;
      if (participant['is_active'] == false) return false;

      return _readString(participant['person_id'] ?? participant['personId']) ==
          userId;
    });
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

    await _apiClient.post(
      '/appointments',
      body: {
        'title': model.title,
        'date':
            '${model.date.year}-${_pad(model.date.month)}-${_pad(model.date.day)}',
        'from_time': '${_pad(model.start.hour)}:${_pad(model.start.minute)}',
        'to_time': '${_pad(model.end.hour)}:${_pad(model.end.minute)}',
        if (model.note != null && model.note!.isNotEmpty)
          'description': model.note,
        'status': 'PENDING',
        if (branchId.isNotEmpty) 'branch_id': branchId,
        if (academicYearId.isNotEmpty) 'academic_year_id': academicYearId,
        if (session?.id.isNotEmpty == true) 'created_by': session!.id,
        if (model.participantIds.isNotEmpty)
          'participants': model.participantIds
              .map((id) => {'person_id': id, 'person_type': 'TEACHER'})
              .toList(),
      },
    );
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

  Future<void> confirmAppointment(AppointmentModel model) async {
    if (model.appointmentPersonId.isEmpty) {
      throw StateError('Missing appointment participant id');
    }

    await _apiClient.patch(
      '/appointments/participants/${model.appointmentPersonId}/respond',
      body: {'status': 'ACCEPTED'},
    );
  }

  Future<void> declineAppointment(AppointmentModel model) async {
    if (model.appointmentPersonId.isEmpty) {
      throw StateError('Missing appointment participant id');
    }

    await _apiClient.patch(
      '/appointments/participants/${model.appointmentPersonId}/respond',
      body: {'status': 'DECLINED'},
    );
  }

  Future<void> rescheduleAppointment(
    AppointmentModel model,
    DateTime date,
    TimeOfDay start,
    TimeOfDay end,
  ) async {
    String pad(int n) => n.toString().padLeft(2, '0');
    if (model.appointmentPersonId.isEmpty) {
      throw StateError('Missing appointment participant id');
    }

    await _apiClient.patch(
      '/appointments/participants/${model.appointmentPersonId}/respond',
      body: {
        'status': 'RESCHEDULED',
        'proposed_date': '${date.year}-${pad(date.month)}-${pad(date.day)}',
        'proposed_from_time': '${pad(start.hour)}:${pad(start.minute)}',
        'proposed_to_time': '${pad(end.hour)}:${pad(end.minute)}',
      },
    );
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

  AppointmentModel? _fromJson(Map<String, dynamic> json, String userId) {
    final currentParticipant = _currentParticipant(json, userId);
    final status = _statusFromJson(
      currentParticipant?['status'] ?? json['status'],
    );
    final proposedReschedule = _latestProposedReschedule(currentParticipant);
    final hasProposedDate = _readString(
      proposedReschedule?['proposed_date'],
    ).isNotEmpty;
    final hasProposedStart = _readString(
      proposedReschedule?['proposed_from_time'],
    ).isNotEmpty;
    final useProposedReschedule =
        status == AppointmentStatus.postponed &&
        hasProposedDate &&
        hasProposedStart;

    final hasRescheduledDate = _readString(json['rescheduled_date']).isNotEmpty;
    final hasRescheduledStart = _readString(
      json['rescheduled_from_time'],
    ).isNotEmpty;
    final useRescheduled = hasRescheduledDate && hasRescheduledStart;

    Object? dateValue = json['date'];
    Object? startValue = json['from_time'];
    Object? endValue = json['to_time'];
    if (useRescheduled) {
      dateValue = json['rescheduled_date'];
      startValue = json['rescheduled_from_time'];
      endValue = json['rescheduled_to_time'];
    }
    if (useProposedReschedule) {
      dateValue = proposedReschedule?['proposed_date'];
      startValue = proposedReschedule?['proposed_from_time'];
      endValue = proposedReschedule?['proposed_to_time'];
    }

    final date = _parseDate(dateValue);
    final start = _parseTime(startValue);
    final end = _parseTime(endValue);

    if (date == null || start == null) return null;

    final place = _readString(json['appointment_place']);
    final description = _readString(json['description']);

    final rescheduleCount = _participantRescheduleCount(currentParticipant);

    return AppointmentModel(
      id: _readString(
        json['id'],
      ).ifEmpty('appointment_${date.millisecondsSinceEpoch}'),
      appointmentPersonId: _readString(currentParticipant?['id']),
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

  int _participantRescheduleCount(Map<String, dynamic>? participant) {
    if (participant == null) return 0;
    return int.tryParse(
          (participant['reschedule_count'] ?? participant['rescheduled_count'])
                  ?.toString() ??
              '0',
        ) ??
        0;
  }

  Map<String, dynamic>? _latestProposedReschedule(
    Map<String, dynamic>? participant,
  ) {
    final history = participant?['response_history'];
    if (history is! List) return null;

    Map<String, dynamic>? latest;
    for (final entry in history.whereType<Map<String, dynamic>>()) {
      if (_readString(entry['status']).toUpperCase() != 'RESCHEDULED') {
        continue;
      }
      if (_readString(entry['proposed_date']).isEmpty) continue;
      latest = entry;
    }

    return latest;
  }

  Map<String, dynamic>? _currentParticipant(
    Map<String, dynamic> appointment,
    String userId,
  ) {
    final participants = appointment['participants'];
    if (participants is! List) return null;

    for (final participant in participants.whereType<Map<String, dynamic>>()) {
      if (participant['is_deleted'] == true) continue;
      if (participant['is_active'] == false) continue;
      if (_readString(participant['person_id'] ?? participant['personId']) ==
          userId) {
        return participant;
      }
    }

    return null;
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

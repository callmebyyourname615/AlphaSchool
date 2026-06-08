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

    return _withDisplayNames(appointments);
  }

  Future<List<AppointmentModel>> _withDisplayNames(
    List<AppointmentModel> appointments,
  ) async {
    final creatorIds = appointments
        .map((appointment) => appointment.createdBy)
        .where((id) => id.isNotEmpty)
        .toSet();
    final names = <String, String>{};
    for (final id in creatorIds) {
      names[id] = await _resolveCreatorName(id);
    }

    return Future.wait(
      appointments.map((appointment) async {
        return appointment.copyWith(
          createdByName: names[appointment.createdBy] ?? appointment.createdBy,
          participants: await _withParticipantNames(appointment.participants),
        );
      }),
    );
  }

  Future<List<AppointmentParticipantModel>> _withParticipantNames(
    List<AppointmentParticipantModel> participants,
  ) async {
    final cache = <String, String>{};
    final resolved = <AppointmentParticipantModel>[];

    for (final participant in participants) {
      final personId = participant.personId.trim();
      if (personId.isEmpty) {
        resolved.add(participant);
        continue;
      }

      final key = '${participant.personType}:$personId';
      var name = cache[key];
      if (name == null) {
        name = await _resolveParticipantName(personId, participant.personType);
        cache[key] = name;
      }

      resolved.add(
        name.isEmpty ? participant : participant.copyWith(name: name),
      );
    }

    return resolved;
  }

  Future<String> _resolveParticipantName(String id, String personType) async {
    if (personType.toUpperCase() == 'PARENT') {
      final parent = await _fetchPersonName('/parents/$id');
      if (parent.isNotEmpty) return parent;
      return _fetchPersonName('/admins/$id');
    }

    final admin = await _fetchPersonName('/admins/$id');
    if (admin.isNotEmpty) return admin;
    return _fetchPersonName('/parents/$id');
  }

  Future<String> _resolveCreatorName(String id) async {
    final admin = await _fetchPersonName('/admins/$id');
    if (admin.isNotEmpty) return admin;
    final parent = await _fetchPersonName('/parents/$id');
    if (parent.isNotEmpty) return parent;
    return id;
  }

  Future<String> _fetchPersonName(String path) async {
    try {
      final response = await _apiClient.get(path);
      if (response is! Map<String, dynamic>) return '';
      return _personName(response);
    } catch (_) {
      return '';
    }
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
    String pad(int n) => n.toString().padLeft(2, '0');

    final session = await SessionService().load();

    // Use branchId from session; fall back to fetching from /admins if missing
    String branchId = session?.branchId ?? '';
    if (branchId.isEmpty) branchId = model.branchId;
    if (branchId.isEmpty && session != null && session.id.isNotEmpty) {
      branchId = await _fetchBranchId(session.id);
    }

    final academicYearId = await _fetchActiveAcademicYearId(
      branchId,
      model.date,
    );

    if (branchId.isEmpty) {
      throw StateError('Branch not found for current user');
    }
    if (academicYearId.isEmpty) {
      throw StateError('Academic year not found for current branch');
    }

    final response = await _apiClient.post(
      '/appointments',
      body: {
        'title': model.title,
        'date':
            '${model.date.year}-${pad(model.date.month)}-${pad(model.date.day)}',
        'from_time': '${pad(model.start.hour)}:${pad(model.start.minute)}:00',
        'to_time': '${pad(model.end.hour)}:${pad(model.end.minute)}:00',
        'description': '',
        'appointment_place': model.note ?? '',
        'status': 'PENDING',
        'branch_id': branchId,
        'academic_year_id': academicYearId,
        if (session?.id.isNotEmpty == true) 'created_by': session!.id,
        'creator_role': 'ADMIN',
        'participants': const [],
      },
    );

    final appointmentId = _extractAppointmentId(response);
    if (appointmentId.isEmpty) {
      throw StateError('Appointment created but no id was returned');
    }

    for (final parentId in model.parentIds) {
      await _createAppointmentPerson(
        branchId: branchId,
        academicYearId: academicYearId,
        appointmentId: appointmentId,
        personId: parentId,
        personType: 'PARENT',
      );
    }

    for (final participantId in model.participantIds) {
      await _createAppointmentPerson(
        branchId: branchId,
        academicYearId: academicYearId,
        appointmentId: appointmentId,
        personId: participantId,
        personType: model.participantTypes[participantId] ?? 'TEACHER',
      );
    }
  }

  Future<void> _createAppointmentPerson({
    required String branchId,
    required String academicYearId,
    required String appointmentId,
    required String personId,
    required String personType,
  }) {
    return _apiClient.post(
      '/appointment-persons',
      body: {
        'branch_id': branchId,
        'appointment_id': appointmentId,
        'academic_year_id': academicYearId,
        'person_id': personId,
        'person_type': personType,
        'status': 'Pending',
        'notes': '',
        'declined_count': 0,
        'rescheduled_count': 0,
        'is_active': true,
      },
    );
  }

  String _extractAppointmentId(dynamic response) {
    final candidates = <dynamic>[
      response,
      if (response is Map) response['appointment'],
      if (response is Map && response['data'] is Map)
        (response['data'] as Map)['appointment'],
      if (response is Map) response['data'],
    ];

    for (final candidate in candidates) {
      if (candidate is Map) {
        final id = _readString(candidate['id']);
        if (id.isNotEmpty) return id;
      }
    }
    return '';
  }

  Future<String> _fetchBranchId(String userId) async {
    try {
      final response = await _apiClient.get('/admins');
      for (final admin in _extractRecords(response, 'admins')) {
        if (admin['id']?.toString() == userId) {
          final direct = _readString(admin['branch_id'] ?? admin['branchId']);
          if (direct.isNotEmpty) return direct;
          final branch = admin['branch'];
          if (branch is Map) return branch['id']?.toString() ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  Future<String> _fetchActiveAcademicYearId(
    String branchId,
    DateTime appointmentDate,
  ) async {
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
      final years = items.whereType<Map<String, dynamic>>().where((item) {
        if (item['is_deleted'] == true || item['isDeleted'] == true) {
          return false;
        }
        if (item['is_active'] == false || item['isActive'] == false) {
          return false;
        }
        final itemBranchId = _readString(item['branch_id'] ?? item['branchId']);
        return itemBranchId.isEmpty || itemBranchId == branchId;
      }).toList();

      for (final item in years) {
        if (_containsDate(item, appointmentDate)) {
          return item['id']?.toString() ?? '';
        }
      }
      if (years.isNotEmpty) return years.first['id']?.toString() ?? '';
    } catch (_) {}
    return '';
  }

  bool _containsDate(Map<String, dynamic> item, DateTime date) {
    final start = _parseDate(item['start_date'] ?? item['startDate']);
    final end = _parseDate(item['end_date'] ?? item['endDate']);
    final day = DateTime(date.year, date.month, date.day);
    if (start != null && day.isBefore(start)) return false;
    if (end != null && day.isAfter(end)) return false;
    return true;
  }

  Future<List<AdminModel>> fetchAdmins() async {
    final response = await _apiClient.get('/admins');
    return _extractRecords(response, 'admins')
        .where((j) => j['is_active'] != false)
        .where((j) {
          final admin = AdminModel.fromJson(j);
          final role = admin.role.toLowerCase().trim();
          return role != 'parent' && role != 'parents';
        })
        .map(AdminModel.fromJson)
        .toList();
  }

  Future<List<ParentInviteModel>> fetchParents() async {
    final response = await _apiClient.get('/parents');
    return _extractRecords(response, 'parents')
        .where((j) => _isActive(j))
        .where((j) => j['is_deleted'] != true && j['isDeleted'] != true)
        .map(ParentInviteModel.fromJson)
        .where((parent) => parent.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<StudentInviteModel>> fetchStudents() async {
    final response = await _apiClient.get('/students');
    return _extractRecords(response, 'students')
        .where((j) => _isActive(j))
        .where((j) => j['is_deleted'] != true && j['isDeleted'] != true)
        .map(StudentInviteModel.fromJson)
        .where((student) => student.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Map<String, AppointmentConflict>> checkConflicts({
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    required List<String> personIds,
  }) async {
    if (personIds.isEmpty) return const {};
    String pad(int n) => n.toString().padLeft(2, '0');
    final result = <String, AppointmentConflict>{};

    try {
      final response = await _apiClient.post(
        '/appointment-persons/check-conflicts',
        body: {
          'date': '${date.year}-${pad(date.month)}-${pad(date.day)}',
          'from_time': '${pad(start.hour)}:${pad(start.minute)}:00',
          'to_time': '${pad(end.hour)}:${pad(end.minute)}:00',
          'person_ids': personIds,
        },
      );

      final conflicts = _extractConflicts(response);
      for (final conflict in conflicts.whereType<Map<String, dynamic>>()) {
        final personId = _readString(
          conflict['person_id'] ??
              conflict['personId'] ??
              (conflict['person'] is Map ? conflict['person']['id'] : null),
        );
        final appointment =
            conflict['appointment'] ??
            conflict['appointment_data'] ??
            conflict['data'];
        if (personId.isEmpty || appointment is! Map) continue;

        final mapped = _conflictFromAppointment(
          personId: personId,
          appointment: Map<String, dynamic>.from(appointment),
          date: date,
          start: start,
          end: end,
        );
        if (mapped != null) result[personId] = mapped;
      }
    } catch (_) {
      // Local scan below still protects the picker when the API conflict
      // endpoint misses rescheduled slots or is temporarily unavailable.
    }

    result.addAll(
      await _checkLocalAppointmentConflicts(
        date: date,
        start: start,
        end: end,
        personIds: personIds,
      ),
    );
    return result;
  }

  Future<Map<String, AppointmentConflict>> _checkLocalAppointmentConflicts({
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
    required List<String> personIds,
  }) async {
    final idSet = personIds.where((id) => id.isNotEmpty).toSet();
    if (idSet.isEmpty) return const {};

    try {
      final appointments = await _fetchConflictAppointments();
      final result = <String, AppointmentConflict>{};

      for (final appointment in appointments) {
        if (!_canBlockTimeSlot(appointment)) continue;

        final mapped = _conflictFromAppointment(
          personId: '',
          appointment: appointment,
          date: date,
          start: start,
          end: end,
        );
        if (mapped == null) continue;

        for (final participant in _participantsForConflict(appointment)) {
          if (!_canParticipantBlockTimeSlot(participant)) continue;
          final personId = _readString(
            participant['person_id'] ??
                participant['personId'] ??
                (participant['person'] is Map
                    ? (participant['person'] as Map)['id']
                    : null),
          );
          if (!idSet.contains(personId)) continue;
          result[personId] = AppointmentConflict(
            personId: personId,
            title: mapped.title,
            date: mapped.date,
            start: mapped.start,
            end: mapped.end,
          );
        }
      }

      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchConflictAppointments() async {
    final session = await SessionService().load();
    final branchId = session?.branchId.trim() ?? '';
    final paths = [
      if (branchId.isNotEmpty) '/appointments/branch/$branchId',
      '/appointments',
    ];

    for (final path in paths) {
      try {
        final response = await _apiClient.get(path);
        return _extractItems(
          response,
        ).whereType<Map<String, dynamic>>().toList();
      } catch (_) {
        if (path == paths.last) rethrow;
      }
    }
    return const [];
  }

  AppointmentConflict? _conflictFromAppointment({
    required String personId,
    required Map<String, dynamic> appointment,
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
  }) {
    final slot = _activeScheduleSlot(appointment);
    if (slot == null) return null;
    if (!_sameDay(slot.date, date)) return null;
    if (!_overlaps(slot.start, slot.end, start, end)) return null;

    return AppointmentConflict(
      personId: personId,
      title: _readString(appointment['title']).ifEmpty('Appointment'),
      date: slot.date,
      start: slot.start,
      end: slot.end,
    );
  }

  _AppointmentSlot? _activeScheduleSlot(Map<String, dynamic> appointment) {
    final originalDate = _parseDate(appointment['date']);
    final originalStart = _parseTime(appointment['from_time']);
    final originalEnd = _parseTime(appointment['to_time']);

    final rescheduledDate = _parseDate(
      appointment['rescheduled_date'] ?? appointment['rescheduledDate'],
    );
    final rescheduledStart = _parseTime(
      appointment['rescheduled_from_time'] ??
          appointment['rescheduledFromTime'],
    );
    final rescheduledEnd = _parseTime(
      appointment['rescheduled_to_time'] ?? appointment['rescheduledToTime'],
    );

    final hasReschedule =
        rescheduledDate != null ||
        rescheduledStart != null ||
        rescheduledEnd != null;
    final effectiveDate = hasReschedule
        ? rescheduledDate ?? originalDate
        : originalDate;
    final effectiveStart = hasReschedule
        ? rescheduledStart ?? originalStart
        : originalStart;
    final effectiveEnd = hasReschedule
        ? rescheduledEnd ?? originalEnd
        : originalEnd;

    if (effectiveDate == null || effectiveStart == null) return null;
    return _AppointmentSlot(
      date: effectiveDate,
      start: effectiveStart,
      end: effectiveEnd ?? _addMinutes(effectiveStart, 30),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _overlaps(
    TimeOfDay existingStart,
    TimeOfDay existingEnd,
    TimeOfDay selectedStart,
    TimeOfDay selectedEnd,
  ) {
    return _toMinutes(existingStart) < _toMinutes(selectedEnd) &&
        _toMinutes(existingEnd) > _toMinutes(selectedStart);
  }

  bool _canBlockTimeSlot(Map<String, dynamic> appointment) {
    if (appointment['is_deleted'] == true || appointment['isDeleted'] == true) {
      return false;
    }
    if (appointment['is_active'] == false || appointment['isActive'] == false) {
      return false;
    }

    final status = _readString(appointment['status']).toUpperCase();
    return !{
      'CANCELLED',
      'CANCELED',
      'DECLINED',
      'REJECTED',
      'DELETED',
    }.contains(status);
  }

  bool _canParticipantBlockTimeSlot(Map<String, dynamic> participant) {
    if (participant['is_deleted'] == true || participant['isDeleted'] == true) {
      return false;
    }
    if (participant['is_active'] == false || participant['isActive'] == false) {
      return false;
    }

    final status = _readString(participant['status']).toUpperCase();
    return !{
      'CANCELLED',
      'CANCELED',
      'DECLINED',
      'REJECTED',
      'DELETED',
    }.contains(status);
  }

  List<Map<String, dynamic>> _participantsForConflict(
    Map<String, dynamic> appointment,
  ) {
    final raw =
        appointment['participants'] ??
        appointment['appointment_persons'] ??
        appointment['appointmentPersons'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
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

  Future<void> deleteAppointment(AppointmentModel model) async {
    if (model.id.isEmpty) {
      throw StateError('Missing appointment id');
    }

    try {
      await _apiClient.delete('/appointments/${model.id}');
    } catch (_) {
      await _apiClient.patch(
        '/appointments/${model.id}',
        body: {'is_deleted': true, 'is_active': false, 'status': 'CANCELLED'},
      );
    }
  }

  Future<void> rescheduleAppointment(
    AppointmentModel model,
    DateTime date,
    TimeOfDay start,
    TimeOfDay end,
  ) async {
    String pad(int n) => n.toString().padLeft(2, '0');
    final dateText = '${date.year}-${pad(date.month)}-${pad(date.day)}';
    final startText = '${pad(start.hour)}:${pad(start.minute)}:00';
    final endText = '${pad(end.hour)}:${pad(end.minute)}:00';

    if (model.id.isEmpty) {
      throw StateError('Missing appointment id');
    }

    await _apiClient.patch(
      '/appointments/${model.id}/reschedule',
      body: {
        'rescheduled_date': dateText,
        'rescheduled_from_time': startText,
        'rescheduled_to_time': endText,
      },
    );

    if (model.appointmentPersonId.isNotEmpty) {
      await _apiClient.patch(
        '/appointments/participants/${model.appointmentPersonId}/respond',
        body: {
          'status': 'RESCHEDULED',
          'proposed_date': dateText,
          'proposed_from_time': startText,
          'proposed_to_time': endText,
        },
      );
    }
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

  List<Map<String, dynamic>> _extractRecords(dynamic response, String key) {
    if (response is List) {
      return response.whereType<Map<String, dynamic>>().toList();
    }
    if (response is Map) {
      for (final candidate in [key, 'data', 'results', 'items', 'value']) {
        final value = response[candidate];
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<dynamic> _extractConflicts(dynamic response) {
    if (response is Map) {
      final direct = response['conflicts'];
      if (direct is List) return direct;
      final data = response['data'];
      if (data is Map && data['conflicts'] is List) {
        return data['conflicts'] as List;
      }
      final value = response['value'];
      if (value is Map && value['conflicts'] is List) {
        return value['conflicts'] as List;
      }
    }
    return const <dynamic>[];
  }

  bool _isActive(Map<String, dynamic> json) {
    final value = json['is_active'] ?? json['isActive'];
    return value != false;
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
      createdByName: _readString(
        json['created_by_name'] ?? json['createdByName'],
      ),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
      rescheduledAt: _parseDateTime(
        json['rescheduled_at'] ?? json['rescheduledAt'],
      ),
      originalDate: _parseDate(json['date']),
      originalStart: _parseTime(json['from_time']),
      originalEnd: _parseTime(json['to_time']),
      previousRescheduledDate: _parseDate(
        json['previous_rescheduled_date'] ?? json['previousRescheduledDate'],
      ),
      previousRescheduledStart: _parseTime(
        json['previous_rescheduled_from_time'] ??
            json['previousRescheduledFromTime'],
      ),
      previousRescheduledEnd: _parseTime(
        json['previous_rescheduled_to_time'] ??
            json['previousRescheduledToTime'],
      ),
      participants: _participantsFromJson(json),
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

  List<AppointmentParticipantModel> _participantsFromJson(
    Map<String, dynamic> appointment,
  ) {
    final raw =
        appointment['participants'] ??
        appointment['appointment_persons'] ??
        appointment['appointmentPersons'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map<String, dynamic>>()
        .where((participant) {
          if (participant['is_deleted'] == true ||
              participant['isDeleted'] == true) {
            return false;
          }
          if (participant['is_active'] == false ||
              participant['isActive'] == false) {
            return false;
          }
          return true;
        })
        .map(_participantFromJson)
        .toList();
  }

  AppointmentParticipantModel _participantFromJson(Map<String, dynamic> json) {
    final personType = _readString(
      json['person_type'] ?? json['personType'],
    ).toUpperCase().ifEmpty('ADMIN');
    return AppointmentParticipantModel(
      id: _readString(json['id']),
      personId: _readString(json['person_id'] ?? json['personId']),
      name: _participantName(json),
      personType: personType,
      roleLabel: _roleLabel(
        _readString(
          json['role_label'] ?? json['roleLabel'],
        ).ifEmpty(personType),
      ),
      status: _readString(json['status']).toUpperCase().ifEmpty('PENDING'),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      respondedAt: _parseDateTime(json['responded_at'] ?? json['respondedAt']),
      responseNote: _readString(json['response_note'] ?? json['responseNote']),
      rescheduleCount: _participantRescheduleCount(json),
      responseHistory: _responseHistoryFromJson(json['response_history']),
    );
  }

  List<ParticipantResponseHistoryModel> _responseHistoryFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((json) {
      return ParticipantResponseHistoryModel(
        status: _readString(
          json['status'] ?? json['action'],
        ).toUpperCase().ifEmpty('PENDING'),
        eventAt: _parseDateTime(
          json['event_at'] ??
              json['eventAt'] ??
              json['responded_at'] ??
              json['respondedAt'],
        ),
        note: _readString(
          json['response_note'] ?? json['responseNote'] ?? json['note'],
        ),
        proposedDate: _parseDate(json['proposed_date'] ?? json['proposedDate']),
        proposedStart: _parseTime(
          json['proposed_from_time'] ?? json['proposedFromTime'],
        ),
        proposedEnd: _parseTime(
          json['proposed_to_time'] ?? json['proposedToTime'],
        ),
        rescheduleCount:
            int.tryParse(
              _readString(
                json['reschedule_count'] ?? json['rescheduled_count'],
              ),
            ) ??
            0,
      );
    }).toList();
  }

  String _participantName(Map<String, dynamic> json) {
    final direct = _readString(json['name'] ?? json['fullName']);
    if (direct.isNotEmpty) return direct;
    final person = json['person'];
    if (person is Map) {
      final name = _personName(Map<String, dynamic>.from(person));
      if (name.isNotEmpty) return name;
    }
    return _readString(
      json['person_id'] ?? json['personId'],
    ).ifEmpty('Participant');
  }

  String _personName(Map<String, dynamic> json) {
    final first = _readString(json['first_name'] ?? json['firstName']);
    final last = _readString(json['last_name'] ?? json['lastName']);
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return _readString(json['username'] ?? json['email']);
  }

  String _roleLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
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

  DateTime? _parseDateTime(dynamic value) {
    final raw = _readString(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
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

class _AppointmentSlot {
  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;

  const _AppointmentSlot({
    required this.date,
    required this.start,
    required this.end,
  });
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

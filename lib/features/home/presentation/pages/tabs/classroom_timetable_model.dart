class ClassroomTimetableItem {
  const ClassroomTimetableItem({
    required this.id,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.subject,
    required this.teacher,
    required this.phone,
    required this.className,
    this.note,
  });

  final String id;
  final String dayOfWeek;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String subject;
  final String teacher;
  final String phone;
  final String className;
  final String? note;

  int get durationMinutes {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return end >= start ? end - start : (24 * 60 - start) + end;
  }

  factory ClassroomTimetableItem.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    final subjectType = subject is Map ? subject['subjectType'] : null;
    final teacher = json['teacher'];
    final klass = json['class'];
    final start = _parseTime(json['startTime']);
    final end = _parseTime(json['endTime']);
    final firstName = teacher is Map
        ? teacher['first_name']?.toString().trim() ?? ''
        : '';
    final lastName = teacher is Map
        ? teacher['last_name']?.toString().trim() ?? ''
        : '';

    return ClassroomTimetableItem(
      id: json['id']?.toString() ?? '',
      dayOfWeek: json['dayOfWeek']?.toString().toLowerCase() ?? '',
      startHour: start.$1,
      startMinute: start.$2,
      endHour: end.$1,
      endMinute: end.$2,
      subject: subjectType is Map
          ? subjectType['name']?.toString() ?? 'Subject'
          : 'Subject',
      teacher: [
        firstName,
        lastName,
      ].where((value) => value.isNotEmpty).join(' '),
      phone: teacher is Map
          ? (teacher['phone'] ?? teacher['tell'] ?? '').toString()
          : '',
      className: klass is Map
          ? klass['name']?.toString() ?? 'Classroom'
          : 'Classroom',
      note: _clean(json['note']),
    );
  }

  static (int, int) _parseTime(dynamic value) {
    final parts = value?.toString().split(':') ?? const [];
    return (
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.startsWith('__TIME_SET_TEMPLATE__')) return null;
    return text;
  }
}

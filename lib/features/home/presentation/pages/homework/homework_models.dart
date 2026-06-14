enum HomeworkStatus { submitted, pending }

enum HomeworkVisual { done, pending, overdue }

class HomeworkSubItem {
  final String id;
  final String title;
  final String? instruction;
  final String? imageUrl; // relative — resolve via HomeworkService
  final double? score;
  final int sortOrder;

  HomeworkSubItem({
    required this.id,
    required this.title,
    this.instruction,
    this.imageUrl,
    this.score,
    this.sortOrder = 0,
  });

  factory HomeworkSubItem.fromJson(Map<String, dynamic> json) {
    final inst = (json['itemInstruction']?.toString() ?? '').trim();
    final image = (json['imageUrl']?.toString() ?? '').trim();
    final score = json['score'];

    return HomeworkSubItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Question').toString(),
      instruction: inst.isEmpty ? null : inst,
      imageUrl: image.isEmpty ? null : image,
      score: score is num ? score.toDouble() : null,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : (json['sortOrder'] is num ? (json['sortOrder'] as num).toInt() : 0),
    );
  }
}

class HomeworkItem {
  final String id;
  final String subject;
  final String grade;
  final HomeworkStatus status;
  final String? teacherId;
  final String? teacher;
  final String? description;
  final double? totalScore;
  final double? yourScore;
  final bool isGraded;
  final String? teacherRemark;
  final DateTime? sentAt;
  final DateTime deadline;
  final List<HomeworkSubItem> items;

  HomeworkItem({
    required this.id,
    required this.subject,
    required this.grade,
    required this.status,
    this.teacherId,
    this.teacher,
    this.description,
    this.totalScore,
    this.yourScore,
    this.isGraded = false,
    this.teacherRemark,
    this.sentAt,
    required this.deadline,
    this.items = const [],
  });

  HomeworkItem copyWithTeacher(String? teacherName) {
    return HomeworkItem(
      id: id,
      subject: subject,
      grade: grade,
      status: status,
      teacherId: teacherId,
      teacher: teacherName,
      description: description,
      totalScore: totalScore,
      yourScore: yourScore,
      isGraded: isGraded,
      teacherRemark: teacherRemark,
      sentAt: sentAt,
      deadline: deadline,
      items: items,
    );
  }

  HomeworkItem copyWithStatus(HomeworkStatus value) {
    return HomeworkItem(
      id: id,
      subject: subject,
      grade: grade,
      status: value,
      teacherId: teacherId,
      teacher: teacher,
      description: description,
      totalScore: totalScore,
      yourScore: yourScore,
      isGraded: isGraded,
      teacherRemark: teacherRemark,
      sentAt: sentAt,
      deadline: deadline,
      items: items,
    );
  }

  HomeworkItem copyWithResult({
    required double? score,
    required bool graded,
    String? teacherRemark,
  }) {
    return HomeworkItem(
      id: id,
      subject: subject,
      grade: grade,
      status: HomeworkStatus.submitted,
      teacherId: teacherId,
      teacher: teacher,
      description: description,
      totalScore: totalScore,
      yourScore: score,
      isGraded: graded,
      teacherRemark: teacherRemark,
      sentAt: sentAt,
      deadline: deadline,
      items: items,
    );
  }

  HomeworkVisual visual(DateTime now) {
    if (status == HomeworkStatus.submitted) return HomeworkVisual.done;
    if (deadline.isBefore(now)) return HomeworkVisual.overdue;
    return HomeworkVisual.pending;
  }

  factory HomeworkItem.fromJson(Map<String, dynamic> json) {
    final klass = json['class'];
    final className = (klass is Map ? klass['name'] : null)?.toString() ?? '';

    final teaching = json['teaching'];
    final teacherId = teaching is Map
        ? (teaching['adminId']?.toString())
        : null;

    final due = _parseDate(json['dueDate']);
    final sent = _parseNullableDate(json['sentAt']);

    final rawItems = json['items'];
    final subs = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(HomeworkSubItem.fromJson)
              .toList()
        : <HomeworkSubItem>[];
    subs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final ts = json['totalScore'];

    return HomeworkItem(
      id: (json['id'] ?? '').toString(),
      subject: (json['title'] ?? 'Untitled').toString(),
      grade: className.isEmpty ? '—' : className,
      // The endpoint reports teacher-side status (e.g. "sent"). We treat
      // every received row as pending until per-student submission data
      // is available; the visual layer reclassifies overdue by deadline.
      status: HomeworkStatus.pending,
      teacherId: (teacherId == null || teacherId.isEmpty) ? null : teacherId,
      teacher: null,
      description: (json['overallInstruction']?.toString() ?? '').trim().isEmpty
          ? null
          : json['overallInstruction'].toString().trim(),
      totalScore: ts is num ? ts.toDouble() : null,
      yourScore: null,
      isGraded: false,
      teacherRemark: null,
      sentAt: sent,
      deadline: due,
      items: subs,
    );
  }

  static DateTime _parseDate(dynamic v) {
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime? _parseNullableDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }
}

enum HomeworkSort { nearestDue, latestDue, subjectAZ }

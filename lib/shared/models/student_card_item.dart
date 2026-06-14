class StudentCardItem {
  /// Internal UUID (students.id) — used to match foreign keys in other tables.
  final String? id;

  /// Human-readable student code (students.student_id).
  final String studentId;
  final String name;
  final String? photoUrl;
  final String? className;

  /// branchId carried by the student's active enrollment.
  final String? branchId;

  /// classId carried by the student's active enrollment.
  final String? classId;

  const StudentCardItem({
    required this.studentId,
    required this.name,
    this.id,
    this.photoUrl,
    this.className,
    this.branchId,
    this.classId,
  });
}

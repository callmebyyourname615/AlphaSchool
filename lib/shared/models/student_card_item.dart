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

  /// false → student is awaiting admin approval; the parent can see it as a
  /// placeholder card but cannot open its details.
  final bool isApproved;
  final String approvalStatus;
  final String? rejectReason;
  final String? linkRequestId;

  const StudentCardItem({
    required this.studentId,
    required this.name,
    this.id,
    this.photoUrl,
    this.className,
    this.branchId,
    this.classId,
    this.isApproved = true,
    this.approvalStatus = 'approved',
    this.rejectReason,
    this.linkRequestId,
  });

  bool get isRejected => approvalStatus == 'rejected';
  bool get isQrLinkRequest => linkRequestId != null && linkRequestId!.isNotEmpty;
}

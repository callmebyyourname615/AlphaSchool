class StudentCardItem {
  final String studentId;
  final String name;
  final String? photoUrl;
  final String? className;

  const StudentCardItem({
    required this.studentId,
    required this.name,
    this.photoUrl,
    this.className,
  });
}

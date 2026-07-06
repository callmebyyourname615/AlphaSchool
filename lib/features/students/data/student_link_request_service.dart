import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// A parent scanned an existing student's QR code and asked to be linked as
/// an additional guardian. Mirrors API_Alphaschool_Merge's
/// StudentLinkRequest entity — separate from the student's own creation
/// approval, since this only gates whether the scanning parent gets added to
/// that (already-approved) student's parent list.
class StudentLinkRequestResult {
  final String id;
  final String status;
  final String studentId;
  final String studentName;
  final String? rejectionReason;

  const StudentLinkRequestResult({
    required this.id,
    required this.status,
    required this.studentId,
    required this.studentName,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory StudentLinkRequestResult.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    String name = '';
    if (student is Map) {
      final eng = [student['first_name_eng'], student['last_name_eng']]
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .join(' ');
      final lao = [student['first_name_lao'], student['last_name_lao']]
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .join(' ');
      name = eng.isNotEmpty ? eng : lao;
    }
    return StudentLinkRequestResult(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      studentName: name,
      rejectionReason: (json['rejectionReason'] as String?),
    );
  }
}

/// Thrown when the backend refuses to create a link request — e.g. the
/// student is already linked to this parent, or a request is already
/// pending review. [message] is safe to show directly to the parent.
class StudentLinkRequestException implements Exception {
  final String message;
  const StudentLinkRequestException(this.message);

  @override
  String toString() => message;
}

class StudentLinkRequestService {
  StudentLinkRequestService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<StudentLinkRequestResult> create({
    required String studentId,
    required String parentId,
  }) async {
    try {
      final res = await _api.post(
        '/student-link-requests',
        body: {'studentId': studentId, 'parentId': parentId},
      );
      if (res is Map<String, dynamic>) {
        return StudentLinkRequestResult.fromJson(res);
      }
      if (res is Map) {
        return StudentLinkRequestResult.fromJson(
          Map<String, dynamic>.from(res),
        );
      }
      throw const ApiException('Unexpected response from server.');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw const StudentLinkRequestException(
          "This doesn't look like a valid student QR code.",
        );
      }
      if (e.statusCode == 409) {
        throw StudentLinkRequestException(e.message);
      }
      rethrow;
    }
  }
}

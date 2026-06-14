class BranchInfo {
  final String id;
  final String code;
  final String branchNo;
  final String name;
  final String phone;
  final String contact;
  final String address;
  final String? profilePicPath;

  const BranchInfo({
    required this.id,
    required this.code,
    required this.branchNo,
    required this.name,
    required this.phone,
    required this.contact,
    required this.address,
    this.profilePicPath,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> json) {
    return BranchInfo(
      id: (json['id'] ?? '').toString(),
      code: (json['branch_id'] ?? '').toString(),
      branchNo: (json['branch_no'] ?? json['branchNo'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      address: _flattenAddress(json['address']),
      profilePicPath:
          (json['profile_pic'] is String &&
              (json['profile_pic'] as String).isNotEmpty)
          ? json['profile_pic'] as String
          : null,
    );
  }

  static String _flattenAddress(dynamic raw) {
    if (raw is String) return raw;
    if (raw is Map) {
      final parts =
          [
                raw['village'],
                raw['district_id'] ?? raw['district'],
                raw['province_id'] ?? raw['province'],
              ]
              .map((v) => v?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
      return parts.join(', ');
    }
    return '';
  }
}

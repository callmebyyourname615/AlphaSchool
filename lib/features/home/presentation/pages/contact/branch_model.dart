class BranchInfo {
  final String id;
  final String code;
  final String branchNo;
  final String name;
  final String phone;
  final String contact;
  final String address;
  final String mapUrl;
  final String facebookUrl;
  final String whatsappUrl;
  final String websiteUrl;
  final String? profilePicPath;

  const BranchInfo({
    required this.id,
    required this.code,
    required this.branchNo,
    required this.name,
    required this.phone,
    required this.contact,
    required this.address,
    required this.mapUrl,
    required this.facebookUrl,
    required this.whatsappUrl,
    required this.websiteUrl,
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
      mapUrl: (json['branch_map'] ?? json['map'] ?? '').toString().trim(),
      facebookUrl: (json['branch_fb'] ?? json['facebook'] ?? '')
          .toString()
          .trim(),
      whatsappUrl:
          (json['branch_whatsapp'] ??
                  json['whatsapp'] ??
                  json['whatapp'] ??
                  json['whatsapp_url'] ??
                  json['whatapp_url'] ??
                  json['whatsapp_number'] ??
                  json['whatapp_number'] ??
                  json['branch_wa'] ??
                  json['branch_whatapp'] ??
                  '')
              .toString()
              .trim(),
      websiteUrl: (json['branch_website'] ?? json['website'] ?? '')
          .toString()
          .trim(),
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

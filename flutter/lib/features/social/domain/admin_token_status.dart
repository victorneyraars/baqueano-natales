/// Estado del admin token de Facebook.
class AdminTokenStatus {
  const AdminTokenStatus({required this.hasToken, this.updatedAt});

  final bool hasToken;
  final DateTime? updatedAt;

  factory AdminTokenStatus.fromJson(Map<String, dynamic> json) {
    return AdminTokenStatus(
      hasToken: json['has_token'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

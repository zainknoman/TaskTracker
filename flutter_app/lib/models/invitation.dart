class Invitation {
  final String id;
  final String workspaceId;
  final String token;
  final String role;
  final String createdBy;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  const Invitation({
    required this.id,
    required this.workspaceId,
    required this.token,
    required this.role,
    required this.createdBy,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        token: json['token'] as String,
        role: json['role'] as String,
        createdBy: json['created_by'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'token': token,
        'role': role,
        'created_by': createdBy,
        'expires_at': expiresAt.toIso8601String(),
        'used_at': usedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

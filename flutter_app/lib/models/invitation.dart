class Invitation {
  final String id;
  final String workspaceId;
  final String token;
  final String role;
  final String? label;
  final String status; // pending | accepted | cancelled
  final String invitedBy;
  final String? acceptedBy;
  final DateTime expiresAt;
  final DateTime createdAt;

  const Invitation({
    required this.id,
    required this.workspaceId,
    required this.token,
    required this.role,
    this.label,
    required this.status,
    required this.invitedBy,
    this.acceptedBy,
    required this.expiresAt,
    required this.createdAt,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        token: json['token'] as String,
        role: json['role'] as String,
        label: json['label'] as String?,
        status: json['status'] as String,
        invitedBy: json['invited_by'] as String,
        acceptedBy: json['accepted_by'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'token': token,
        'role': role,
        'label': label,
        'status': status,
        'invited_by': invitedBy,
        'accepted_by': acceptedBy,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

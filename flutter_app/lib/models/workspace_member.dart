class WorkspaceMember {
  final String id;
  final String workspaceId;
  final String userId;
  final String role; // owner | member | guest
  final String? displayName;
  final String? avatarUrl;
  final String? avatarPreset;
  final String? color;
  final List<String> skills;
  final DateTime joinedAt;

  const WorkspaceMember({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.role,
    this.displayName,
    this.avatarUrl,
    this.avatarPreset,
    this.color,
    required this.skills,
    required this.joinedAt,
  });

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) => WorkspaceMember(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        avatarPreset: json['avatar_preset'] as String?,
        color: json['color'] as String?,
        skills: List<String>.from(json['skills'] as List? ?? const []),
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'role': role,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'avatar_preset': avatarPreset,
        'color': color,
        'skills': skills,
        'joined_at': joinedAt.toIso8601String(),
      };

  WorkspaceMember copyWith({
    String? displayName,
    String? avatarUrl,
    String? avatarPreset,
    String? color,
    List<String>? skills,
  }) =>
      WorkspaceMember(
        id: id,
        workspaceId: workspaceId,
        userId: userId,
        role: role,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        avatarPreset: avatarPreset ?? this.avatarPreset,
        color: color ?? this.color,
        skills: skills ?? this.skills,
        joinedAt: joinedAt,
      );
}

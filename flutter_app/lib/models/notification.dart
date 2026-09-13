class AppNotification {
  final String id;
  final String workspaceId;
  final String userId;
  final String type;
  final String message;
  final String? taskId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.type,
    required this.message,
    this.taskId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        taskId: json['task_id'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'type': type,
        'message': message,
        'task_id': taskId,
        'read': read,
        'created_at': createdAt.toIso8601String(),
      };
}

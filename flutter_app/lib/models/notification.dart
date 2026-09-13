class AppNotification {
  final String id;
  final String workspaceId;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.entityType,
    this.entityId,
    required this.read,
    required this.createdAt,
  });

  /// Convenience accessor: the linked task's id, when this notification is about a task.
  String? get taskId => entityType == 'task' ? entityId : null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'entity_type': entityType,
        'entity_id': entityId,
        'read': read,
        'created_at': createdAt.toIso8601String(),
      };
}

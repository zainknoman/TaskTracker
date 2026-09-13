class TaskComment {
  final String id;
  final String taskId;
  final String workspaceId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  const TaskComment({
    required this.id,
    required this.taskId,
    required this.workspaceId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
        id: json['id'] as String,
        taskId: json['task_id'] as String,
        workspaceId: json['workspace_id'] as String,
        authorId: json['author_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'task_id': taskId,
        'workspace_id': workspaceId,
        'author_id': authorId,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}

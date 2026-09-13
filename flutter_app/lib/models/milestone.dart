class Milestone {
  final String id;
  final String workspaceId;
  final String projectId;
  final String title;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;

  const Milestone({
    required this.id,
    required this.workspaceId,
    required this.projectId,
    required this.title,
    this.dueDate,
    required this.status,
    required this.createdAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        projectId: json['project_id'] as String,
        title: json['title'] as String,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'project_id': projectId,
        'title': title,
        'due_date': dueDate?.toIso8601String(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

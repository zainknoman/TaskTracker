class Milestone {
  final String id;
  final String workspaceId;
  final String projectId;
  final String name;
  final String? description;
  final DateTime? dueDate;
  final String status;
  final int sortOrder;
  final DateTime createdAt;

  const Milestone({
    required this.id,
    required this.workspaceId,
    required this.projectId,
    required this.name,
    this.description,
    this.dueDate,
    required this.status,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        projectId: json['project_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        status: json['status'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'project_id': projectId,
        'name': name,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'status': status,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };
}

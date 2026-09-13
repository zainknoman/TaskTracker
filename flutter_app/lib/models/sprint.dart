class Sprint {
  final String id;
  final String workspaceId;
  final String projectId;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final DateTime createdAt;

  const Sprint({
    required this.id,
    required this.workspaceId,
    required this.projectId,
    required this.name,
    this.startDate,
    this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory Sprint.fromJson(Map<String, dynamic> json) => Sprint(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        projectId: json['project_id'] as String,
        name: json['name'] as String,
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'project_id': projectId,
        'name': name,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

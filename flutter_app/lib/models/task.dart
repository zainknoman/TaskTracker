class Task {
  final String id;
  final String workspaceId;
  final String projectId;
  final String? milestoneId;
  final String? sprintId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final String priority; // low | medium | high | critical
  final String status; // pending | in_progress | completed | blocked
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? ba;
  final String? assigneeId;
  final num? estimatedHours;
  final num? actualHours;
  final int progress;
  final List<String> tags;
  final List<dynamic> documents;
  final List<dynamic> dependencies;
  final List<dynamic> subtasks;
  final String? notes;
  final bool starred;
  final bool pinned;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.workspaceId,
    required this.projectId,
    this.milestoneId,
    this.sprintId,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.startDate,
    this.dueDate,
    this.ba,
    this.assigneeId,
    this.estimatedHours,
    this.actualHours,
    required this.progress,
    required this.tags,
    required this.documents,
    required this.dependencies,
    required this.subtasks,
    this.notes,
    required this.starred,
    required this.pinned,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        projectId: json['project_id'] as String,
        milestoneId: json['milestone_id'] as String?,
        sprintId: json['sprint_id'] as String?,
        parentTaskId: json['parent_task_id'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: json['priority'] as String,
        status: json['status'] as String,
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        ba: json['ba'] as String?,
        assigneeId: json['assignee_id'] as String?,
        estimatedHours: json['estimated_hours'] as num?,
        actualHours: json['actual_hours'] as num?,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        tags: List<String>.from(json['tags'] as List? ?? const []),
        documents: List<dynamic>.from(json['documents'] as List? ?? const []),
        dependencies: List<dynamic>.from(json['dependencies'] as List? ?? const []),
        subtasks: List<dynamic>.from(json['subtasks'] as List? ?? const []),
        notes: json['notes'] as String?,
        starred: json['starred'] as bool? ?? false,
        pinned: json['pinned'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'project_id': projectId,
        'milestone_id': milestoneId,
        'sprint_id': sprintId,
        'parent_task_id': parentTaskId,
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'start_date': startDate?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'ba': ba,
        'assignee_id': assigneeId,
        'estimated_hours': estimatedHours,
        'actual_hours': actualHours,
        'progress': progress,
        'tags': tags,
        'documents': documents,
        'dependencies': dependencies,
        'subtasks': subtasks,
        'notes': notes,
        'starred': starred,
        'pinned': pinned,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Task copyWith({
    String? title,
    String? description,
    String? priority,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
    String? assigneeId,
    num? estimatedHours,
    num? actualHours,
    int? progress,
    List<String>? tags,
    String? notes,
    bool? starred,
    bool? pinned,
    String? milestoneId,
    String? sprintId,
  }) =>
      Task(
        id: id,
        workspaceId: workspaceId,
        projectId: projectId,
        milestoneId: milestoneId ?? this.milestoneId,
        sprintId: sprintId ?? this.sprintId,
        parentTaskId: parentTaskId,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        dueDate: dueDate ?? this.dueDate,
        ba: ba,
        assigneeId: assigneeId ?? this.assigneeId,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        actualHours: actualHours ?? this.actualHours,
        progress: progress ?? this.progress,
        tags: tags ?? this.tags,
        documents: documents,
        dependencies: dependencies,
        subtasks: subtasks,
        notes: notes ?? this.notes,
        starred: starred ?? this.starred,
        pinned: pinned ?? this.pinned,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

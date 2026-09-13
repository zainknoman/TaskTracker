class Project {
  final String id;
  final String workspaceId;
  final String name;
  final String? code;
  final String? description;
  final String? department;
  final String? client;
  final String? pm;
  final List<String> baTeam;
  final String status; // active | planning | onhold | completed | archived
  final String priority; // low | medium | high | critical
  final DateTime? startDate;
  final DateTime? endDate;
  final num? budget;
  final String? color;
  final List<String> tags;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.code,
    this.description,
    this.department,
    this.client,
    this.pm,
    this.baTeam = const [],
    required this.status,
    required this.priority,
    this.startDate,
    this.endDate,
    this.budget,
    this.color,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        name: json['name'] as String,
        code: json['code'] as String?,
        description: json['description'] as String?,
        department: json['department'] as String?,
        client: json['client'] as String?,
        pm: json['pm'] as String?,
        baTeam: List<String>.from(json['ba_team'] as List? ?? const []),
        status: json['status'] as String,
        priority: json['priority'] as String,
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
        budget: json['budget'] as num?,
        color: json['color'] as String?,
        tags: List<String>.from(json['tags'] as List? ?? const []),
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'name': name,
        'code': code,
        'description': description,
        'department': department,
        'client': client,
        'pm': pm,
        'ba_team': baTeam,
        'status': status,
        'priority': priority,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'budget': budget,
        'color': color,
        'tags': tags,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Project copyWith({
    String? name,
    String? code,
    String? description,
    String? department,
    String? client,
    String? pm,
    List<String>? baTeam,
    String? status,
    String? priority,
    DateTime? startDate,
    DateTime? endDate,
    num? budget,
    String? color,
    List<String>? tags,
  }) =>
      Project(
        id: id,
        workspaceId: workspaceId,
        name: name ?? this.name,
        code: code ?? this.code,
        description: description ?? this.description,
        department: department ?? this.department,
        client: client ?? this.client,
        pm: pm ?? this.pm,
        baTeam: baTeam ?? this.baTeam,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        budget: budget ?? this.budget,
        color: color ?? this.color,
        tags: tags ?? this.tags,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

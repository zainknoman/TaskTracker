class Workspace {
  final String id;
  final String name;
  final String slug;
  final String ownerId;
  final DateTime createdAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerId,
    required this.createdAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        ownerId: json['owner_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'owner_id': ownerId,
        'created_at': createdAt.toIso8601String(),
      };
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tasktracker_flutter/models/project.dart';

void main() {
  test('Project.fromJson / toJson round-trip', () {
    final json = {
      'id': 'p1',
      'workspace_id': 'w1',
      'name': 'Acme Website',
      'code': 'ACME-WEB',
      'description': 'desc',
      'department': 'Engineering',
      'client': 'Acme Corp',
      'pm': 'Alice',
      'ba_team': 'BA Team 1',
      'status': 'active',
      'priority': 'high',
      'start_date': '2026-01-01',
      'end_date': null,
      'budget': 10000,
      'color': '#4F46E5',
      'tags': ['web'],
      'created_by': 'u1',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    };
    final project = Project.fromJson(json);
    expect(project.name, 'Acme Website');
    expect(project.status, 'active');
    expect(project.tags, ['web']);
    expect(project.toJson()['name'], 'Acme Website');
  });

  test('Project.copyWith overrides only given fields', () {
    final project = Project.fromJson({
      'id': 'p1',
      'workspace_id': 'w1',
      'name': 'A',
      'code': null,
      'description': null,
      'department': null,
      'client': null,
      'pm': null,
      'ba_team': null,
      'status': 'planning',
      'priority': 'low',
      'start_date': null,
      'end_date': null,
      'budget': null,
      'color': null,
      'tags': [],
      'created_by': 'u1',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    });
    final updated = project.copyWith(status: 'completed');
    expect(updated.status, 'completed');
    expect(updated.name, 'A');
  });
}

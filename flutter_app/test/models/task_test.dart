import 'package:flutter_test/flutter_test.dart';
import 'package:tasktracker_flutter/models/task.dart';

void main() {
  test('Task.fromJson / toJson round-trip', () {
    final json = {
      'id': 't1',
      'workspace_id': 'w1',
      'project_id': 'p1',
      'milestone_id': null,
      'sprint_id': null,
      'parent_task_id': null,
      'title': 'Write plan',
      'description': 'desc',
      'priority': 'high',
      'status': 'inprogress',
      'start_date': null,
      'due_date': '2026-09-20',
      'ba': null,
      'assignee_id': 'u1',
      'estimated_hours': 4,
      'actual_hours': 0,
      'progress': 25,
      'tags': ['flutter'],
      'documents': [],
      'dependencies': [],
      'subtasks': [],
      'notes': null,
      'starred': false,
      'pinned': false,
      'created_by': 'u1',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    };
    final task = Task.fromJson(json);
    expect(task.title, 'Write plan');
    expect(task.priority, 'high');
    expect(task.tags, ['flutter']);
    expect(task.toJson()['title'], 'Write plan');
  });

  test('Task.copyWith overrides only given fields', () {
    final task = Task.fromJson({
      'id': 't1',
      'workspace_id': 'w1',
      'project_id': 'p1',
      'milestone_id': null,
      'sprint_id': null,
      'parent_task_id': null,
      'title': 'A',
      'description': null,
      'priority': 'low',
      'status': 'pending',
      'start_date': null,
      'due_date': null,
      'ba': null,
      'assignee_id': null,
      'estimated_hours': null,
      'actual_hours': null,
      'progress': 0,
      'tags': [],
      'documents': [],
      'dependencies': [],
      'subtasks': [],
      'notes': null,
      'starred': false,
      'pinned': false,
      'created_by': 'u1',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    });
    final updated = task.copyWith(status: 'completed');
    expect(updated.status, 'completed');
    expect(updated.title, 'A');
  });
}

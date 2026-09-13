import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/task.dart';
import 'exceptions.dart';

class TaskRepository {
  final SupabaseClient _client;
  TaskRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<Task>> listForWorkspace(String workspaceId) async {
    try {
      final rows = await _client.from('tasks').select().eq('workspace_id', workspaceId);
      return rows.map((r) => Task.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Task> create(Task task) async {
    try {
      final payload = task.toJson()..remove('id');
      final row = await _client.from('tasks').insert(payload).select().single();
      return Task.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Task> update(Task task) async {
    try {
      final row = await _client.from('tasks').update(task.toJson()).eq('id', task.id).select().single();
      return Task.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('tasks').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Stream<List<Task>> streamForWorkspace(String workspaceId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .map((rows) => rows.map((r) => Task.fromJson(r)).toList());
  }
}

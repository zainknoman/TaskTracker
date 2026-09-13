import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/task_comment.dart';
import 'exceptions.dart';

class TaskCommentRepository {
  final SupabaseClient _client;
  TaskCommentRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<TaskComment> create(TaskComment comment) async {
    try {
      final payload = comment.toJson()..remove('id');
      final row = await _client.from('task_comments').insert(payload).select().single();
      return TaskComment.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  // One-time fetch, not a Realtime stream: task_comments has no Realtime
  // replication enabled on this Supabase project (see readme.md "Database ->
  // How to access the database" and js/realtime.js, which doesn't subscribe
  // to it either). Callers must ref.invalidate() the provider after create().
  Future<List<TaskComment>> listForTask(String taskId) async {
    try {
      final rows = await _client
          .from('task_comments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return rows.map((r) => TaskComment.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }
}

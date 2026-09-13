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

  Stream<List<TaskComment>> streamForTask(String taskId) {
    return _client
        .from('task_comments')
        .stream(primaryKey: ['id'])
        .eq('task_id', taskId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => TaskComment.fromJson(r)).toList());
  }
}

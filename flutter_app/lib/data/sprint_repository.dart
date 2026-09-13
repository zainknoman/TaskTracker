import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/sprint.dart';
import 'exceptions.dart';

class SprintRepository {
  final SupabaseClient _client;
  SprintRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<Sprint>> listForProject(String projectId) async {
    try {
      final rows = await _client.from('sprints').select().eq('project_id', projectId);
      return rows.map((r) => Sprint.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Sprint> create(Sprint sprint) async {
    try {
      final payload = sprint.toJson()..remove('id');
      final row = await _client.from('sprints').insert(payload).select().single();
      return Sprint.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Sprint> update(Sprint sprint) async {
    try {
      final row = await _client.from('sprints').update(sprint.toJson()).eq('id', sprint.id).select().single();
      return Sprint.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('sprints').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }
}

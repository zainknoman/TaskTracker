import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/milestone.dart';
import 'exceptions.dart';

class MilestoneRepository {
  final SupabaseClient _client;
  MilestoneRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<Milestone>> listForProject(String projectId) async {
    try {
      final rows = await _client.from('milestones').select().eq('project_id', projectId);
      return rows.map((r) => Milestone.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Milestone> create(Milestone milestone) async {
    try {
      final payload = milestone.toJson()..remove('id');
      final row = await _client.from('milestones').insert(payload).select().single();
      return Milestone.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Milestone> update(Milestone milestone) async {
    try {
      final row =
          await _client.from('milestones').update(milestone.toJson()).eq('id', milestone.id).select().single();
      return Milestone.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('milestones').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/notification.dart';
import 'exceptions.dart';

class NotificationRepository {
  final SupabaseClient _client;
  NotificationRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<AppNotification>> listForUser(String userId) async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows.map((r) => AppNotification.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client.from('notifications').update({'read': true}).eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Stream<List<AppNotification>> streamForUser(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => AppNotification.fromJson(r)).toList());
  }
}

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/supabase_config.dart';
import 'exceptions.dart';

class AuthRepository {
  final sb.SupabaseClient _client;
  AuthRepository({sb.SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  sb.User? get currentUser => _client.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthFailureException(e.message);
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthFailureException(e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

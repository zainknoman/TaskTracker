import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.value?.session?.user ?? SupabaseConfig.client.auth.currentUser;
});

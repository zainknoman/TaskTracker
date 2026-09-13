import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zynunureylcdexxhvdth.supabase.co',
  );
  // Same anon/public key the web app ships in config.js (gitignored there too,
  // but safe to embed here: it's RLS-restricted, not a secret - see readme.md
  // "How to access the database"). Override with --dart-define for a
  // different Supabase project.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5bnVudXJleWxjZGV4eGh2ZHRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5MTI3NzcsImV4cCI6MjA5NDQ4ODc3N30._-PPlFHrYI7tv6_V_hmlQ9p5wVFGl4X4uGKxuQd2XbY',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tasktracker_flutter/data/exceptions.dart';

void main() {
  test('mapPostgrestError maps RLS denial to PermissionDeniedException', () {
    final err = PostgrestException(message: 'new row violates row-level security policy', code: '42501');
    final mapped = mapPostgrestError(err);
    expect(mapped, isA<PermissionDeniedException>());
  });

  test('mapPostgrestError maps not-found code to NotFoundException', () {
    final err = PostgrestException(message: 'no rows returned', code: 'PGRST116');
    final mapped = mapPostgrestError(err);
    expect(mapped, isA<NotFoundException>());
  });

  test('mapPostgrestError falls back to AppException', () {
    final err = PostgrestException(message: 'boom', code: '500');
    final mapped = mapPostgrestError(err);
    expect(mapped, isA<AppException>());
  });
}

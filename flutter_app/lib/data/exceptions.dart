import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

class AuthFailureException extends AppException {
  AuthFailureException(super.message);
}

class PermissionDeniedException extends AppException {
  PermissionDeniedException(super.message);
}

class NotFoundException extends AppException {
  NotFoundException(super.message);
}

AppException mapPostgrestError(PostgrestException err) {
  if (err.code == '42501' || err.message.toLowerCase().contains('row-level security')) {
    return PermissionDeniedException('You do not have permission to do that.');
  }
  if (err.code == 'PGRST116' || err.message.toLowerCase().contains('no rows')) {
    return NotFoundException('The requested item was not found.');
  }
  return AppException(err.message);
}

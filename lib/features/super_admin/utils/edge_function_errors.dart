import 'package:supabase_flutter/supabase_flutter.dart';

/// Human-readable message from Supabase RPC / PostgREST failures.
String supabaseErrorMessage(Object error) {
  if (error is PostgrestException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) return msg;
  }
  return error.toString();
}

/// Human-readable message from a Supabase edge-function failure.
String edgeFunctionErrorMessage(Object error) {
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map) {
      final err = details['error'];
      if (err is String && err.trim().isNotEmpty) return err.trim();
      if (err is Map) {
        final msg = err['message'] ?? err['msg'] ?? err['error_description'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
    }
    if (error.reasonPhrase != null && error.reasonPhrase!.isNotEmpty) {
      return error.reasonPhrase!;
    }
  }
  return error.toString();
}

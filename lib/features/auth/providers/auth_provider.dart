import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/app_logger.dart';

enum AuthStatus { idle, loading, error }

/// Maps raw Supabase auth errors to user-friendly messages.
/// Top-level (rather than a private method) so it can be unit-tested.
String friendlyAuthError(Object e) {
  final msg = e.toString();
  if (msg.contains('Invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  if (msg.contains('already registered')) {
    return 'That email is already registered. Try logging in.';
  }
  if (msg.contains('Password should be')) {
    return 'Password must be at least 6 characters.';
  }
  // handle_new_user() fails on the unique username constraint.
  if (msg.contains('Database error saving new user')) {
    return 'That username is taken. Try another one.';
  }
  if (msg.contains('Email not confirmed')) {
    return 'Confirm your email first. Check your inbox for the link.';
  }
  if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
    return 'No internet connection. Check your data or Wi-Fi.';
  }
  return 'Something went wrong. Please try again.';
}

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  const AuthState({this.status = AuthStatus.idle, this.errorMessage});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await SupabaseService.client.auth
          .signInWithPassword(email: email, password: password);
      state = const AuthState(status: AuthStatus.idle);
      return true;
    } catch (e, st) {
      AppLogger.error('signIn failed', name: 'auth', error: e, stackTrace: st);
      state = AuthState(
          status: AuthStatus.error, errorMessage: friendlyAuthError(e));
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    String? department,
    String? level,
    String? university,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'username': username,
          if (department != null) 'department': department,
          if (level != null) 'level': level,
          if (university != null) 'university': university,
        },
      );
      state = const AuthState(status: AuthStatus.idle);
      return true;
    } catch (e, st) {
      AppLogger.error('signUp failed', name: 'auth', error: e, stackTrace: st);
      state = AuthState(
          status: AuthStatus.error, errorMessage: friendlyAuthError(e));
      return false;
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_initialization.dart';

class AuthService {
  SupabaseClient? get _client {
    if (!AppInitialization.supabaseAvailable) {
      return null;
    }

    return AppInitialization.supabase;
  }

  User? get currentUser {
    return _client?.auth.currentUser;
  }

  bool get isAuthenticated {
    return currentUser != null;
  }

  /// Whether sign-in can be offered at all (Supabase configured).
  bool get isAvailable => _client != null;

  /// True for the silent guest account every install starts with.
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  String? get email => currentUser?.email;

  /// Emails a 6-digit sign-in code, creating the account if needed.
  /// The Supabase "Magic Link" email template must include {{ .Token }}.
  Future<void> sendEmailCode(String email) async {
    final client = _client;
    if (client == null) throw StateError('Sign-in is not configured.');
    await client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Signs in with the emailed [code]. The previous guest session is
  /// replaced; local birth profiles stay on the device.
  Future<void> verifyEmailCode(String email, String code) async {
    final client = _client;
    if (client == null) throw StateError('Sign-in is not configured.');
    await client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.email,
    );
  }

  /// Signs out and starts a fresh guest session so the app keeps working.
  Future<void> signOutToGuest() async {
    await signOut();
    await signInAnonymously();
  }

  Future<void> signInAnonymously() async {
    final client = _client;

    if (client == null) {
      return;
    }

    if (client.auth.currentUser != null) {
      return;
    }

    await client.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    final client = _client;

    if (client == null) {
      return;
    }

    await client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges {
    final client = _client;

    if (client == null) {
      return const Stream.empty();
    }

    return client.auth.onAuthStateChange;
  }
}

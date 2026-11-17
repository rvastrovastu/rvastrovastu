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

  /// True only for a real (non-guest) account with an active session.
  bool get isSignedInAccount => currentUser != null && !isAnonymous;

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

  /// Creates an account with email and password. If this device is a guest,
  /// the guest account is upgraded in place so existing bookings stay linked.
  Future<void> signUpWithPassword(
    String email,
    String password,
    String username,
  ) async {
    final client = _client;
    if (client == null) throw StateError('Sign-in is not configured.');
    final user = client.auth.currentUser;
    if (user != null && user.isAnonymous) {
      await client.auth.updateUser(
        UserAttributes(
          email: email.trim(),
          password: password,
          data: {'username': username.trim()},
        ),
      );
    } else {
      await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim()},
      );
    }
  }

  /// Signs in with email and password.
  Future<void> signInWithPassword(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Sign-in is not configured.');
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Emails a password reset link. The link opens the app.
  Future<void> sendPasswordReset(String email) async {
    final client = _client;
    if (client == null) throw StateError('Sign-in is not configured.');
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'rvastrovastu://reset-password',
    );
  }

  /// Sets a new password for the user who opened a reset link.
  Future<void> updatePassword(String newPassword) async {
    final client = _client;
    if (client == null) throw StateError('Sign-in is not configured.');
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Signs out and starts a fresh guest session so the app keeps working.
  Future<void> signOutToGuest() async {
    await signOut();
    await signInAnonymously();
  }

  /// Permanently deletes the signed-in account and its cloud data (the
  /// `delete_my_account` database function), then starts a fresh guest
  /// session. Store subscriptions are not cancelled by this.
  Future<void> deleteAccount() async {
    final client = _client;
    if (client == null) throw StateError('Accounts are not configured.');
    if (client.auth.currentUser == null) return;
    await client.rpc('delete_my_account');
    // The user no longer exists on the server, so only clear this device.
    await client.auth.signOut(scope: SignOutScope.local);
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

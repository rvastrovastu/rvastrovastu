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

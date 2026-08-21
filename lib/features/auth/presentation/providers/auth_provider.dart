import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(authServiceProvider);

  return service.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final service = ref.watch(authServiceProvider);

  return service.currentUser;
});

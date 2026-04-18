import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase_user_repository.dart';
import '../../domain/models/synq_user.dart';
import 'auth_provider.dart';

final userRepositoryProvider = Provider<SupabaseUserRepository>((ref) {
  return SupabaseUserRepository();
});

final userProvider = StreamProvider<SynqUser?>((ref) {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return Stream.value(null);
  }

  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    return Stream.value(null);
  }

  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.watchUser(uid).distinct();
});

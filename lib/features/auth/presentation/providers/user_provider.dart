import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/user_repository.dart';
import '../../domain/models/synq_user.dart';
import 'auth_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userProvider = StreamProvider<SynqUser?>((ref) {
  final authState = ref.watch(authProvider);
  
  if (!authState.isAuthenticated) {
    return Stream.value(null);
  }
  
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.watchUser(uid);
});

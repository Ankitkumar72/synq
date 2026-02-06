import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/main_shell.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FirebaseService.initialize();

    runApp(const ProviderScope(child: SynqApp()));
  } catch (e, stack) {
    debugPrint('ERROR_IN_MAIN: $e');
    debugPrint(stack.toString());
  }
}

class SynqApp extends ConsumerWidget {
  const SynqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Synq',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: authState.isLoading
          ? Scaffold(backgroundColor: AppColors.background, body: const Center(child: CircularProgressIndicator()))
          : authState.isAuthenticated
              ? MainShell()
              : const LoginScreen(),
    );
  }
}



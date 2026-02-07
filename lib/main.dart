import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/firebase_provider.dart';
import 'features/shell/presentation/main_shell.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  String? firebaseError;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FirebaseService.initialize();
    await NotificationService().init();
  } catch (e, stack) {
    debugPrint('ERROR_IN_MAIN: $e');
    debugPrint(stack.toString());
    firebaseError = e.toString();
  }

  runApp(ProviderScope(
    overrides: [
      if (firebaseError != null)
        firebaseErrorProvider.overrideWith((ref) => firebaseError),
    ],
    child: const SynqApp(),
  ));
}

class SynqApp extends ConsumerWidget {
  const SynqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final firebaseError = ref.watch(firebaseErrorProvider);

    return MaterialApp(
      title: 'Synq',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: firebaseError != null
          ? Scaffold(
              backgroundColor: AppColors.background,
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Initialization Failed',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        firebaseError,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : authState.isLoading
              ? Scaffold(backgroundColor: AppColors.background, body: const Center(child: CircularProgressIndicator()))
              : authState.isAuthenticated
                  ? MainShell()
                  : const LoginScreen(),
    );
  }
}



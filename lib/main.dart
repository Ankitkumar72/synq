import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/tasks/data/hive_task_repository.dart';
import 'features/tasks/domain/models/task.dart';
import 'features/shell/presentation/main_shell.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskAdapter());
  
  // Open box (optional here, but good for startup)
  await Hive.openBox<Task>(HiveTaskRepository.boxName);

  runApp(const ProviderScope(child: SynqApp()));
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
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : authState.isAuthenticated
              ? MainShell()
              : const LoginScreen(),
    );
  }
}



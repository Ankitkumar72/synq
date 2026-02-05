import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/tasks/data/hive_task_repository.dart';
import 'features/tasks/domain/models/task.dart';
import 'features/shell/presentation/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskAdapter());
  
  // Open box (optional here, but good for startup)
  await Hive.openBox<Task>(HiveTaskRepository.boxName);

  runApp(const ProviderScope(child: SynqApp()));
}

class SynqApp extends StatelessWidget {
  const SynqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synq',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: MainShell(),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/firebase_provider.dart';
import 'features/shell/presentation/main_shell.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:synq/core/widgets/responsive_wrapper.dart';
import 'package:synq/features/auth/presentation/providers/auth_provider.dart';
import 'package:synq/features/auth/presentation/screens/login_screen.dart';
import 'package:synq/features/sync/data/sync_access_provider.dart';
import 'package:synq/features/notes/data/notes_provider.dart';
import 'package:synq/features/tasks/data/tasks_provider.dart';
import 'package:synq/features/auth/presentation/widgets/device_enforcement_guard.dart';
import 'package:synq/features/auth/presentation/widgets/downgrade_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  String? firebaseError;
  try {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    await FirebaseService.initialize();

    // Enable offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    await NotificationService().init();

    // Enable edge-to-edge mode and set initial overlay style
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('ERROR_IN_MAIN: $e');
      debugPrint(stack.toString());
    } else {
      debugPrint('ERROR_IN_MAIN');
    }
    firebaseError = e.toString();
  }

  runApp(
    ProviderScope(
      overrides: [
        if (firebaseError != null)
          firebaseErrorProvider.overrideWith((ref) => firebaseError),
      ],
      child: const SynqApp(),
    ),
  );
}

class SynqApp extends ConsumerStatefulWidget {
  const SynqApp({super.key});

  @override
  ConsumerState<SynqApp> createState() => _SynqAppState();
}

class _SynqAppState extends ConsumerState<SynqApp> {
  bool _didRequestNotificationPermission = false;
  bool _isSplashAnimationComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didRequestNotificationPermission) {
        return;
      }
      _didRequestNotificationPermission = true;
      NotificationService().requestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final firebaseError = ref.watch(firebaseErrorProvider);
    final syncAccess = ref.watch(syncAccessProvider);
    final notesAsync = ref.watch(notesProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final requiresCloudAuth = syncAccess.cloudSyncEnabled;
    final canEnterApp = !requiresCloudAuth || authState.isAuthenticated;
    final shouldShowLoading =
        syncAccess.isLoading ||
        (requiresCloudAuth && authState.isLoading) ||
        notesAsync.isLoading ||
        tasksAsync.isLoading;

    return MaterialApp(
      title: 'Synq',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      builder: (context, child) {
        return ResponsiveWrapper(child: child ?? const SizedBox());
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: firebaseError != null
            ? Scaffold(
                key: const ValueKey('error'),
                backgroundColor: AppColors.background,
                body: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
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
            : (!_isSplashAnimationComplete || shouldShowLoading)
            ? SplashScreen(
                key: const ValueKey('splash'),
                onAnimationComplete: () {
                  if (mounted) {
                    setState(() => _isSplashAnimationComplete = true);
                  }
                },
              )
            : canEnterApp
            ? const DeviceEnforcementGuard(
                key: ValueKey('shell'),
                child: DowngradeHandler(child: MainShell()),
              )
            : const LoginScreen(key: ValueKey('login')),
      ),
    );
  }
}

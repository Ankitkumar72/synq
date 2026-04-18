import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/firebase_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/repository_provider.dart';
import 'features/shell/presentation/main_shell.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:synq/core/widgets/responsive_wrapper.dart';
import 'package:synq/features/auth/presentation/providers/auth_provider.dart';
import 'package:synq/features/auth/presentation/screens/login_screen.dart';
import 'package:synq/features/sync/data/sync_access_provider.dart';
import 'package:synq/features/auth/presentation/widgets/device_enforcement_guard.dart';
import 'package:synq/features/auth/presentation/widgets/downgrade_handler.dart';

void main() async {
  try {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Services in parallel to drastically improve startup time
    // and reduce jank on the main thread.
    await Future.wait([
      // Initialize Supabase (Fatal: App cannot run without this)
      SupabaseService.initialize(),
      
      // Initialize Firebase (Non-fatal: Silently log and continue if this fails)
      FirebaseService.initialize().catchError((e) {
        debugPrint('⚠️ Firebase Init Silent Failure: $e');
      }),
      
      // Initialize Notifications
      NotificationService().init(),
    ]);

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
  }

  runApp(
    const ProviderScope(
      child: SynqApp(),
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
      PermissionService().requestInitialPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final syncAccess = ref.watch(syncAccessProvider);
    ref.watch(appInitializationProvider); // Trigger background initializations
    final requiresCloudAuth = syncAccess.cloudSyncEnabled;
    final canEnterApp = !requiresCloudAuth || authState.isAuthenticated;
    final shouldShowLoading =
        syncAccess.isLoading ||
        (requiresCloudAuth && authState.isLoading);

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
        child: (!_isSplashAnimationComplete || shouldShowLoading)
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

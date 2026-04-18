import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../firebase_options.dart';


class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final recaptchaSiteKey = dotenv.get('RECAPTCHA_V3_SITE_KEY', fallback: '');
    if (kIsWeb && recaptchaSiteKey.isEmpty) {
      throw StateError(
        'Missing RECAPTCHA_V3_SITE_KEY for Firebase App Check on web.',
      );
    }


    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
      providerWeb: recaptchaSiteKey.isEmpty
          ? null
          : ReCaptchaV3Provider(recaptchaSiteKey),
    );

    if (kDebugMode) {
      try {
        final token = await FirebaseAppCheck.instance.getToken();
        debugPrint('--- APP CHECK DEBUG TOKEN ---');
        debugPrint(token);
        debugPrint('-----------------------------');
      } catch (e) {
        debugPrint('--- APP CHECK DEBUG TOKEN (ERROR) ---');
        debugPrint('Failed to get App Check token: $e');
        debugPrint('--------------------------------------');
      }
      
      final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      debugPrint('Firebase initialized for vitals (project: $projectId)');
    }

    // Initialize Crashlytics
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }
}

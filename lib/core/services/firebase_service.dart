import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');
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
      final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      debugPrint('Firebase initialized for project: $projectId');
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}

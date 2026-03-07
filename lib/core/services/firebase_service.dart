import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize App Check
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
      providerWeb: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
    
    // Debug log to verify project ID and details
    final options = DefaultFirebaseOptions.currentPlatform;
    if (kDebugMode) {
      debugPrint('🔥 Firebase Initialized!');
      debugPrint('🔥 Project ID: ${options.projectId}');
      debugPrint('🔥 App ID: ${options.appId}');
      debugPrint('🔥 API Key: ${options.apiKey.substring(0, 5)}...');
    }
    
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}

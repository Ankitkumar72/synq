import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
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

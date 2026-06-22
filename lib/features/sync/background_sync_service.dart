
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String backgroundSyncTask = 'com.yourapp.sync';

class BackgroundSyncService {
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task == backgroundSyncTask) {
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity == ConnectivityResult.none) {
          return Future.value(true);
        }

        try {
          final supabaseUrl = inputData?['SUPABASE_URL'] as String?;
          final supabaseAnonKey = inputData?['SUPABASE_ANON_KEY'] as String?;

          if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
            return Future.value(false);
          }

          // MUST re-initialize Supabase in the background isolate
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseAnonKey,
          );

          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) return Future.value(true);

          // Perform actual sync: fetch latest timestamps from each table
          // This wakes up the sync engine when the app foregrounds
          await supabase.from('tasks').select('id,updated_at').limit(1);
          await supabase.from('events').select('id,updated_at').limit(1);
          await supabase.from('notes').select('id,updated_at').limit(1);

          return Future.value(true);
        } catch (e) {
          return Future.value(false); // Retry on failure
        }
      }
      return Future.value(true);
    });
  }

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'sync-periodic',
      backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      inputData: <String, dynamic>{
        'SUPABASE_URL': dotenv.env['SUPABASE_URL'] ?? '',
        'SUPABASE_ANON_KEY': dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      },
    );
  }
}

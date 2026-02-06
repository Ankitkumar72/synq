import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the error message if Firebase initialization fails.
/// null means no error occurred.
final firebaseErrorProvider = StateProvider<String?>((ref) => null);

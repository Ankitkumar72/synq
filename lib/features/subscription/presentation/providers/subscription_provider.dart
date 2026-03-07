import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

class SubscriptionState {
  final bool isLoading;
  final String? error;
  
  const SubscriptionState({
    this.isLoading = false,
    this.error,
  });
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repository;
  
  SubscriptionNotifier(this._repository) : super(const SubscriptionState());

  Future<void> initiateUpgrade() async {
    state = const SubscriptionState(isLoading: true, error: null);
    try {
      await _repository.initiateUpgrade();
      // Keep loading state true even after returning from the external browser. 
      // The Firestore stream will eventually trigger and rebuild the UI organically
      // leaving a smooth "Pending Upgrade..." state.
    } catch (e) {
      state = SubscriptionState(isLoading: false, error: e.toString());
    }
  }
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return SubscriptionNotifier(repository);
});

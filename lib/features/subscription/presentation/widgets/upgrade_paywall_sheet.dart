import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';
import '../../../auth/domain/models/synq_user.dart';
import '../../../auth/presentation/providers/user_provider.dart';

class UpgradePaywallSheet extends ConsumerWidget {
  const UpgradePaywallSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionProvider);
    final userAsync = ref.watch(userProvider);
    
    final isPro = userAsync.valueOrNull?.planTier == PlanTier.pro;

    // Reacting to the organic upgrade
    if (isPro) {
      // Small delay to let the animation breathe
      Future.microtask(() {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Synq Pro! 🚀')),
          );
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.star, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'Upgrade to Pro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Unlock advanced features and sync seamlessly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          
          if (subState.error != null)
             Text(
              subState.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 16),
            
          ElevatedButton(
            onPressed: subState.isLoading ? null : () {
              ref.read(subscriptionProvider.notifier).initiateUpgrade();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: subState.isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Connecting to secure checkout...'),
                    ],
                  )
                : const Text('Upgrade Now - \$4.99/mo', style: TextStyle(fontSize: 16)),
          ),
          
          if (subState.isLoading)
             const Padding(
               padding: EdgeInsets.only(top: 16.0),
               child: Text(
                 'Activating your Pro account once payment succeeds...',
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
               ),
             ),
             
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

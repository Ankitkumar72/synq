import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/subscription_repository.dart';
import '../../../auth/domain/models/synq_user.dart';
import '../../../auth/presentation/providers/user_provider.dart';

final paddleServiceProvider = Provider<PaddleService>((ref) {
  return PaddleService();
});

class UpgradePaywallSheet extends ConsumerStatefulWidget {
  const UpgradePaywallSheet({super.key});

  @override
  ConsumerState<UpgradePaywallSheet> createState() => _UpgradePaywallSheetState();
}

class _UpgradePaywallSheetState extends ConsumerState<UpgradePaywallSheet> {
  bool _isLoading = false;
  String? _error;

  Future<void> _handleUpgrade() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(paddleServiceProvider).launchCheckout();
      // After returning from the browser, show a pending state.
      // The StreamProvider will auto-update when the webhook fires.
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final isPro = userAsync.valueOrNull?.planTier == PlanTier.pro;

    // Auto-dismiss when upgrade is detected via Firestore stream
    if (isPro) {
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

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleUpgrade,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Connecting to secure checkout...'),
                    ],
                  )
                : const Text('Upgrade Now', style: TextStyle(fontSize: 16)),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Text(
                'Processing your upgrade...',
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

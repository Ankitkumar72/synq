import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../auth/domain/models/synq_user.dart';
import '../../../auth/presentation/providers/user_provider.dart';

final paddleServiceProvider = Provider<PaddleService>((ref) {
  return PaddleService();
});

class UpgradePaywallSheet extends ConsumerStatefulWidget {
  const UpgradePaywallSheet({super.key});

  @override
  ConsumerState<UpgradePaywallSheet> createState() =>
      _UpgradePaywallSheetState();
}

class _UpgradePaywallSheetState extends ConsumerState<UpgradePaywallSheet> {
  bool _isLoading = false;
  String _selectedPlanSlug = 'yearly'; // Yearly by default

  Future<void> _handleUpgrade() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await ref.read(paddleServiceProvider).launchCheckout(_selectedPlanSlug);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Welcome to Synq Pro!')));
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.stars_rounded, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'Upgrade to Pro',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black, // Explicitly black
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Unlock advanced features and sync seamlessly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54), // Explicitly dark gray
          ),
          const SizedBox(height: 24),

          // Plan Selection
          _buildPlanOption(title: 'Monthly', price: '\$3.99', slug: 'monthly'),
          const SizedBox(height: 12),
          _buildPlanOption(
            title: 'Yearly',
            price: '\$24.99',
            subtitle: 'Best value — \$2.08/mo',
            slug: 'yearly',
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleUpgrade,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Connecting to secure checkout...'),
                    ],
                  )
                : const Text(
                    'Upgrade Now',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ), // Explicitly white on black button
                  ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Text(
                'Processing your upgrade...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ), // Explicitly dark
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String price,
    String? subtitle,
    required String slug,
  }) {
    final isSelected = _selectedPlanSlug == slug;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanSlug = slug),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.grey[50] : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.black : Colors.grey[400],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                      color: Colors.black, // Explicitly black
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black, // Explicitly black
              ),
            ),
          ],
        ),
      ),
    );
  }
}

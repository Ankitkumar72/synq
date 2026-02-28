import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        // Dummy Restore button temporarily removed for store compliance
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Header
              const Text(
                'Unlock Seamless Sync & Deep Focus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24, // Slightly smaller
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 40),
              
              const Spacer(),

              // Pricing Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'BEST VALUE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          '\$24.99',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          ' / Year',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(Just \$2.08 / month — less than a coffee!)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),

              // Features Comparison
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Free Plan
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FREE PLAN',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem('Local Only', isCheck: false),
                          _buildFeatureItem('1 Device', isCheck: false),
                          _buildFeatureItem('Basic Stats', isCheck: false),
                          _buildFeatureItem('Secure local storage & TLS sync', isCheck: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Synq Pro
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF0FF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SYNQ PRO',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem('Cloud Sync', isCheck: true),
                          _buildFeatureItem('Unlimited Devices', isCheck: true),
                          _buildFeatureItem('100MB Files', isCheck: true),
                          _buildFeatureItem('Deep Analytics', isCheck: true),
                          _buildFeatureItem('Secure local storage & TLS sync', isCheck: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 2),

              // Subscription CTA temporarily removed pending fully integrated payment processor

              // Footer Text
              Text(
                'Terms of Service • Privacy Policy • Recurring billing, cancel anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, {required bool isCheck}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCheck ? Icons.check : Icons.remove,
            size: 16,
            color: isCheck ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isCheck ? Colors.black : Colors.grey[600],
                fontWeight: isCheck ? FontWeight.w500 : FontWeight.normal,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> initiateUpgrade({String priceId = 'price_1PlaceholderHere'}) async {
    try {
      final callable = _functions.httpsCallable('createStripeCheckout');
      
      final response = await callable.call(<String, dynamic>{
        'priceId': priceId,
      });

      final String? urlString = response.data['url'] as String?;
      
      if (urlString != null) {
        final Uri url = Uri.parse(urlString);
        if (await canLaunchUrl(url)) {
          // Launch the stripe checkout page in an external browser for security
          // Apple/Google compliance often requires this over web views for external billing.
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch checkout URL');
        }
      } else {
        throw Exception('Invalid response from Stripe functions');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Functions Error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'An error occurred connecting to checkout.');
    } catch (e) {
      debugPrint('Upgrade Error: $e');
      throw Exception('Failed to initiate upgrade process.');
    }
  }
}

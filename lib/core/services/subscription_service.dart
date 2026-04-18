import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PaddleService {
  static String get _baseUrl {
    final envUrl = dotenv.get('API_BASE_URL', fallback: '');
    if (envUrl.isNotEmpty) return envUrl;

    if (kReleaseMode) {
      return 'https://synq-synq-paddle-webhook.hf.space';
    }

    // For local development on Android emulators
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  static const Set<String> _trustedCheckoutHosts = <String>{
    'checkout.paddle.com',
    'pay.paddle.com',
    'sandbox-checkout.paddle.com',
  };

  bool _isAllowedCheckoutUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return false;
    if (kReleaseMode && scheme != 'https') return false;

    final host = uri.host.toLowerCase();
    final baseHost = Uri.tryParse(_baseUrl)?.host.toLowerCase();
    if (baseHost != null && host == baseHost) {
      return !kReleaseMode || scheme == 'https';
    }

    if (_trustedCheckoutHosts.contains(host)) {
      return true;
    }

    if (!kReleaseMode &&
        (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2')) {
      return true;
    }

    return false;
  }

  /// for a specific [planSlug] (e.g. 'monthly', 'yearly'), then launches the checkout URL.
  Future<void> launchCheckout(String planSlug) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final token = Supabase.instance.client.auth.currentSession?.accessToken;

    final priceId = planSlug == 'monthly'
        ? dotenv.get('PADDLE_MONTHLY_PRICE_ID')
        : dotenv.get('PADDLE_YEARLY_PRICE_ID');

    final response = await http.post(
      Uri.parse('$_baseUrl/create-checkout'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'plan_slug': planSlug,
        'price_id': priceId,
      }),
    );


    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('--- CHECKOUT FAILED ---');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('Body: ${response.body}');
        debugPrint('-----------------------');
      }
      throw Exception('Failed to create checkout session: ${response.statusCode}');
    }


    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid checkout response from server.');
    }

    final urlString = data['checkout_url'];
    if (urlString is! String || urlString.isEmpty) {
      throw Exception('Invalid checkout response from server.');
    }

    var fixedUrlString = urlString;
    if (urlString.contains('localhost') && !_baseUrl.contains('localhost')) {
      fixedUrlString = urlString
          .replaceFirst('https://localhost/', '$_baseUrl/paddle-checkout?')
          .replaceFirst('http://localhost/', '$_baseUrl/paddle-checkout?');
    }

    final checkoutUrl = Uri.tryParse(fixedUrlString);
    if (checkoutUrl == null || !_isAllowedCheckoutUri(checkoutUrl)) {
      throw Exception('Received an unsafe checkout URL.');
    }

    final launched = await launchUrl(
      checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not launch checkout URL.');
    }
  }
}

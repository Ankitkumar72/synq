import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PaddleService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode
        ? 'https://synq-synq-paddle-webhook.hf.space'
        : 'http://localhost:8000',
  );

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final token = await user.getIdToken(true);

    final response = await http.post(
      Uri.parse('$_baseUrl/create-checkout'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'plan_slug': planSlug}),
    );

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          'Checkout request failed with status ${response.statusCode}',
        );
      }
      throw Exception('Failed to create checkout session.');
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

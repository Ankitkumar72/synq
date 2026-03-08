import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class PaddleService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000', // Need to pass --dart-define for physical devices
  );

  /// Calls the FastAPI backend to create a Paddle checkout session,
  /// then launches the checkout URL in an external browser.
  Future<void> launchCheckout() async {
    // 1. Get a fresh Firebase ID token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final token = await user.getIdToken(true); // true = force refresh

    // 2. Call FastAPI to create checkout
    final response = await http.post(
      Uri.parse('$_baseUrl/create-checkout'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      debugPrint('Checkout error: ${response.body}');
      throw Exception('Failed to create checkout session.');
    }

    // 3. Parse URL and launch in external browser
    final data = jsonDecode(response.body);
    final String? urlString = data['checkout_url'] as String?;

    if (urlString == null) {
      throw Exception('Invalid checkout response from server.');
    }

    String fixedUrlString = urlString;
    // Replace default localhost with the local IP for testing, only in debug mode
    if (kDebugMode && _baseUrl.startsWith('http://')) {
      fixedUrlString = urlString.replaceFirst(
        'https://localhost/', 
        '$_baseUrl/paddle-checkout?', 
      ).replaceFirst('http://localhost/', '$_baseUrl/paddle-checkout?');
    }

    final checkoutUrl = Uri.parse(fixedUrlString);
    if (await canLaunchUrl(checkoutUrl)) {
      await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch checkout URL.');
    }
  }
}

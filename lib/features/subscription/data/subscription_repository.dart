import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class PaddleService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode 
      ? 'https://synq-synq-paddle-webhook.hf.space' 
      : 'http://localhost:8000',
  );




  
  /// for a specific [planSlug] (e.g. 'monthly', 'yearly'), then launches the checkout URL.
  Future<void> launchCheckout(String planSlug) async {
    // 1. Get a fresh Firebase ID token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final token = await user.getIdToken(true); // true = force refresh

    // 2. Call FastAPI to create checkout
    final response = await http.post(
      Uri.parse('$_baseUrl/create-checkout'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'plan_slug': planSlug}),
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
    
    if (urlString.contains('localhost') && !_baseUrl.contains('localhost')) {
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

// lib/core/services/api_service.dart
// HTTP service — all REST calls go through here.
// Flutter ↔ Node.js backend ONLY. No direct Supabase calls.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../../features/sales/models/dropdown_options_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(AppConstants.connectTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection or server unreachable.');
    } on TimeoutException {
      throw ApiException('Request timed out. Check your network connection.');
    }
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(AppConstants.connectTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection or server unreachable.');
    } on TimeoutException {
      throw ApiException('Request timed out. Check your network connection.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded['error'] as String? ?? 'Unknown server error';
    throw ApiException(message, statusCode: response.statusCode);
  }

  // ─────────────────────────────────────────────
  // Public API methods
  // ─────────────────────────────────────────────

  /// Fetches all dropdown option lists (items, threads, lengths, heads, colours).
  Future<DropdownOptionsModel> fetchDropdownOptions() async {
    final response = await _get('/items/all');
    return DropdownOptionsModel.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Fetches the customer list from Customer_Master.
  /// Returns [{ id, name, alias }] — alias is used as the Party value.
  Future<List<CustomerOption>> fetchCustomers() async {
    final response = await _get('/customers');
    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => CustomerOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Posts a new sales transaction to the backend.
  /// Payload: { item_name, thread, length, head, colour,
  ///            party, date, quantity, uom, rate, mode, receipt?, location? }
  Future<Map<String, dynamic>> createTransaction(
      Map<String, dynamic> payload) async {
    final response = await _post('/transactions', payload);
    return response['data'] as Map<String, dynamic>;
  }
}

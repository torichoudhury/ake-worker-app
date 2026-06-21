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
        'Bypass-Tunnel-Reminder': 'true',
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

    String message = decoded['error'] as String? ?? 'Unknown server error';
    
    if (decoded['details'] != null && decoded['details'] is List && (decoded['details'] as List).isNotEmpty) {
      final details = decoded['details'] as List;
      final firstDetail = details.first as Map<String, dynamic>;
      if (firstDetail['msg'] != null) {
        message = '$message: ${firstDetail['msg']}';
        if (firstDetail['path'] != null) {
           message = '$message (Field: ${firstDetail['path']})';
        }
      }
    }

    throw ApiException(message, statusCode: response.statusCode);
  }

  // ─────────────────────────────────────────────
  // Public API methods
  // ─────────────────────────────────────────────

  /// Fetches all dropdown option lists (items, threads, lengths, heads, colours).
  Future<DropdownOptionsModel> fetchDropdownOptions({
    String? itemName,
    String? thread,
    String? length,
    String? head,
  }) async {
    final params = <String>[];
    if (itemName != null) params.add('name=${Uri.encodeQueryComponent(itemName)}');
    if (thread != null) params.add('thread=${Uri.encodeQueryComponent(thread)}');
    if (length != null) params.add('length=${Uri.encodeQueryComponent(length)}');
    if (head != null) params.add('head=${Uri.encodeQueryComponent(head)}');

    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _get('/items/all$query');
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

  // Movement API
  Future<Map<String, dynamic>> createMovement(Map<String, dynamic> payload) async {
    final response = await _post('/movement', payload);
    return response['data'] as Map<String, dynamic>;
  }

  // Dues / Treasury
  // ─────────────────────────────────────────────
  Future<List<dynamic>> fetchDues({String? name, String? phone}) async {
    final queryParams = <String, String>{};
    if (name != null && name.isNotEmpty) queryParams['name'] = name;
    if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;

    final queryStr = Uri(queryParameters: queryParams).query;
    final path = '/dues${queryStr.isNotEmpty ? '?$queryStr' : ''}';
    final response = await _get(path);
    return response['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> settleDue(int transactionId, double balanceSettled, {String? date}) async {
    final Map<String, dynamic> body = {
      'transaction_id': transactionId,
      'balance_settled': balanceSettled,
    };
    if (date != null) {
      body['date'] = date;
    }
    final response = await _post('/dues/settle', body);
    return response['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchDueHistory(int transactionId) async {
    final response = await _get('/dues/$transactionId/history');
    return response['data'] as List<dynamic>;
  }

  // Contacts API
  Future<Map<String, dynamic>> createContact(Map<String, dynamic> payload) async {
    final response = await _post('/contacts', payload);
    return response['data'] as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────
  // Item Weight / UoM API
  // ─────────────────────────────────────────────

  /// POST /api/item-weight-uom/entry
  /// Saves a new dated weight + rate entry for an item+uom.
  Future<void> saveItemWeightEntry(Map<String, dynamic> payload) async {
    await _post('/item-weight-uom/entry', payload);
  }

  /// GET /api/item-weight-uom/enquiry
  /// Returns avg weight + suggested sale rates for a given item+uom+customer.
  Future<Map<String, dynamic>> fetchItemEnquiry({
    required String itemIdUom,
    required String uom,
    String? customer,
    // Individual item fields so backend can resolve item_master.id reliably
    String? itemName,
    String? thread,
    String? length,
    String? head,
    String? colour,
  }) async {
    final params = [
      'item_id_uom=${Uri.encodeQueryComponent(itemIdUom)}',
      'uom=${Uri.encodeQueryComponent(uom)}',
      if (customer != null && customer.isNotEmpty)
        'customer=${Uri.encodeQueryComponent(customer)}',
      if (itemName != null) 'name=${Uri.encodeQueryComponent(itemName)}',
      if (thread != null)   'thread=${Uri.encodeQueryComponent(thread)}',
      if (length != null)   'length=${Uri.encodeQueryComponent(length)}',
      if (head != null)     'head=${Uri.encodeQueryComponent(head)}',
      if (colour != null)   'colour=${Uri.encodeQueryComponent(colour)}',
    ];
    final response = await _get('/item-weight-uom/enquiry?${params.join('&')}');
    return response['data'] as Map<String, dynamic>;
  }

  /// GET /api/item-weight-uom/entries
  /// Returns combined entries from item_weight_uom_log AND sale_transaction.
  /// Response shape: { manual_entries: [...], sale_transactions: [...] }
  Future<Map<String, dynamic>> fetchItemWeightEntries({
    required String itemIdUom,
    String? uom,
    // Individual item fields so backend can resolve item_master.id reliably
    String? itemName,
    String? thread,
    String? length,
    String? head,
    String? colour,
  }) async {
    final params = [
      'item_id_uom=${Uri.encodeQueryComponent(itemIdUom)}',
      if (uom != null)      'uom=${Uri.encodeQueryComponent(uom)}',
      if (itemName != null) 'name=${Uri.encodeQueryComponent(itemName)}',
      if (thread != null)   'thread=${Uri.encodeQueryComponent(thread)}',
      if (length != null)   'length=${Uri.encodeQueryComponent(length)}',
      if (head != null)     'head=${Uri.encodeQueryComponent(head)}',
      if (colour != null)   'colour=${Uri.encodeQueryComponent(colour)}',
    ];
    final response = await _get('/item-weight-uom/entries?${params.join('&')}');
    return response['data'] as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────
  // Authentication API Methods
  // ─────────────────────────────────────────────

  /// GET /api/auth/check-alias?alias=...
  /// Checks if a worker alias exists in user_login with role=worker.
  Future<bool> checkWorkerAlias(String alias) async {
    final response = await _get('/auth/check-alias?alias=${Uri.encodeQueryComponent(alias)}');
    return response['exists'] as bool? ?? false;
  }

  /// POST /api/auth/login
  /// Verifies credentials and returns user details.
  Future<Map<String, dynamic>> loginWorker(String alias, String pin) async {
    final response = await _post('/auth/login', {
      'alias': alias,
      'pin': pin,
    });
    return response;
  }
}


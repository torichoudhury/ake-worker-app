import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../sales/models/dropdown_options_model.dart';

class DueBillsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _error = '';
  List<dynamic> _dueBills = [];

  bool get isLoading => _isLoading;
  String get error => _error;
  List<dynamic> get dueBills => _dueBills;

  List<CustomerOption> _customers = [];
  CustomerOption? _selectedCustomer;
  String _searchPhone = '';

  List<CustomerOption> get customers => _customers;
  CustomerOption? get selectedCustomer => _selectedCustomer;

  void setSelectedCustomer(CustomerOption? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setSearchPhone(String phone) {
    _searchPhone = phone;
  }

  Future<void> loadCustomers() async {
    try {
      _customers = await ApiService.instance.fetchCustomers();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load customers: $e';
      notifyListeners();
    }
  }

  Future<void> search() async {
    final searchName = _selectedCustomer?.alias ?? '';
    
    if (searchName.isEmpty && _searchPhone.isEmpty) {
      _error = 'Please enter a name or phone number to search';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = '';
    _dueBills = [];
    notifyListeners();

    try {
      final searchName = _selectedCustomer?.alias ?? '';
      _dueBills = await ApiService.instance.fetchDues(
        name: searchName,
        phone: _searchPhone,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> settle(int transactionId, double amount, {String? date}) async {
    try {
      await ApiService.instance.settleDue(transactionId, amount, date: date);
      // Refresh list after successful settlement
      await search();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>> fetchHistory(int transactionId) async {
    try {
      return await ApiService.instance.fetchDueHistory(transactionId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
}

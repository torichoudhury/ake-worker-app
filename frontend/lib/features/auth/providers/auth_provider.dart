// lib/features/auth/providers/auth_provider.dart
// State management for Landing Authorization (Login Screen)

import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isAliasVerified = false;
  String _errorMessage = '';
  String _workerAlias = '';
  String? _loggedInUser;

  bool get isLoading => _isLoading;
  bool get isAliasVerified => _isAliasVerified;
  String get errorMessage => _errorMessage;
  String get workerAlias => _workerAlias;
  bool get isAuthenticated => _loggedInUser != null;
  String? get loggedInUser => _loggedInUser;

  /// Verifies if the worker alias exists and has worker role
  Future<bool> verifyAlias(String alias) async {
    if (alias.trim().isEmpty) {
      _errorMessage = 'Worker alias cannot be empty';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final exists = await ApiService.instance.checkWorkerAlias(alias.trim());
      if (exists) {
        _isAliasVerified = true;
        _workerAlias = alias.trim();
        _errorMessage = '';
        return true;
      } else {
        _isAliasVerified = false;
        _errorMessage = 'Worker alias not found or unauthorized';
        return false;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to connect to authentication service';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifies PIN against the user_login table
  Future<bool> login(String pin) async {
    if (pin.trim().isEmpty) {
      _errorMessage = 'PIN cannot be empty';
      notifyListeners();
      return false;
    }

    if (!_isAliasVerified) {
      _errorMessage = 'Please verify your worker alias first';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.instance.loginWorker(_workerAlias, pin.trim());
      if (response['success'] == true) {
        _loggedInUser = _workerAlias;
        _errorMessage = '';
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Authentication failed';
        return false;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resets the alias verification step
  void resetAlias() {
    _isAliasVerified = false;
    _workerAlias = '';
    _errorMessage = '';
    notifyListeners();
  }

  /// Logs out the user
  void logout() {
    _loggedInUser = null;
    resetAlias();
  }
}

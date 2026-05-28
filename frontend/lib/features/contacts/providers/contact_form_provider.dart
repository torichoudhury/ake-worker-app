import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class ContactFormProvider extends ChangeNotifier {
  String _type = 'customer'; // default
  String _alias = '';
  String _name = '';
  String _address = '';
  String _gst = '';
  String _whatsapp = '';
  String _phone = '';
  String _email = '';

  bool _isSubmitting = false;
  String _submitError = '';

  String get type => _type;
  String get alias => _alias;
  String get name => _name;
  String get address => _address;
  String get gst => _gst;
  String get whatsapp => _whatsapp;
  String get phone => _phone;
  String get email => _email;

  bool get isSubmitting => _isSubmitting;
  String get submitError => _submitError;

  void setType(String v) { _type = v; notifyListeners(); }
  void setAlias(String v) { _alias = v; notifyListeners(); }
  void setName(String v) { _name = v; notifyListeners(); }
  void setAddress(String v) { _address = v; notifyListeners(); }
  void setGst(String v) { _gst = v; notifyListeners(); }
  void setWhatsapp(String v) { _whatsapp = v; notifyListeners(); }
  void setPhone(String v) { _phone = v; notifyListeners(); }
  void setEmail(String v) { _email = v; notifyListeners(); }

  Future<bool> submit() async {
    _submitError = '';
    
    if (_alias.isEmpty || _name.isEmpty) {
      _submitError = 'Alias and Name are required.';
      notifyListeners();
      return false;
    }

    if (_whatsapp.isEmpty && _phone.isEmpty) {
      _submitError = 'Either WhatsApp or Phone number is required.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      List<String> phoneList = [];
      if (_phone.isNotEmpty) {
        // Allow user to enter multiple numbers separated by comma
        phoneList = _phone.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      final payload = {
        'type': _type,
        'alias': _alias,
        'name': _name,
        'address': _address.isEmpty ? null : _address,
        'gst': _gst.isEmpty ? null : _gst,
        'whatsapp': _whatsapp.isEmpty ? null : _whatsapp,
        'phone': phoneList.isEmpty ? null : phoneList,
        'email': _email.isEmpty ? null : _email,
      };

      await ApiService.instance.createContact(payload);
      return true;
    } on ApiException catch (e) {
      _submitError = e.message;
      return false;
    } catch (e) {
      _submitError = 'An unexpected error occurred.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void resetForm() {
    _type = 'customer';
    _alias = '';
    _name = '';
    _address = '';
    _gst = '';
    _whatsapp = '';
    _phone = '';
    _email = '';
    _submitError = '';
    notifyListeners();
  }
}

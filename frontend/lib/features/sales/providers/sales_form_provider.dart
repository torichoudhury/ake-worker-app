// lib/features/sales/providers/sales_form_provider.dart
// State management for the Sales Transaction form using ChangeNotifier

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../models/dropdown_options_model.dart';

enum FormLoadState { idle, loading, loaded, error }

enum SubmitState { idle, submitting, success, error }

class SalesFormProvider extends ChangeNotifier {
  // ─── Item dropdown data ──────────────────────
  DropdownOptionsModel _options = DropdownOptionsModel.empty();
  FormLoadState _loadState = FormLoadState.idle;
  String _loadError = '';

  // ─── Customer list ──────────────────────────
  List<CustomerOption> _customers = [];

  // ─── Item selections (combo → resolves Item_Id) ─
  LookupOption? _selectedItem;
  LookupOption? _selectedThread;
  LookupOption? _selectedLength;
  LookupOption? _selectedHead;
  LookupOption? _selectedColour;

  // ─── Party selection ─────────────────────────
  CustomerOption? _selectedParty;

  // ─── Transaction fields ──────────────────────
  String? _selectedUom;
  String? _selectedMode;
  String? _selectedLocation;
  String? _receipt;

  // ─── Computed amount ─────────────────────────
  double _quantity = 0;
  double _rate     = 0;

  // ─── Date — auto-set from device clock ──────
  /// Stored as "dd MMM yyyy" for display; sent as "yyyy-MM-dd" to backend
  final String _dateDisplay =
      DateFormat('dd MMM yyyy').format(DateTime.now());
  final String _dateForBackend =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ─── Submit state ────────────────────────────
  SubmitState _submitState = SubmitState.idle;
  String _submitError = '';

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  DropdownOptionsModel get options    => _options;
  FormLoadState get loadState         => _loadState;
  String get loadError                => _loadError;
  SubmitState get submitState         => _submitState;
  String get submitError              => _submitError;

  List<CustomerOption> get customers  => _customers;

  LookupOption? get selectedItem      => _selectedItem;
  LookupOption? get selectedThread    => _selectedThread;
  LookupOption? get selectedLength    => _selectedLength;
  LookupOption? get selectedHead      => _selectedHead;
  LookupOption? get selectedColour    => _selectedColour;
  CustomerOption? get selectedParty   => _selectedParty;
  String? get selectedUom             => _selectedUom;
  String? get selectedMode            => _selectedMode;
  String? get selectedLocation        => _selectedLocation;
  String? get receipt                 => _receipt;

  /// Date shown in the read-only field (e.g. "27 May 2026")
  String get dateDisplay              => _dateDisplay;

  /// Amount auto-calculated from quantity × rate
  double get amount => _quantity * _rate;

  // ─────────────────────────────────────────────
  // Setters
  // ─────────────────────────────────────────────

  void setItem(LookupOption? v)      { _selectedItem   = v; notifyListeners(); }
  void setThread(LookupOption? v)    { _selectedThread  = v; notifyListeners(); }
  void setLength(LookupOption? v)    { _selectedLength  = v; notifyListeners(); }
  void setHead(LookupOption? v)      { _selectedHead    = v; notifyListeners(); }
  void setColour(LookupOption? v)    { _selectedColour  = v; notifyListeners(); }
  void setParty(CustomerOption? v)   { _selectedParty   = v; notifyListeners(); }
  void setUom(String? v)             { _selectedUom      = v; notifyListeners(); }
  void setMode(String? v)            { _selectedMode     = v; notifyListeners(); }
  void setLocation(String? v)        { _selectedLocation = v; notifyListeners(); }
  void setReceipt(String v)          { _receipt = v.trim().isEmpty ? null : v.trim(); notifyListeners(); }

  void setQuantity(String v) {
    _quantity = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  void setRate(String v) {
    _rate = double.tryParse(v) ?? 0;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Load dropdown options + customer list from API
  // ─────────────────────────────────────────────

  Future<void> loadOptions() async {
    if (_loadState == FormLoadState.loading) return;

    _loadState = FormLoadState.loading;
    _loadError = '';
    notifyListeners();

    try {
      // Fetch item dropdowns and customer list in parallel
      final results = await Future.wait([
        ApiService.instance.fetchDropdownOptions(),
        ApiService.instance.fetchCustomers(),
      ]);

      _options   = results[0] as DropdownOptionsModel;
      _customers = results[1] as List<CustomerOption>;
      _loadState = FormLoadState.loaded;
    } on ApiException catch (e) {
      _loadState = FormLoadState.error;
      _loadError = e.message;
    } catch (e) {
      _loadState = FormLoadState.error;
      _loadError = 'Unexpected error: $e';
    } finally {
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Submit transaction
  // ─────────────────────────────────────────────

  Future<bool> submit({
    required String quantity,
    required String rate,
  }) async {
    _submitState = SubmitState.submitting;
    _submitError = '';
    notifyListeners();

    try {
      await ApiService.instance.createTransaction({
        // Item combination — backend resolves Item_Id from Item_Master
        'item_name': _selectedItem!.label,
        'thread':    _selectedThread!.label,
        'length':    _selectedLength!.label,
        'head':      _selectedHead!.label,
        'colour':    _selectedColour!.label,

        // Party: the alias value stored in Sale_Transaction.Party
        'party': _selectedParty!.alias,

        // Date: set on the device (system date)
        'date': _dateForBackend,

        // Transaction fields
        'quantity': double.parse(quantity),
        'uom':      _selectedUom,
        'rate':     double.parse(rate),
        'mode':     _selectedMode,
        'amount':   double.parse(quantity) * double.parse(rate),

        // Optional
        'receipt':  _receipt,
        'location': _selectedLocation,
      });

      _submitState = SubmitState.success;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _submitState = SubmitState.error;
      _submitError = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _submitState = SubmitState.error;
      _submitError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Reset form
  // ─────────────────────────────────────────────

  void resetForm() {
    _selectedItem    = null;
    _selectedThread  = null;
    _selectedLength  = null;
    _selectedHead    = null;
    _selectedColour  = null;
    _selectedParty   = null;
    _selectedUom     = null;
    _selectedMode    = null;
    _selectedLocation = null;
    _receipt         = null;
    _quantity        = 0;
    _rate            = 0;
    _submitState     = SubmitState.idle;
    _submitError     = '';
    notifyListeners();
  }
}

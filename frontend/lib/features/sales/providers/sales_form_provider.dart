import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../models/dropdown_options_model.dart';
import '../models/cart_item_model.dart';

enum FormLoadState { idle, loading, loaded, error }

class SalesFormProvider extends ChangeNotifier {
  FormLoadState _loadState = FormLoadState.idle;
  String _loadError = '';

  FormLoadState get loadState => _loadState;
  String get loadError => _loadError;

  // ─────────────────────────────────────────────
  // Data
  // ─────────────────────────────────────────────
  DropdownOptionsModel _options = DropdownOptionsModel.empty();
  List<CustomerOption> _customers = [];

  List<LookupOption> get items => _options.items;
  List<LookupOption> get threads => _options.threads;
  List<LookupOption> get lengths => _options.lengths;
  List<LookupOption> get heads => _options.heads;
  List<LookupOption> get colours => _options.colours;
  List<CustomerOption> get customers => _customers;

  // ─────────────────────────────────────────────
  // Selection State (General Info & Item Form)
  // ─────────────────────────────────────────────
  
  // General Info
  String? _selectedLocation;
  CustomerOption? _selectedParty;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  int? _lastTransactionId;

  // Current Item Form
  LookupOption? _selectedItem;
  LookupOption? _selectedThread;
  LookupOption? _selectedLength;
  LookupOption? _selectedHead;
  LookupOption? _selectedColour;
  String? _selectedUom;
  String? _selectedMode;

  // Suggested rate fetched from item_weight_uom enquiry
  double? _suggestedRate;
  bool _isFetchingRate = false;

  // ─────────────────────────────────────────────
  // Cart & Transaction State
  // ─────────────────────────────────────────────
  final List<CartItem> _cart = [];
  double _gst = 0.0;
  double _cartage = 0.0;
  double _receipt = 0.0;

  bool _isSubmitting = false;
  String _submitError = '';

  // Getters
  String? get selectedLocation => _selectedLocation;
  CustomerOption? get selectedParty => _selectedParty;
  String get selectedDate => _selectedDate;
  int? get lastTransactionId => _lastTransactionId;

  LookupOption? get selectedItem   => _selectedItem;
  LookupOption? get selectedThread => _selectedThread;
  LookupOption? get selectedLength => _selectedLength;
  LookupOption? get selectedHead   => _selectedHead;
  LookupOption? get selectedColour => _selectedColour;
  String? get selectedUom  => _selectedUom;
  String? get selectedMode => _selectedMode;

  double? get suggestedRate    => _suggestedRate;
  bool    get isFetchingRate   => _isFetchingRate;

  List<CartItem> get cart => _cart;
  double get gst => _gst;
  double get cartage => _cartage;
  double get receipt => _receipt;

  bool get isSubmitting => _isSubmitting;
  String get submitError => _submitError;

  // Computed Totals
  double get totalItemsAmount => _cart.fold(0.0, (sum, item) => sum + item.amount);
  double get gstAmount => totalItemsAmount * (_gst / 100);
  double get grandTotal => totalItemsAmount + gstAmount + _cartage;
  double get remaining => grandTotal - _receipt;

  // Setters
  void setLocation(String? v) { _selectedLocation = v; notifyListeners(); }
  void setParty(CustomerOption? v) {
    _selectedParty = v;
    _suggestedRate = null;
    notifyListeners();
    _tryFetchSuggestedRate();
  }
  void setDate(String v) { _selectedDate = v; notifyListeners(); }

  void setItem(LookupOption? v) {
    _selectedItem   = v;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead   = null;
    _selectedColour = null;
    _suggestedRate  = null;
    notifyListeners();

    _fetchFilteredOptions();
  }

  Future<void> _fetchFilteredOptions() async {
    try {
      final newOptions = await ApiService.instance.fetchDropdownOptions(
        itemName: _selectedItem?.label,
        thread: _selectedThread?.label,
        length: _selectedLength?.label,
        head: _selectedHead?.label,
      );
      _options = _options.copyWith(
        threads: newOptions.threads,
        lengths: newOptions.lengths,
        heads: newOptions.heads,
        colours: newOptions.colours,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch filtered options: $e');
    }
  }

  void setThread(LookupOption? v) { 
    _selectedThread = v; 
    _selectedLength = null;
    _selectedHead = null;
    _selectedColour = null;
    notifyListeners(); 
    _fetchFilteredOptions();
  }
  
  void setLength(LookupOption? v) { 
    _selectedLength = v; 
    _selectedHead = null;
    _selectedColour = null;
    notifyListeners(); 
    _fetchFilteredOptions();
  }
  
  void setHead(LookupOption? v) { 
    _selectedHead = v; 
    _selectedColour = null;
    notifyListeners(); 
    _fetchFilteredOptions();
  }
  
  void setColour(LookupOption? v) { 
    _selectedColour = v;
    _suggestedRate = null;
    notifyListeners();
    _tryFetchSuggestedRate();
  }
  void setUom(String? v) {
    _selectedUom = v;
    _suggestedRate = null;
    notifyListeners();
    _tryFetchSuggestedRate();
  }
  void setMode(String? v) { _selectedMode = v; notifyListeners(); }

  void setGst(String text) {
    _gst = double.tryParse(text) ?? 0.0;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Suggested Rate (from item_weight_uom)
  // ─────────────────────────────────────────────

  /// Called whenever item selection or UoM changes.
  /// Builds the composite item_id_uom and calls the enquiry API.
  Future<void> _tryFetchSuggestedRate() async {
    if (_selectedItem == null || _selectedThread == null ||
        _selectedLength == null || _selectedHead == null ||
        _selectedColour == null || _selectedUom == null) {
      _suggestedRate = null;
      notifyListeners();
      return;
    }

    final itemIdUom = '${_selectedItem!.label}_${_selectedThread!.label}_'
        '${_selectedLength!.label}_${_selectedHead!.label}_${_selectedColour!.label}';

    // Use the selected party alias for customer-specific rate (cash if not selected)
    final customerAlias = _selectedParty?.alias;

    _isFetchingRate = true;
    notifyListeners();

    try {
      final data = await ApiService.instance.fetchItemEnquiry(
        itemIdUom: itemIdUom,
        uom:       _selectedUom!,
        customer:  customerAlias,
      );
      final raw = data['suggested_rate'];
      _suggestedRate = raw != null ? double.tryParse(raw.toString()) : null;
    } catch (e) {
      debugPrint('Rate suggestion fetch failed: $e');
      _suggestedRate = null;
    } finally {
      _isFetchingRate = false;
      notifyListeners();
    }
  }

  void setCartage(String text) {
    _cartage = double.tryParse(text) ?? 0.0;
    notifyListeners();
  }

  void setReceipt(String text) {
    _receipt = double.tryParse(text) ?? 0.0;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Cart Methods
  // ─────────────────────────────────────────────
  void addToCart(double quantity, double rate) {
    if (_selectedItem == null || _selectedThread == null || _selectedLength == null ||
        _selectedHead == null || _selectedColour == null || _selectedUom == null) {
      return;
    }

    _cart.add(CartItem(
      item: _selectedItem!,
      thread: _selectedThread!,
      length: _selectedLength!,
      head: _selectedHead!,
      colour: _selectedColour!,
      quantity: quantity,
      uom: _selectedUom!,
      rate: rate,
    ));

    // Reset item form fields (keep UoM as it might be reused)
    _selectedItem = null;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead = null;
    _selectedColour = null;
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Load data
  // ─────────────────────────────────────────────

  Future<void> loadOptions() async {
    if (_loadState == FormLoadState.loading) return;

    _loadState = FormLoadState.loading;
    _loadError = '';
    notifyListeners();

    try {
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

  Future<bool> submit() async {
    if (_cart.isEmpty) {
      _submitError = 'Cart is empty.';
      return false;
    }
    if (_selectedLocation == null || _selectedParty == null || _selectedMode == null) {
      _submitError = 'Missing general transaction info (Location, Party, or Mode).';
      return false;
    }

    _isSubmitting = true;
    _submitError = '';
    notifyListeners();

    try {
      final payload = {
        'party': _selectedParty!.alias,
        'date': _selectedDate,
        'mode': _selectedMode,
        'location': _selectedLocation,
        'receipt': _receipt,
        'grand_total': grandTotal,
        'remaining': remaining,
        'items': _cart.map((cartItem) => {
          'item_name': cartItem.item.label,
          'thread':    cartItem.thread.label,
          'length':    cartItem.length.label,
          'head':      cartItem.head.label,
          'colour':    cartItem.colour.label,
          'quantity':  cartItem.quantity,
          'uom':       cartItem.uom,
          'rate':      cartItem.rate,
        }).toList(),
      };

      final responseData = await ApiService.instance.createTransaction(payload);
      _lastTransactionId = responseData['transaction_id'] as int?;
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
    _selectedLocation = null;
    _selectedParty    = null;
    _selectedItem     = null;
    _selectedThread   = null;
    _selectedLength   = null;
    _selectedHead     = null;
    _selectedColour   = null;
    _selectedUom      = null;
    _selectedMode     = null;
    _suggestedRate    = null;
    _cart.clear();
    _gst = 0.0;
    _cartage = 0.0;
    _receipt = 0.0;
    _submitError = '';
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    notifyListeners();
  }
}

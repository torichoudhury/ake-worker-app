// lib/features/item_weight_uom/providers/item_weight_uom_provider.dart
// State management for Item Weight/UoM Screen (Record Entry tab + Enquiry tab).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../sales/models/dropdown_options_model.dart';
import '../models/item_weight_uom_model.dart';

enum ItemWeightLoadState { idle, loading, loaded, error }

// ─────────────────────────────────────────────
// UoM → quantity_per_uom map (mirrors backend)
// ─────────────────────────────────────────────
const Map<String, double?> kUomQtyMap = {
  'Pcs':   1,
  '%':     100,
  'Gross': 144,
  'KG':    null,
  'Bag':   null,
  'Box':   null,
};

class ItemWeightUomProvider extends ChangeNotifier {
  ItemWeightUomProvider() {
    _loadBaseOptions();
  }

  // ─────────────────────────────────────────────
  // Base data (items dropdown options + customers)
  // ─────────────────────────────────────────────
  ItemWeightLoadState _loadState = ItemWeightLoadState.idle;
  String _loadError = '';
  DropdownOptionsModel _options = DropdownOptionsModel.empty();
  List<CustomerOption> _customers = [];

  ItemWeightLoadState get loadState => _loadState;
  String get loadError => _loadError;
  List<LookupOption> get items   => _options.items;
  List<LookupOption> get threads => _options.threads;
  List<LookupOption> get lengths => _options.lengths;
  List<LookupOption> get heads   => _options.heads;
  List<LookupOption> get colours => _options.colours;
  List<CustomerOption> get customers => _customers;

  // ─────────────────────────────────────────────
  // Shared item selector state
  // ─────────────────────────────────────────────
  LookupOption? _selectedItem;
  LookupOption? _selectedThread;
  LookupOption? _selectedLength;
  LookupOption? _selectedHead;
  LookupOption? _selectedColour;
  String? _selectedUom;

  LookupOption? get selectedItem   => _selectedItem;
  LookupOption? get selectedThread => _selectedThread;
  LookupOption? get selectedLength => _selectedLength;
  LookupOption? get selectedHead   => _selectedHead;
  LookupOption? get selectedColour => _selectedColour;
  String? get selectedUom => _selectedUom;

  /// "Name_Thread_Length_Head_Colour" composite key
  String? get itemIdUom {
    if (_selectedItem == null || _selectedThread == null ||
        _selectedLength == null || _selectedHead == null ||
        _selectedColour == null) return null;
    return '${_selectedItem!.label}_${_selectedThread!.label}_'
        '${_selectedLength!.label}_${_selectedHead!.label}_${_selectedColour!.label}';
  }

  bool get isItemFullySelected =>
      _selectedItem != null &&
      _selectedThread != null &&
      _selectedLength != null &&
      _selectedHead != null &&
      _selectedColour != null &&
      _selectedUom != null;

  // ─────────────────────────────────────────────
  // Entry tab state
  // ─────────────────────────────────────────────
  String _entryDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _isSubmitting = false;
  String _submitError = '';
  String _submitSuccess = '';

  String get entryDate     => _entryDate;
  bool   get isSubmitting  => _isSubmitting;
  String get submitError   => _submitError;
  String get submitSuccess => _submitSuccess;

  // Log history for entry tab (combined: manual + sales)
  ItemEntriesResult? _entriesResult;
  bool _isLoadingEntries = false;

  ItemEntriesResult? get entriesResult    => _entriesResult;
  bool               get isLoadingEntries => _isLoadingEntries;

  // Convenience getters
  List<ItemWeightUomLogEntry> get logEntries       => _entriesResult?.manualEntries ?? [];
  List<SaleTransactionEntry>  get saleTransactions => _entriesResult?.saleTransactions ?? [];
  bool get hasAnyEntries => !(_entriesResult?.isEmpty ?? true);

  // ─────────────────────────────────────────────
  // Enquiry tab state
  // ─────────────────────────────────────────────
  bool _isCashCustomer = true;
  CustomerOption? _selectedEnquiryCustomer;
  ItemWeightUomEnquiryResult? _enquiryResult;
  bool _isEnquiring = false;
  String _enquiryError = '';

  bool get isCashCustomer => _isCashCustomer;
  CustomerOption? get selectedEnquiryCustomer => _selectedEnquiryCustomer;
  ItemWeightUomEnquiryResult? get enquiryResult => _enquiryResult;
  bool get isEnquiring => _isEnquiring;
  String get enquiryError => _enquiryError;

  // ─────────────────────────────────────────────
  // Load base options
  // ─────────────────────────────────────────────
  Future<void> _loadBaseOptions() async {
    _loadState = ItemWeightLoadState.loading;
    _loadError = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.instance.fetchDropdownOptions(),
        ApiService.instance.fetchCustomers(),
      ]);
      _options   = results[0] as DropdownOptionsModel;
      _customers = results[1] as List<CustomerOption>;
      _loadState = ItemWeightLoadState.loaded;
    } on ApiException catch (e) {
      _loadState = ItemWeightLoadState.error;
      _loadError = e.message;
    } catch (e) {
      _loadState = ItemWeightLoadState.error;
      _loadError = 'Unexpected error: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> retryLoad() => _loadBaseOptions();

  // ─────────────────────────────────────────────
  // Item selector setters (cascade)
  // ─────────────────────────────────────────────
  void setItem(LookupOption? v) {
    _selectedItem   = v;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead   = null;
    _selectedColour = null;
    _clearResults();
    notifyListeners();
    if (v != null) _fetchFilteredOptions();
  }

  void setThread(LookupOption? v) {
    _selectedThread = v;
    _selectedLength = null;
    _selectedHead   = null;
    _selectedColour = null;
    _clearResults();
    notifyListeners();
    _fetchFilteredOptions();
  }

  void setLength(LookupOption? v) {
    _selectedLength = v;
    _selectedHead   = null;
    _selectedColour = null;
    _clearResults();
    notifyListeners();
    _fetchFilteredOptions();
  }

  void setHead(LookupOption? v) {
    _selectedHead   = v;
    _selectedColour = null;
    _clearResults();
    notifyListeners();
    _fetchFilteredOptions();
  }

  void setColour(LookupOption? v) {
    _selectedColour = v;
    _clearResults();
    notifyListeners();
  }

  void setUom(String? v) {
    _selectedUom = v;
    _clearResults();
    notifyListeners();
    // Auto-load log entries when both item and uom are selected
    if (isItemFullySelected) {
      loadLogEntries();
    }
  }

  void _clearResults() {
    _enquiryResult  = null;
    _enquiryError   = '';
    _entriesResult  = null;
  }

  Future<void> _fetchFilteredOptions() async {
    try {
      final newOptions = await ApiService.instance.fetchDropdownOptions(
        itemName: _selectedItem?.label,
        thread:   _selectedThread?.label,
        length:   _selectedLength?.label,
        head:     _selectedHead?.label,
      );
      _options = _options.copyWith(
        threads: newOptions.threads,
        lengths: newOptions.lengths,
        heads:   newOptions.heads,
        colours: newOptions.colours,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch filtered options: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Entry tab methods
  // ─────────────────────────────────────────────
  void setEntryDate(String v) {
    _entryDate = v;
    notifyListeners();
  }

  Future<void> submitEntry({
    required double weightPerUom,
    required double saleRatePerUom,
  }) async {
    if (itemIdUom == null || _selectedUom == null) return;

    _isSubmitting  = true;
    _submitError   = '';
    _submitSuccess = '';
    notifyListeners();

    try {
      final qtyPerUom = kUomQtyMap[_selectedUom];
      await ApiService.instance.saveItemWeightEntry({
        'item_id_uom':      itemIdUom,
        'uom':              _selectedUom,
        'date':             _entryDate,
        'weight_per_uom':   weightPerUom,
        'weight_uom':       'KG',
        'sale_rate_per_uom': saleRatePerUom,
        if (qtyPerUom != null) 'quantity_per_uom': qtyPerUom,
      });
      _submitSuccess = 'Entry saved for ${_entryDate}';
      // Refresh log
      await loadLogEntries();
    } on ApiException catch (e) {
      _submitError = e.message;
    } catch (e) {
      _submitError = 'An unexpected error occurred.';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadLogEntries() async {
    if (itemIdUom == null) return;

    _isLoadingEntries = true;
    notifyListeners();

    try {
      final raw = await ApiService.instance.fetchItemWeightEntries(
        itemIdUom: itemIdUom!,
        uom:       _selectedUom,
      );
      _entriesResult = ItemEntriesResult.fromJson(raw);
    } catch (e) {
      debugPrint('Failed to load entries: $e');
      _entriesResult = null;
    } finally {
      _isLoadingEntries = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Enquiry tab methods
  // ─────────────────────────────────────────────
  void setCashCustomer(bool isCash) {
    _isCashCustomer            = isCash;
    _selectedEnquiryCustomer   = null;
    _enquiryResult             = null;
    notifyListeners();
  }

  void setEnquiryCustomer(CustomerOption? v) {
    _selectedEnquiryCustomer = v;
    _enquiryResult = null;
    notifyListeners();
  }

  Future<void> runEnquiry() async {
    if (itemIdUom == null || _selectedUom == null) return;

    _isEnquiring  = true;
    _enquiryError = '';
    _enquiryResult = null;
    notifyListeners();

    try {
      final customer = _isCashCustomer ? 'cash' : _selectedEnquiryCustomer?.alias;
      final raw = await ApiService.instance.fetchItemEnquiry(
        itemIdUom: itemIdUom!,
        uom:       _selectedUom!,
        customer:  customer,
      );
      _enquiryResult = ItemWeightUomEnquiryResult.fromJson(raw);
    } on ApiException catch (e) {
      _enquiryError = e.message;
    } catch (e) {
      _enquiryError = 'An unexpected error occurred.';
    } finally {
      _isEnquiring = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Reset
  // ─────────────────────────────────────────────
  void resetSelector() {
    _selectedItem   = null;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead   = null;
    _selectedColour = null;
    _selectedUom    = null;
    _clearResults();
    notifyListeners();
  }
}

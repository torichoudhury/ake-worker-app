import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../sales/models/dropdown_options_model.dart';
import '../../sales/providers/sales_form_provider.dart'; // Using FormLoadState from here
import '../models/movement_item_model.dart';

class MovementFormProvider extends ChangeNotifier {
  FormLoadState _loadState = FormLoadState.idle;
  String _loadError = '';

  FormLoadState get loadState => _loadState;
  String get loadError => _loadError;

  DropdownOptionsModel _options = DropdownOptionsModel.empty();

  List<LookupOption> get items => _options.items;
  List<LookupOption> get threads => _options.threads;
  List<LookupOption> get lengths => _options.lengths;
  List<LookupOption> get heads => _options.heads;
  List<LookupOption> get colours => _options.colours;

  // Form Fields
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _selectedActivity;
  String? _fromLocation;
  String? _toLocation;
  
  LookupOption? _selectedItem;
  LookupOption? _selectedThread;
  LookupOption? _selectedLength;
  LookupOption? _selectedHead;
  LookupOption? _selectedColour;
  
  double? _quantity;
  double? _packet;
  String? _selectedUom;
  String? _packetUom;
  int? _perPacket;

  // After Plating Fields
  LookupOption? _afterColour;
  double? _afterQuantity;
  double? _afterPacket;
  String? _afterUom;
  String? _afterPacketUom;
  int? _afterPerPacket;

  // Multi-item cart
  final List<MovementItem> _movementItems = [];

  bool _isSubmitting = false;
  String _submitError = '';
  int? _lastMovementId;

  // Getters
  String get selectedDate => _selectedDate;
  String? get selectedActivity => _selectedActivity;
  String? get fromLocation => _fromLocation;
  String? get toLocation => _toLocation;
  
  LookupOption? get selectedItem => _selectedItem;
  LookupOption? get selectedThread => _selectedThread;
  LookupOption? get selectedLength => _selectedLength;
  LookupOption? get selectedHead => _selectedHead;
  LookupOption? get selectedColour => _selectedColour;
  
  double? get quantity => _quantity;
  double? get packet => _packet;
  String? get selectedUom => _selectedUom;
  String? get packetUom => _packetUom;
  int? get perPacket => _perPacket;

  LookupOption? get afterColour => _afterColour;
  double? get afterQuantity => _afterQuantity;
  double? get afterPacket => _afterPacket;
  String? get afterUom => _afterUom;
  String? get afterPacketUom => _afterPacketUom;
  int? get afterPerPacket => _afterPerPacket;

  List<MovementItem> get movementItems => _movementItems;

  bool get isSubmitting => _isSubmitting;
  String get submitError => _submitError;
  int? get lastMovementId => _lastMovementId;

  bool get isPackingActivity => _selectedActivity == 'Packing: Box to Bag';
  bool get isPlatingLocation => _fromLocation == 'Plating' || _toLocation == 'Plating';

  // Setters
  void setDate(String v) { _selectedDate = v; notifyListeners(); }
  void setActivity(String? v) { 
    _selectedActivity = v;
    _movementItems.clear(); // Clear cart when switching activity type
    notifyListeners(); 
  }
  void setFromLocation(String? v) { _fromLocation = v; notifyListeners(); }
  void setToLocation(String? v) { _toLocation = v; notifyListeners(); }

  void setItem(LookupOption? v) {
    _selectedItem = v;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead = null;
    _selectedColour = null;
    _afterColour = null;
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
    notifyListeners(); 
  }
  
  void setQuantity(String text) {
    _quantity = text.isEmpty ? null : double.tryParse(text);
    notifyListeners();
  }
  
  void setPacket(String text) {
    _packet = text.isEmpty ? null : double.tryParse(text);
    notifyListeners();
  }
  
  void setUom(String? v) { _selectedUom = v; notifyListeners(); }
  void setPacketUom(String? v) { _packetUom = v; notifyListeners(); }
  
  void setPerPacket(String text) {
    _perPacket = text.isEmpty ? null : int.tryParse(text);
    notifyListeners();
  }

  void setAfterColour(LookupOption? v) { _afterColour = v; notifyListeners(); }
  
  void setAfterQuantity(String text) {
    _afterQuantity = text.isEmpty ? null : double.tryParse(text);
    notifyListeners();
  }
  
  void setAfterPacket(String text) {
    _afterPacket = text.isEmpty ? null : double.tryParse(text);
    notifyListeners();
  }
  
  void setAfterUom(String? v) { _afterUom = v; notifyListeners(); }
  void setAfterPacketUom(String? v) { _afterPacketUom = v; notifyListeners(); }
  
  void setAfterPerPacket(String text) {
    _afterPerPacket = text.isEmpty ? null : int.tryParse(text);
    notifyListeners();
  }

  // Cart Methods
  void addMovementItem() {
    if (_selectedItem == null || _selectedThread == null || _selectedLength == null ||
        _selectedHead == null || _selectedColour == null) {
      return;
    }

    if (isPlatingLocation) {
      final hasBefore = _quantity != null && _selectedUom != null;
      final hasAfter = _afterColour != null && _afterQuantity != null && _afterUom != null;
      if (!hasBefore && !hasAfter) return; // Must have at least one side
    } else {
      if (_quantity == null || _selectedUom == null) return;
    }

    _movementItems.add(MovementItem(
      item: _selectedItem!,
      thread: _selectedThread!,
      length: _selectedLength!,
      head: _selectedHead!,
      colour: _selectedColour!,
      quantity: _quantity,
      uom: _selectedUom,
      packet: _packet,
      perPacket: _perPacket,
      packetUom: _packetUom,
      afterColour: _afterColour,
      afterQuantity: _afterQuantity,
      afterUom: _afterUom,
      afterPacket: _afterPacket,
      afterPerPacket: _afterPerPacket,
      afterPacketUom: _afterPacketUom,
    ));

    // Reset item form fields
    _selectedItem = null;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead = null;
    _selectedColour = null;
    _quantity = null;
    _packet = null;
    _perPacket = null;
    _packetUom = null;
    
    notifyListeners();
  }

  void removeMovementItem(int index) {
    _movementItems.removeAt(index);
    notifyListeners();
  }

  Future<void> loadOptions() async {
    if (_loadState == FormLoadState.loading) return;
    _loadState = FormLoadState.loading;
    _loadError = '';
    notifyListeners();

    try {
      _options = await ApiService.instance.fetchDropdownOptions();
      _loadState = FormLoadState.loaded;
    } catch (e) {
      _loadState = FormLoadState.error;
      _loadError = 'Failed to load options: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> submit() async {
    if (_fromLocation == null) {
      _submitError = 'Please select a From Location.';
      return false;
    }
    
    if (!isPackingActivity && _fromLocation == _toLocation) {
      _submitError = 'From and To locations cannot be the same.';
      return false;
    }
    
    if (!isPackingActivity && !isPlatingLocation && _movementItems.isEmpty) {
      _submitError = 'List is empty. Please add items.';
      return false;
    }
    
    if (isPackingActivity && (_selectedItem == null || _quantity == null || _selectedUom == null)) {
      _submitError = 'Please fill out all required packing fields (Item, Quantity, UoM).';
      return false;
    }

    if (isPlatingLocation) {
      bool isValid = _selectedItem != null && _selectedThread != null && _selectedLength != null && _selectedHead != null && _selectedColour != null;
      final hasBeforeQty = _quantity != null && _selectedUom != null;
      final hasAfterQty = _afterQuantity != null && _afterUom != null && _afterColour != null;
      
      final isPartialBefore = (_quantity != null || _selectedUom != null) && !hasBeforeQty;
      final isPartialAfter = (_afterQuantity != null || _afterUom != null || _afterColour != null) && !hasAfterQty;
      
      if (!isValid || (!hasBeforeQty && !hasAfterQty)) {
        _submitError = 'Please fill out required item details and at least one Plating quantity (Before or After).';
        return false;
      }
      if (isPartialBefore || isPartialAfter) {
        _submitError = 'You have partially filled a section. Please complete both Quantity and UoM for whichever sections you are using, and select the New Colour for After Plating.';
        return false;
      }
    }

    _isSubmitting = true;
    _submitError = '';
    notifyListeners();

    try {
      List<Map<String, dynamic>> itemsPayload = [];

      if (isPackingActivity) {
        itemsPayload.add({
          'item_name': _selectedItem!.label,
          'thread': _selectedThread!.label,
          'length': _selectedLength!.label,
          'head': _selectedHead!.label,
          'colour': _selectedColour!.label,
          'quantity': _quantity,
          'uom': _selectedUom,
          'packet': _packet,
          'per_packet': _perPacket,
          'uom_packet': _packetUom,
        });
      } else if (isPlatingLocation) {
        itemsPayload.add({
          'item_name': _selectedItem!.label,
          'thread': _selectedThread!.label,
          'length': _selectedLength!.label,
          'head': _selectedHead!.label,
          'colour': _selectedColour!.label,
          'quantity': _quantity,
          'uom': _selectedUom,
          'packet': _packet,
          'per_packet': _perPacket,
          'uom_packet': _packetUom,
          'after_colour': _afterColour?.label,
          'after_quantity': _afterQuantity,
          'after_uom': _afterUom,
          'after_packet': _afterPacket,
          'after_per_packet': _afterPerPacket,
          'after_uom_packet': _afterPacketUom,
        });
      } else {
        itemsPayload = _movementItems.map((item) => {
          'item_name': item.item.label,
          'thread': item.thread.label,
          'length': item.length.label,
          'head': item.head.label,
          'colour': item.colour.label,
          'quantity': item.quantity,
          'uom': item.uom,
          'packet': item.packet,
          'per_packet': item.perPacket,
          'uom_packet': item.packetUom,
          'after_colour': item.afterColour?.label,
          'after_quantity': item.afterQuantity,
          'after_uom': item.afterUom,
          'after_packet': item.afterPacket,
          'after_per_packet': item.afterPerPacket,
          'after_uom_packet': item.afterPacketUom,
        }).toList();
      }

      final payload = {
        'date': _selectedDate,
        'activity': _selectedActivity,
        'from_location': _fromLocation,
        'to_location': isPackingActivity ? null : _toLocation,
        'items': itemsPayload,
      };

      final response = await ApiService.instance.createMovement(payload);
      _lastMovementId = int.tryParse(response['movement_id']?.toString() ?? '');

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
    _selectedActivity = null;
    _fromLocation = null;
    _toLocation = null;
    _selectedItem = null;
    _selectedThread = null;
    _selectedLength = null;
    _selectedHead = null;
    _selectedColour = null;
    _quantity = null;
    _packet = null;
    _selectedUom = null;
    _packetUom = null;
    _perPacket = null;
    _afterColour = null;
    _afterQuantity = null;
    _afterPacket = null;
    _afterUom = null;
    _afterPacketUom = null;
    _afterPerPacket = null;
    _movementItems.clear();
    _lastMovementId = null;
    notifyListeners();
  }
}

// lib/features/item_weight_uom/models/item_weight_uom_model.dart
// Data models for Item Weight/UoM entry, log, and enquiry result.

// ─────────────────────────────────────────────
// A single manual entry from item_weight_uom_log
// ─────────────────────────────────────────────
class ItemWeightUomLogEntry {
  final int? id;
  final String itemIdUom;
  final String date;
  final String uom;
  final double? weightPerUom;     // in KG
  final String weightUom;
  final double? saleRatePerUom;
  final double? quantityPerUom;
  final String source; // 'manual_entry' | 'sale_transaction'

  const ItemWeightUomLogEntry({
    this.id,
    required this.itemIdUom,
    required this.date,
    required this.uom,
    this.weightPerUom,
    this.weightUom = 'KG',
    this.saleRatePerUom,
    this.quantityPerUom,
    this.source = 'manual_entry',
  });

  factory ItemWeightUomLogEntry.fromJson(Map<String, dynamic> json) {
    return ItemWeightUomLogEntry(
      id:             json['id'] != null ? (json['id'] as num).toInt() : null,
      itemIdUom:      json['item_id_uom'] as String? ?? '',
      date:           json['date'] as String? ?? '',
      uom:            json['uom'] as String? ?? '',
      weightPerUom:   json['weight_per_uom'] != null
          ? double.tryParse(json['weight_per_uom'].toString())
          : null,
      weightUom:      json['weight_uom'] as String? ?? 'KG',
      saleRatePerUom: json['sale_rate_per_uom'] != null
          ? double.tryParse(json['sale_rate_per_uom'].toString())
          : null,
      quantityPerUom: json['quantity_per_uom'] != null
          ? double.tryParse(json['quantity_per_uom'].toString())
          : null,
      source:         json['source'] as String? ?? 'manual_entry',
    );
  }
}

// ─────────────────────────────────────────────
// A single sale transaction entry for history view
// ─────────────────────────────────────────────
class SaleTransactionEntry {
  final int? id;
  final String date;
  final String uom;
  final double? rate;
  final String? party;
  final double? quantity;
  final double? amount;

  const SaleTransactionEntry({
    this.id,
    required this.date,
    required this.uom,
    this.rate,
    this.party,
    this.quantity,
    this.amount,
  });

  factory SaleTransactionEntry.fromJson(Map<String, dynamic> json) {
    double? _p(dynamic v) => v != null ? double.tryParse(v.toString()) : null;
    return SaleTransactionEntry(
      id:       json['id'] != null ? (json['id'] as num).toInt() : null,
      date:     json['date'] as String? ?? '',
      uom:      json['uom'] as String? ?? '',
      rate:     _p(json['sale_rate_per_uom']),
      party:    json['party'] as String?,
      quantity: _p(json['quantity']),
      amount:   _p(json['amount']),
    );
  }
}

// ─────────────────────────────────────────────
// Combined entries result from GET /entries
// ─────────────────────────────────────────────
class ItemEntriesResult {
  final List<ItemWeightUomLogEntry> manualEntries;
  final List<SaleTransactionEntry> saleTransactions;

  const ItemEntriesResult({
    required this.manualEntries,
    required this.saleTransactions,
  });

  factory ItemEntriesResult.fromJson(Map<String, dynamic> json) {
    final manual = (json['manual_entries'] as List<dynamic>? ?? [])
        .map((e) => ItemWeightUomLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final sales = (json['sale_transactions'] as List<dynamic>? ?? [])
        .map((e) => SaleTransactionEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return ItemEntriesResult(manualEntries: manual, saleTransactions: sales);
  }

  bool get isEmpty => manualEntries.isEmpty && saleTransactions.isEmpty;
}

// ─────────────────────────────────────────────
// Enquiry result returned by GET /enquiry
// ─────────────────────────────────────────────
class ItemWeightUomEnquiryResult {
  final String itemIdUom;
  final String uom;
  final double? weightPerUom;     // avg weight in KG from log
  final String weightUom;
  final double? firstRate;        // first-ever rate (log + sales combined)
  final double? avgRate;          // avg across log + sales (sliding window)
  final double? customerLastRate; // last rate from sale_transaction for specific customer
  final double? suggestedRate;    // = customerLastRate ?? avgRate

  const ItemWeightUomEnquiryResult({
    required this.itemIdUom,
    required this.uom,
    this.weightPerUom,
    this.weightUom = 'KG',
    this.firstRate,
    this.avgRate,
    this.customerLastRate,
    this.suggestedRate,
  });

  factory ItemWeightUomEnquiryResult.fromJson(Map<String, dynamic> json) {
    double? _p(dynamic v) => v != null ? double.tryParse(v.toString()) : null;
    return ItemWeightUomEnquiryResult(
      itemIdUom:        json['item_id_uom'] as String? ?? '',
      uom:              json['uom'] as String? ?? '',
      weightPerUom:     _p(json['weight_per_uom']),
      weightUom:        json['weight_uom'] as String? ?? 'KG',
      firstRate:        _p(json['first_rate']),
      avgRate:          _p(json['avg_rate']),
      customerLastRate: _p(json['customer_last_rate']),
      suggestedRate:    _p(json['suggested_rate']),
    );
  }
}

// lib/features/sales/models/dropdown_options_model.dart
// Data models for the dropdown option lists and customer list

// ─────────────────────────────────────────────
// Generic lookup option (id + label) — for items, threads, lengths, heads, colours
// ─────────────────────────────────────────────

class LookupOption {
  final String label;

  const LookupOption({required this.label});

  factory LookupOption.fromJson(Map<String, dynamic> json,
      {String labelKey = 'name'}) {
    return LookupOption(
      label: json[labelKey] as String,
    );
  }

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookupOption &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;
}

// ─────────────────────────────────────────────
// Customer option — id, name, alias
// The "alias" is what gets stored as Party in Sale_Transaction
// ─────────────────────────────────────────────

class CustomerOption {
  final String alias;       // stored as party in sale_transaction
  final String vendorName;  // display name (vendor_name column)

  const CustomerOption({
    required this.alias,
    required this.vendorName,
  });

  factory CustomerOption.fromJson(Map<String, dynamic> json) {
    return CustomerOption(
      alias:      json['alias'] as String,
      vendorName: json['vendor_name'] as String? ?? json['alias'] as String,
    );
  }

  /// Display label: "ALIAS — Vendor Name"
  String get displayLabel => '$alias — $vendorName';

  @override
  String toString() => displayLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerOption &&
          runtimeType == other.runtimeType &&
          alias == other.alias;

  @override
  int get hashCode => alias.hashCode;
}

// ─────────────────────────────────────────────
// Dropdown options for item-related fields
// ─────────────────────────────────────────────

class DropdownOptionsModel {
  final List<LookupOption> items;
  final List<LookupOption> threads;
  final List<LookupOption> lengths;
  final List<LookupOption> heads;
  final List<LookupOption> colours;

  const DropdownOptionsModel({
    required this.items,
    required this.threads,
    required this.lengths,
    required this.heads,
    required this.colours,
  });

  factory DropdownOptionsModel.fromJson(Map<String, dynamic> json) {
    List<LookupOption> parse(dynamic list, {String labelKey = 'name'}) {
      return (list as List<dynamic>)
          .map((e) =>
              LookupOption.fromJson(e as Map<String, dynamic>, labelKey: labelKey))
          .toList();
    }

    return DropdownOptionsModel(
      items:   parse(json['items']),
      threads: parse(json['threads']),
      lengths: parse(json['lengths'], labelKey: 'value'),
      heads:   parse(json['heads']),
      colours: parse(json['colours']),
    );
  }

  static DropdownOptionsModel empty() => const DropdownOptionsModel(
        items:   [],
        threads: [],
        lengths: [],
        heads:   [],
        colours: [],
      );
}

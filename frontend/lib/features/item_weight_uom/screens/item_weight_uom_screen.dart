// lib/features/item_weight_uom/screens/item_weight_uom_screen.dart
// Two-tab screen:
//   Tab 1 — "Record Entry"  : save date-stamped weight + rate for an item+UoM
//   Tab 2 — "Enquiry"       : look up avg weight + suggested sale rate by item+UoM+Customer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../sales/models/dropdown_options_model.dart';
import '../models/item_weight_uom_model.dart';
import '../providers/item_weight_uom_provider.dart';

class ItemWeightUomScreen extends StatelessWidget {
  const ItemWeightUomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ItemWeightUomProvider(),
      child: const _ItemWeightUomView(),
    );
  }
}

class _ItemWeightUomView extends StatefulWidget {
  const _ItemWeightUomView();

  @override
  State<_ItemWeightUomView> createState() => _ItemWeightUomViewState();
}

class _ItemWeightUomViewState extends State<_ItemWeightUomView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemWeightUomProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Weight & Rates'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Record Entry'),
            Tab(icon: Icon(Icons.manage_search_rounded), text: 'Enquiry'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset',
            onPressed: () => provider.resetSelector(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ItemWeightUomProvider provider) {
    switch (provider.loadState) {
      case ItemWeightLoadState.idle:
      case ItemWeightLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case ItemWeightLoadState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 48),
              const SizedBox(height: 16),
              Text('Failed to load data',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(provider.loadError,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: provider.retryLoad,
                style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case ItemWeightLoadState.loaded:
        return TabBarView(
          controller: _tabController,
          children: [
            _RecordEntryTab(provider: provider),
            _EnquiryTab(provider: provider),
          ],
        );
    }
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 1 — Record Entry
// ══════════════════════════════════════════════════════════════════

class _RecordEntryTab extends StatefulWidget {
  final ItemWeightUomProvider provider;
  const _RecordEntryTab({required this.provider});

  @override
  State<_RecordEntryTab> createState() => _RecordEntryTabState();
}

class _RecordEntryTabState extends State<_RecordEntryTab> {
  final _formKey           = GlobalKey<FormState>();
  final _weightController  = TextEditingController();
  final _rateController    = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final p = widget.provider;
    if (!p.isItemFullySelected) {
      _showSnackbar('Please select all item fields and UoM.', isError: true);
      return;
    }

    final weight = double.tryParse(_weightController.text) ?? 0;
    final rate   = double.tryParse(_rateController.text)   ?? 0;

    await p.submitEntry(weightPerUom: weight, saleRatePerUom: rate);

    if (!mounted) return;
    if (p.submitError.isNotEmpty) {
      _showSnackbar(p.submitError, isError: true);
    } else {
      _showSnackbar(p.submitSuccess, isError: false);
      _weightController.clear();
      _rateController.clear();
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white, size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Item Selector ─────────────────────────
                _ItemSelectorCard(provider: p),
                const SizedBox(height: 16),

                // ── Entry Fields ──────────────────────────
                Form(
                  key: _formKey,
                  child: SectionCard(
                    title: 'Entry Details',
                    icon: Icons.edit_calendar_rounded,
                    accentColor: const Color(0xFF1565C0),
                    children: [
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(p.entryDate) ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            p.setEntryDate(DateFormat('yyyy-MM-dd').format(date));
                          }
                        },
                        child: AbsorbPointer(
                          child: AppTextField(
                            label: 'Entry Date',
                            controller: TextEditingController(text: p.entryDate),
                            readOnly: true,
                            prefixIcon: const Icon(Icons.calendar_today_rounded,
                                size: 20, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weight per UoM
                      AppTextField(
                        label: 'Weight per UoM (KG)',
                        controller: _weightController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: const Icon(Icons.monitor_weight_outlined,
                            size: 20, color: Colors.grey),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,3}')),
                        ],
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Sale rate per UoM
                      AppTextField(
                        label: 'Sale Rate per UoM',
                        controller: _rateController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded,
                            size: 20, color: Colors.grey),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),

                      // UoM conversion hint
                      if (p.selectedUom != null) ...[
                        const SizedBox(height: 8),
                        _UomConversionHint(uom: p.selectedUom!),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: p.isSubmitting ? null : _submit,
                          icon: p.isSubmitting
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            p.isSubmitting ? 'Saving...' : 'Save Entry',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Log History ───────────────────────────
                _LogHistoryCard(provider: p),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 2 — Enquiry
// ══════════════════════════════════════════════════════════════════

class _EnquiryTab extends StatefulWidget {
  final ItemWeightUomProvider provider;
  const _EnquiryTab({required this.provider});

  @override
  State<_EnquiryTab> createState() => _EnquiryTabState();
}

class _EnquiryTabState extends State<_EnquiryTab> {
  @override
  Widget build(BuildContext context) {
    final p = widget.provider;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Item Selector ───────────────────────────
          _ItemSelectorCard(provider: p),
          const SizedBox(height: 16),

          // ── Customer Selection ──────────────────────
          SectionCard(
            title: 'Customer',
            icon: Icons.person_search_rounded,
            accentColor: const Color(0xFF6A1B9A),
            children: [
              // Cash / Specific toggle
              Row(
                children: [
                  Expanded(
                    child: _ToggleButton(
                      label: 'Cash Customer',
                      icon: Icons.payments_outlined,
                      selected: p.isCashCustomer,
                      onTap: () => p.setCashCustomer(true),
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ToggleButton(
                      label: 'Specific Customer',
                      icon: Icons.person_pin_rounded,
                      selected: !p.isCashCustomer,
                      onTap: () => p.setCashCustomer(false),
                      color: const Color(0xFF6A1B9A),
                    ),
                  ),
                ],
              ),
              if (!p.isCashCustomer) ...[
                const SizedBox(height: 16),
                AppDropdown<CustomerOption>(
                  label: 'Select Customer',
                  value: p.selectedEnquiryCustomer,
                  items: p.customers,
                  itemLabel: (c) => c.displayLabel,
                  onChanged: p.setEnquiryCustomer,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Enquire Button ──────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (p.isItemFullySelected && !p.isEnquiring)
                  ? () => p.runEnquiry()
                  : null,
              icon: p.isEnquiring
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search_rounded),
              label: Text(
                p.isEnquiring ? 'Fetching...' : 'Enquire',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Enquiry Error ───────────────────────────
          if (p.enquiryError.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFD32F2F), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.enquiryError,
                        style: GoogleFonts.inter(
                            color: const Color(0xFFD32F2F), fontSize: 14)),
                  ),
                ],
              ),
            ),

          // ── Enquiry Result ──────────────────────────
          if (p.enquiryResult != null) ...[
            _EnquiryResultCard(result: p.enquiryResult!),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Shared: Item Selector Card
// ══════════════════════════════════════════════════════════════════

class _ItemSelectorCard extends StatelessWidget {
  final ItemWeightUomProvider provider;
  const _ItemSelectorCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;

    return SectionCard(
      title: 'Select Item',
      icon: Icons.inventory_2_outlined,
      children: [
        AppDropdown<LookupOption>(
          label: 'Item Name',
          value: p.selectedItem,
          items: p.items,
          itemLabel: (o) => o.label,
          onChanged: p.setItem,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppDropdown<LookupOption>(
                label: 'Thread/ID',
                value: p.selectedThread,
                items: p.threads,
                itemLabel: (o) => o.label,
                onChanged: p.setThread,
                enabled: p.selectedItem != null,
                hint: p.selectedItem == null ? 'Select Item' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDropdown<LookupOption>(
                label: 'Length/OD',
                value: p.selectedLength,
                items: p.lengths,
                itemLabel: (o) => o.label,
                onChanged: p.setLength,
                enabled: p.selectedThread != null,
                hint: p.selectedThread == null ? 'Select Thread' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppDropdown<LookupOption>(
                label: 'Head',
                value: p.selectedHead,
                items: p.heads,
                itemLabel: (o) => o.label,
                onChanged: p.setHead,
                enabled: p.selectedLength != null,
                hint: p.selectedLength == null ? 'Select Length' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDropdown<LookupOption>(
                label: 'Colour',
                value: p.selectedColour,
                items: p.colours,
                itemLabel: (o) => o.label,
                onChanged: p.setColour,
                enabled: p.selectedHead != null,
                hint: p.selectedHead == null ? 'Select Head' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: 'UoM',
          value: p.selectedUom,
          items: AppConstants.uomOptions,
          itemLabel: (s) => s,
          onChanged: p.setUom,
          enabled: p.selectedColour != null,
          hint: p.selectedColour == null ? 'Select Colour First' : null,
        ),
        // Show composite key when fully selected
        if (p.itemIdUom != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.key_rounded, size: 14, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.itemIdUom!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Enquiry Result Card
// ══════════════════════════════════════════════════════════════════

class _EnquiryResultCard extends StatelessWidget {
  final ItemWeightUomEnquiryResult result;
  const _EnquiryResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.000', 'en_IN');
    final fmtRate = NumberFormat('#,##0.00', 'en_IN');

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Enquiry Result',
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.uom,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Weight row
                _ResultRow(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Avg Weight per UoM',
                  value: result.weightPerUom != null
                      ? '${fmt.format(result.weightPerUom!)} KG'
                      : '— No data',
                  highlight: false,
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),

                // Rate rows
                _ResultRow(
                  icon: Icons.first_page_rounded,
                  label: 'First Sale Rate',
                  value: result.firstRate != null
                      ? '₹ ${fmtRate.format(result.firstRate!)}'
                      : '— No data',
                  highlight: false,
                ),
                const SizedBox(height: 14),
                _ResultRow(
                  icon: Icons.timeline_rounded,
                  label: 'Avg Sale Rate (All-time)',
                  value: result.avgRate != null
                      ? '₹ ${fmtRate.format(result.avgRate!)}'
                      : '— No data',
                  highlight: false,
                ),
                if (result.customerLastRate != null) ...[
                  const SizedBox(height: 14),
                  _ResultRow(
                    icon: Icons.person_pin_rounded,
                    label: 'Customer Last Rate',
                    value: '₹ ${fmtRate.format(result.customerLastRate!)}',
                    highlight: false,
                  ),
                ],
                const SizedBox(height: 16),

                // Suggested rate — highlighted
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Suggested Rate',
                        style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600, letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.suggestedRate != null
                            ? '₹ ${fmtRate.format(result.suggestedRate!)}'
                            : '— No data yet',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      Text(
                        'per ${result.uom}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white70,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: highlight ? 17 : 14,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Log History Card (Entry tab)
// ══════════════════════════════════════════════════════════════════

class _LogHistoryCard extends StatelessWidget {
  final ItemWeightUomProvider provider;
  const _LogHistoryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final fmt     = NumberFormat('#,##0.000', 'en_IN');
    final fmtRate = NumberFormat('#,##0.00', 'en_IN');

    return SectionCard(
      title: 'Entry History',
      icon: Icons.history_rounded,
      accentColor: const Color(0xFF37474F),
      children: [
        if (!p.isItemFullySelected)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Select an item and UoM above to view history.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          )
        else if (p.isLoadingEntries)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          // ── Manual Entries ────────────────────────
          _SectionHeader(
            label: 'Manual Entries',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: 8),
          if (p.logEntries.isEmpty)
            _EmptyHint('No manual entries recorded yet.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: p.logEntries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = p.logEntries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_calendar_rounded,
                            size: 16, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.date,
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A2340),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'UoM: ${entry.uom}  •  Wt: ${entry.weightPerUom != null ? fmt.format(entry.weightPerUom!) : "—"} KG',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            entry.saleRatePerUom != null
                                ? '₹ ${fmtRate.format(entry.saleRatePerUom!)}'
                                : '—',
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          Text('per ${entry.uom}',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 16),
          const Divider(thickness: 1.5),
          const SizedBox(height: 8),

          // ── Sale Transactions ─────────────────────
          _SectionHeader(
            label: 'Sale Transactions',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 8),
          if (p.saleTransactions.isEmpty)
            _EmptyHint('No sale transactions found for this item.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: p.saleTransactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = p.saleTransactions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded,
                            size: 16, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.date,
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A2340),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tx.party ?? "—"}  •  Qty: ${tx.quantity != null ? tx.quantity!.toStringAsFixed(2) : "—"} ${tx.uom}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tx.rate != null
                                ? '₹ ${fmtRate.format(tx.rate!)}'
                                : '—',
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          if (tx.amount != null)
                            Text('Amt: ₹${fmtRate.format(tx.amount!)}',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
//  UoM Conversion Hint
// ══════════════════════════════════════════════════════════════════

class _UomConversionHint extends StatelessWidget {
  final String uom;
  const _UomConversionHint({required this.uom});

  String get _hint {
    switch (uom) {
      case 'Pcs':   return 'PCS = 1 piece';
      case '%':     return '% = 100 PCS';
      case 'Gross': return 'Gross = 144 PCS';
      case 'KG':    return 'KG = weight in kilograms';
      case 'Bag':   return 'Bag = natural unit (no conversion)';
      case 'Box':   return 'Box = natural unit (no conversion)';
      default:      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hint.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFF57F17)),
          const SizedBox(width: 6),
          Text(
            _hint,
            style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFFF57F17), fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Toggle Button (Cash / Specific Customer)
// ══════════════════════════════════════════════════════════════════

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey.shade500, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

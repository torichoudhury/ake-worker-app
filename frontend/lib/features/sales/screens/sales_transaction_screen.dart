import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_card.dart';
import '../models/dropdown_options_model.dart';
import '../providers/sales_form_provider.dart';

class SalesTransactionScreen extends StatelessWidget {
  const SalesTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SalesFormProvider()..loadOptions(),
      child: const _SalesTransactionView(),
    );
  }
}

class _SalesTransactionView extends StatefulWidget {
  const _SalesTransactionView();

  @override
  State<_SalesTransactionView> createState() => _SalesTransactionViewState();
}

class _SalesTransactionViewState extends State<_SalesTransactionView> {
  final _itemFormKey = GlobalKey<FormState>();
  final _transactionFormKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController();
  final _rateController     = TextEditingController();
  
  final _gstController      = TextEditingController();
  final _cartageController  = TextEditingController();
  final _receiptController  = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _rateController.dispose();
    _gstController.dispose();
    _cartageController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Action Handlers
  // ─────────────────────────────────────────────

  void _handleAddItem(SalesFormProvider provider) {
    if (!_itemFormKey.currentState!.validate()) {
      return;
    }
    
    if (provider.selectedItem == null ||
        provider.selectedThread == null ||
        provider.selectedLength == null ||
        provider.selectedHead == null ||
        provider.selectedColour == null ||
        provider.selectedUom == null) {
      _showSnackbar(context, 'Please select all item dropdowns.', isError: true);
      return;
    }

    final qty = double.tryParse(_quantityController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;

    provider.addToCart(qty, rate);
    
    _quantityController.clear();
    _rateController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleSubmitTransaction(SalesFormProvider provider) async {
    if (provider.cart.isEmpty) {
      _showSnackbar(context, 'Please add at least one item to the bill.', isError: true);
      return;
    }

    if (provider.selectedLocation == null ||
        provider.selectedParty == null ||
        provider.selectedMode == null) {
      _showSnackbar(context, 'Please complete General Information and Payment Mode.', isError: true);
      return;
    }

    final success = await provider.submit();

    if (!mounted) return;

    if (success) {
      _showSuccessDialog(provider);
    } else {
      _showSnackbar(context, provider.submitError, isError: true);
    }
  }

  void _showSuccessDialog(SalesFormProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 48),
            ),
            const SizedBox(height: 20),
            Text('Transaction Saved!',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A2340))),
            const SizedBox(height: 8),
            Text('All items have been successfully recorded.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text('Txn ID: ${provider.lastTransactionId ?? 'N/A'}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A2340))),
                  const SizedBox(height: 4),
                  Text('${provider.selectedParty?.vendorName ?? 'Unknown Customer'}',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _quantityController.clear();
              _rateController.clear();
              _gstController.clear();
              _cartageController.clear();
              _receiptController.clear();
              provider.resetForm();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('New Entry', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
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

  // ─────────────────────────────────────────────
  // UI Builders
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesFormProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset form',
            onPressed: () {
              _itemFormKey.currentState?.reset();
              _transactionFormKey.currentState?.reset();
              _quantityController.clear();
              _rateController.clear();
              _gstController.clear();
              _cartageController.clear();
              _receiptController.clear();
              provider.resetForm();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(SalesFormProvider provider) {
    switch (provider.loadState) {
      case FormLoadState.idle:
      case FormLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case FormLoadState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 48),
              const SizedBox(height: 16),
              Text('Failed to load data', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(provider.loadError, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => provider.loadOptions(),
                style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case FormLoadState.loaded:
        return _buildForm(provider);
    }
  }

  Widget _buildForm(SalesFormProvider provider) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGeneralInfo(provider),
                const SizedBox(height: 16),
                _buildItemDetails(provider),
                const SizedBox(height: 16),
                _buildBillTable(provider),
                const SizedBox(height: 16),
                _buildTransactionContainer(provider),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10),
            ],
          ),
          child: ElevatedButton(
            onPressed: provider.isSubmitting ? null : () => _handleSubmitTransaction(provider),
            child: provider.isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Transaction'),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralInfo(SalesFormProvider provider) {
    return SectionCard(
      title: 'General Information',
      icon: Icons.info_outline_rounded,
      children: [
        AppDropdown<String>(
          label: 'Location',
          value: provider.selectedLocation,
          items: AppConstants.locationOptions,
          itemLabel: (s) => s,
          onChanged: provider.setLocation,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(provider.selectedDate) ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              provider.setDate(DateFormat('yyyy-MM-dd').format(date));
            }
          },
          child: AbsorbPointer(
            child: AppTextField(
              label: 'Date',
              controller: TextEditingController(text: provider.selectedDate),
              readOnly: true,
              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppDropdown<CustomerOption>(
          label: 'Party',
          value: provider.selectedParty,
          items: provider.customers,
          itemLabel: (c) => c.displayLabel,
          onChanged: provider.setParty,
        ),
      ],
    );
  }

  Widget _buildItemDetails(SalesFormProvider provider) {
    return Form(
      key: _itemFormKey,
      child: SectionCard(
        title: 'Item Details',
        icon: Icons.inventory_2_outlined,
        children: [
          AppDropdown<LookupOption>(
            label: 'Item Name',
            value: provider.selectedItem,
            items: provider.items,
            itemLabel: (o) => o.label,
            onChanged: provider.setItem,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppDropdown<LookupOption>(
                  label: 'Thread/ID',
                  value: provider.selectedThread,
                  items: provider.threads,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setThread,
                  enabled: provider.selectedItem != null,
                  hint: provider.selectedItem == null ? 'Select Item First' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdown<LookupOption>(
                  label: 'Length/OD',
                  value: provider.selectedLength,
                  items: provider.lengths,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setLength,
                  enabled: provider.selectedThread != null,
                  hint: provider.selectedThread == null ? 'Select Thread/ID First' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppDropdown<LookupOption>(
                  label: 'Head',
                  value: provider.selectedHead,
                  items: provider.heads,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setHead,
                  enabled: provider.selectedLength != null,
                  hint: provider.selectedLength == null ? 'Select Length/OD First' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdown<LookupOption>(
                  label: 'Colour',
                  value: provider.selectedColour,
                  items: provider.colours,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setColour,
                  enabled: provider.selectedHead != null,
                  hint: provider.selectedHead == null ? 'Select Head First' : null,
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: 'Quantity',
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppDropdown<String>(
                  label: 'UoM',
                  value: provider.selectedUom,
                  items: AppConstants.uomOptions,
                  itemLabel: (s) => s,
                  onChanged: provider.setUom,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rate field + suggested rate chip
          Consumer<SalesFormProvider>(
            builder: (context, prov, _) {
              // Auto-fill rate when suggestion arrives and controller is empty
              if (prov.suggestedRate != null &&
                  _rateController.text.isEmpty &&
                  !prov.isFetchingRate) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_rateController.text.isEmpty) {
                    _rateController.text =
                        prov.suggestedRate!.toStringAsFixed(2);
                  }
                });
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Rate',
                    controller: _rateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon:
                        const Icon(Icons.currency_rupee_rounded, size: 20),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'))
                    ],
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  // Suggested rate badge
                  if (prov.isFetchingRate)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 6),
                          Text('Fetching suggested rate…',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  else if (prov.suggestedRate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _rateController.text =
                                prov.suggestedRate!.toStringAsFixed(2);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF1565C0).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 13, color: Color(0xFF1565C0)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Suggested: ₹${prov.suggestedRate!.toStringAsFixed(2)}  •  Tap to use',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (prov.avgRate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  'Average Price: ₹${prov.avgRate!.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleAddItem(provider),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text('Add Item to Bill', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillTable(SalesFormProvider provider) {
    return SectionCard(
      title: 'Bill Items',
      icon: Icons.receipt_long_rounded,
      children: provider.cart.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'No items added to the bill yet.\nFill the Item Details above and tap "Add Item to Bill".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey.shade500, height: 1.5),
                  ),
                ),
              )
            ]
          : [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.cart.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = provider.cart[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${item.item.label} ',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1A2340)),
                          ),
                          TextSpan(
                            text: '  ${item.length.label} * ${item.thread.label} | ${item.head.label} | ${item.colour.label}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${item.quantity} ${item.uom}  |  ₹${item.rate}',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          '₹${item.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1A2340)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => provider.removeFromCart(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
    );
  }

  Widget _buildTransactionContainer(SalesFormProvider provider) {
    return Form(
      key: _transactionFormKey,
      child: SectionCard(
        title: 'Transaction Summary',
        icon: Icons.payments_outlined,
        children: [
          _SummaryRow(label: 'Total Items Amount:', value: provider.totalItemsAmount),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'GST %',
                  controller: _gstController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: const Icon(Icons.percent_rounded, size: 18),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: provider.setGst,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Cartage',
                  controller: _cartageController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onChanged: provider.setCartage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _SummaryRow(label: 'Grand Total:', value: provider.grandTotal, isBold: true, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'Payment Mode',
            value: provider.selectedMode,
            items: AppConstants.modeOptions,
            itemLabel: (s) => s.toUpperCase(),
            onChanged: provider.setMode,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Receipt (Amount Paid)',
            controller: _receiptController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            onChanged: provider.setReceipt,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: provider.remaining > 0 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _SummaryRow(
              label: 'Remaining Balance:', 
              value: provider.remaining, 
              isBold: true, 
              color: provider.remaining > 0 ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final Color? color;

  const _SummaryRow({required this.label, required this.value, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: isBold ? 16 : 15,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? Colors.grey.shade700,
        )),
        Text('₹${fmt.format(value)}', style: GoogleFonts.inter(
          fontSize: isBold ? 18 : 16,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? const Color(0xFF1A2340),
        )),
      ],
    );
  }
}

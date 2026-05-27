// lib/features/sales/screens/sales_transaction_screen.dart
// Full Sales Transaction form screen

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

// ─────────────────────────────────────────────
// Internal stateful view
// ─────────────────────────────────────────────

class _SalesTransactionView extends StatefulWidget {
  const _SalesTransactionView();

  @override
  State<_SalesTransactionView> createState() => _SalesTransactionViewState();
}

class _SalesTransactionViewState extends State<_SalesTransactionView> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _rateController     = TextEditingController();
  final _receiptController  = TextEditingController();

  // Date is auto-set from device clock (read-only display)

  @override
  void dispose() {
    _quantityController.dispose();
    _rateController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Submit handler
  // ─────────────────────────────────────────────

  Future<void> _handleSubmit(SalesFormProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar(
        context,
        'Please fix the errors above before submitting.',
        isError: true,
      );
      return;
    }

    // Extra guard: check all dropdowns are selected
    if (provider.selectedItem == null ||
        provider.selectedThread == null ||
        provider.selectedLength == null ||
        provider.selectedHead == null ||
        provider.selectedColour == null ||
        provider.selectedParty == null ||
        provider.selectedUom == null ||
        provider.selectedMode == null ||
        provider.selectedLocation == null) {
      _showSnackbar(
        context,
        'Please select all required dropdown fields.',
        isError: true,
      );
      return;
    }

    final success = await provider.submit(
      quantity: _quantityController.text.trim(),
      rate:     _rateController.text.trim(),
    );

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E7D32),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Transaction Saved!',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2340),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The sales transaction has been\nsuccessfully recorded.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // back to dashboard
            },
            child: Text('Back to Dashboard',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _formKey.currentState!.reset();
              _quantityController.clear();
              _rateController.clear();
              _receiptController.clear();
              provider.resetForm();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('New Entry',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
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
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset form',
            onPressed: () {
              _formKey.currentState?.reset();
              _quantityController.clear();
              _rateController.clear();
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
        return _LoadingView();
      case FormLoadState.error:
        return _ErrorView(
          message: provider.loadError,
          onRetry: provider.loadOptions,
        );
      case FormLoadState.loaded:
        return _buildForm(provider);
    }
  }

  Widget _buildForm(SalesFormProvider provider) {
    final isSubmitting = provider.submitState == SubmitState.submitting;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── 1. General Information ──────────────
          SectionCard(
            title: 'GENERAL INFORMATION',
            icon: Icons.info_outline_rounded,
            accentColor: const Color(0xFF1565C0),
            children: [
              // Date (auto-set from device, read-only)
              AppTextField(
                label: 'Date',
                initialValue: provider.dateDisplay,
                readOnly: true,
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
              const SizedBox(height: 16),

              // Party — dropdown from Customer_Master
              AppDropdown<CustomerOption>(
                label: 'Party',
                value: provider.selectedParty,
                items: provider.customers,
                itemLabel: (c) => c.displayLabel,
                onChanged: provider.setParty,
                validator: (v) => v == null ? 'Please select a party' : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 2. Item Container ───────────────────
          SectionCard(
            title: 'ITEM DETAILS',
            icon: Icons.inventory_2_rounded,
            accentColor: const Color(0xFF00695C),
            children: [
              if (provider.loadState == FormLoadState.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Item Name
                AppDropdown<LookupOption>(
                  label: 'Item Name',
                  value: provider.selectedItem,
                  items: provider.options.items,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setItem,
                  validator: (v) => v == null ? 'Please select an item' : null,
                ),
                const SizedBox(height: 14),

                // Thread
                AppDropdown<LookupOption>(
                  label: 'Thread',
                  value: provider.selectedThread,
                  items: provider.options.threads,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setThread,
                  validator: (v) => v == null ? 'Please select a thread' : null,
                ),
                const SizedBox(height: 14),

                // Length
                AppDropdown<LookupOption>(
                  label: 'Length',
                  value: provider.selectedLength,
                  items: provider.options.lengths,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setLength,
                  validator: (v) => v == null ? 'Please select a length' : null,
                ),
                const SizedBox(height: 14),

                // Head
                AppDropdown<LookupOption>(
                  label: 'Head',
                  value: provider.selectedHead,
                  items: provider.options.heads,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setHead,
                  validator: (v) =>
                      v == null ? 'Please select a head type' : null,
                ),
                const SizedBox(height: 14),

                // Colour
                AppDropdown<LookupOption>(
                  label: 'Colour',
                  value: provider.selectedColour,
                  items: provider.options.colours,
                  itemLabel: (o) => o.label,
                  onChanged: provider.setColour,
                  validator: (v) => v == null ? 'Please select a colour' : null,
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ── 3. Transaction Details ──────────────
          SectionCard(
            title: 'TRANSACTION DETAILS',
            icon: Icons.point_of_sale_rounded,
            accentColor: const Color(0xFF6A1B9A),
            children: [
              // Quantity
              AppTextField(
                label: 'Quantity',
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                hintText: 'Enter quantity',
                prefixIcon:
                    const Icon(Icons.format_list_numbered_rounded, size: 18),
                onChanged: provider.setQuantity,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Quantity is required';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0)
                    return 'Enter a valid positive integer';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // UoM
              AppDropdown<String>(
                label: 'Unit of Measure (UoM)',
                value: provider.selectedUom,
                items: AppConstants.uomOptions,
                itemLabel: (s) => s,
                onChanged: provider.setUom,
                validator: (v) => v == null ? 'Please select a unit' : null,
              ),
              const SizedBox(height: 14),

              // Rate
              AppTextField(
                label: 'Rate',
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                hintText: '0.00',
                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                onChanged: provider.setRate,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Rate is required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid rate';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Mode
              AppDropdown<String>(
                label: 'Payment Mode',
                value: provider.selectedMode,
                items: AppConstants.modeOptions,
                itemLabel: (s) => s,
                onChanged: provider.setMode,
                validator: (v) =>
                    v == null ? 'Please select a payment mode' : null,
              ),
              const SizedBox(height: 14),

              // Receipt (optional)
              AppTextField(
                label: 'Receipt',
                controller: _receiptController,
                hintText: 'Receipt no. / reference (optional)',
                prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18),
                onChanged: provider.setReceipt,
              ),
              const SizedBox(height: 14),

              // Amount (auto-calculated, read-only)
              _AmountDisplay(amount: provider.amount),
            ],
          ),

          const SizedBox(height: 16),

          // ── 4. Additional Info ───────────────────
          SectionCard(
            title: 'ADDITIONAL INFO',
            icon: Icons.location_on_rounded,
            accentColor: Colors.grey.shade600,
            children: [
              // Location — dropdown
              AppDropdown<String>(
                label: 'Location',
                value: provider.selectedLocation,
                items: AppConstants.locationOptions,
                itemLabel: (s) => s,
                onChanged: provider.setLocation,
                validator: (v) => v == null ? 'Please select a location' : null,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Submit Button ───────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isSubmitting
                ? Container(
                    key: const ValueKey('loading'),
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    key: const ValueKey('submit'),
                    onPressed: () => _handleSubmit(provider),
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: const Text('Submit Transaction'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Auto-calculated amount display
// ─────────────────────────────────────────────

class _AmountDisplay extends StatelessWidget {
  final double amount;

  const _AmountDisplay({required this.amount});

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,##0.00', 'en_IN').format(amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1565C0).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_rounded, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(
            'Amount',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            '₹ $formatted',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(
              'Auto',
              style:
                  GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Loading & Error state views
// ─────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Loading form data…',
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Load',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2340),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

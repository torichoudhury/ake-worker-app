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
import '../../sales/providers/sales_form_provider.dart'; // For FormLoadState
import '../providers/movement_form_provider.dart';

class MovementScreen extends StatelessWidget {
  const MovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MovementFormProvider()..loadOptions(),
      child: const _MovementScreenContent(),
    );
  }
}

class _MovementScreenContent extends StatefulWidget {
  const _MovementScreenContent();

  @override
  State<_MovementScreenContent> createState() => _MovementScreenContentState();
}

class _MovementScreenContentState extends State<_MovementScreenContent> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _packetController = TextEditingController();
  final _perPacketController = TextEditingController();
  
  final _afterQuantityController = TextEditingController();
  final _afterPacketController = TextEditingController();
  final _afterPerPacketController = TextEditingController();

  final List<String> _activityOptions = [
    'Packing: Box to Bag',
    'OUT/IN (inc. Plating)',
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _packetController.dispose();
    _perPacketController.dispose();
    _afterQuantityController.dispose();
    _afterPacketController.dispose();
    _afterPerPacketController.dispose();
    super.dispose();
  }

  void _handleSubmit(MovementFormProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    
    final success = await provider.submit();
    if (!mounted) return;
    
    if (success) {
      _showSuccessDialog(provider);
    } else {
      _showSnackbar(context, provider.submitError, isError: true);
    }
  }

  void _showSuccessDialog(MovementFormProvider provider) {
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
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 48),
            ),
            const SizedBox(height: 20),
            Text('Movement Saved!', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A2340))),
            const SizedBox(height: 8),
            Text('Movement details successfully recorded.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
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
                  Text('Movement ID: ${provider.lastMovementId ?? 'N/A'}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A2340))),
                  const SizedBox(height: 4),
                  Text(provider.selectedActivity ?? 'Activity',
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
              _packetController.clear();
              _perPacketController.clear();
              _afterQuantityController.clear();
              _afterPacketController.clear();
              _afterPerPacketController.clear();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovementFormProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Movement', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A2340),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset form',
            onPressed: () {
              _formKey.currentState?.reset();
              _quantityController.clear();
              _packetController.clear();
              _perPacketController.clear();
              _afterQuantityController.clear();
              _afterPacketController.clear();
              _afterPerPacketController.clear();
              provider.resetForm();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(MovementFormProvider provider) {
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
              Text(provider.loadError, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => provider.loadOptions(), child: const Text('Retry')),
            ],
          ),
        );
      case FormLoadState.loaded:
        return _buildForm(provider);
    }
  }

  Widget _buildForm(MovementFormProvider provider) {
    final showCartSystem = provider.selectedActivity != null && !provider.isPackingActivity && !provider.isPlatingLocation;
    
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGeneralInfo(provider),
                  if (provider.selectedActivity != null) ...[
                    const SizedBox(height: 16),
                    _buildItemDetails(provider),
                    const SizedBox(height: 16),
                    if (provider.isPackingActivity)
                      _buildPackingQuantities(provider)
                    else
                      _buildCartItemInputs(provider),
                      
                    if (showCartSystem) ...[
                      const SizedBox(height: 16),
                      _buildMovementTable(provider),
                    ],
                  ]
                ],
              ),
            ),
          ),
        ),
        if (provider.selectedActivity != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)],
            ),
            child: ElevatedButton(
              onPressed: provider.isSubmitting ? null : () => _handleSubmit(provider),
              child: provider.isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Movement'),
            ),
          ),
      ],
    );
  }

  Widget _buildGeneralInfo(MovementFormProvider provider) {
    return SectionCard(
      title: 'General Information',
      icon: Icons.info_outline_rounded,
      children: [
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
        AppDropdown<String>(
          label: 'Activity',
          value: provider.selectedActivity,
          items: _activityOptions,
          itemLabel: (s) => s,
          onChanged: provider.setActivity,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        if (provider.selectedActivity != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppDropdown<String>(
                  label: 'From Location',
                  value: provider.fromLocation,
                  items: AppConstants.locationOptions,
                  itemLabel: (s) => s,
                  onChanged: provider.setFromLocation,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              if (!provider.isPackingActivity) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: AppDropdown<String>(
                    label: 'To Location',
                    value: provider.toLocation,
                    items: AppConstants.locationOptions,
                    itemLabel: (s) => s,
                    onChanged: provider.setToLocation,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildItemDetails(MovementFormProvider provider) {
    return SectionCard(
      title: 'Item Details',
      icon: Icons.category_rounded,
      children: [
        AppDropdown<LookupOption>(
          label: 'Item Name',
          value: provider.selectedItem,
          items: provider.items,
          itemLabel: (o) => o.label,
          onChanged: provider.setItem,
          // Only required if we haven't submitted yet and list is empty
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
        if (provider.isPlatingLocation) ...[
          const Divider(height: 32),
          Text('New Colour (After Plating)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          AppDropdown<LookupOption>(
            label: 'After Colour',
            value: provider.afterColour,
            items: provider.colours,
            itemLabel: (o) => o.label,
            onChanged: provider.setAfterColour,
            enabled: provider.selectedItem != null,
            hint: provider.selectedItem == null ? 'Select Item First' : null,
          ),
        ],
      ],
    );
  }

  // Fields for 'Packing: Bag to Box'
  Widget _buildPackingQuantities(MovementFormProvider provider) {
    return SectionCard(
      title: 'Packing Details',
      icon: Icons.inventory_2_rounded,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Quantity',
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                onChanged: provider.setQuantity,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Packet',
                controller: _packetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                onChanged: provider.setPacket,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppDropdown<String>(
                label: 'Packet UoM',
                value: provider.packetUom,
                items: AppConstants.uomOptions,
                itemLabel: (s) => s,
                onChanged: provider.setPacketUom,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Per Packet',
          controller: _perPacketController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: provider.setPerPacket,
        ),
      ],
    );
  }

  // Fields and 'Add to List' for Cart system
  Widget _buildCartItemInputs(MovementFormProvider provider) {
    final hasBeforeQty = provider.quantity != null && provider.selectedUom != null;
    final hasAfterQty = provider.afterQuantity != null && provider.afterUom != null && provider.afterColour != null;
    
    bool isValid = provider.selectedItem != null &&
        provider.selectedThread != null &&
        provider.selectedLength != null &&
        provider.selectedHead != null &&
        provider.selectedColour != null;
        
    if (provider.isPlatingLocation) {
      isValid = isValid && (hasBeforeQty || hasAfterQty);
    } else {
      isValid = isValid && hasBeforeQty;
    }

    return Column(
      children: [
        SectionCard(
          title: provider.isPlatingLocation ? 'Before Plating Quantity' : 'Movement Quantity',
          icon: Icons.analytics_rounded,
          children: [
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
                    onChanged: provider.setQuantity,
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
            AppTextField(
              label: 'Packet',
              controller: _packetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: provider.setPacket,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Per Packet',
              controller: _perPacketController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: provider.setPerPacket,
            ),
          ],
        ),
        if (provider.isPlatingLocation) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'After Plating Quantity',
            icon: Icons.auto_awesome_rounded,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: 'After Quantity',
                      controller: _afterQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      onChanged: provider.setAfterQuantity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppDropdown<String>(
                      label: 'UoM',
                      value: provider.afterUom,
                      items: AppConstants.uomOptions,
                      itemLabel: (s) => s,
                      onChanged: provider.setAfterUom,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'After Packet',
                controller: _afterPacketController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                onChanged: provider.setAfterPacket,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'After Per Packet',
                controller: _afterPerPacketController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: provider.setAfterPerPacket,
              ),
            ],
          ),
        ],
        if (!provider.isPlatingLocation) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isValid
                ? () {
                    provider.addMovementItem();
                    _quantityController.clear();
                    _packetController.clear();
                    _perPacketController.clear();
                    _afterQuantityController.clear();
                    _afterPacketController.clear();
                    _afterPerPacketController.clear();
                    FocusScope.of(context).unfocus();
                  }
                : null,
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Add to List'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMovementTable(MovementFormProvider provider) {
    if (provider.movementItems.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Added Items (${provider.movementItems.length})',
      icon: Icons.list_alt_rounded,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.movementItems.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = provider.movementItems[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: item.item.label,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1A2340)),
                    ),
                    TextSpan(
                      text: '  ${item.length.label} * ${item.thread.label} | ${item.head.label} | ${item.colour.label}',
                      style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (item.quantity != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('Before: ${item.quantity} ${item.uom}', style: GoogleFonts.inter(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    if (item.afterQuantity != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('After: ${item.afterQuantity} ${item.afterUom} (${item.afterColour?.label})', style: GoogleFonts.inter(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Remove Item',
                onPressed: () => provider.removeMovementItem(index),
              ),
            );
          },
        ),
      ],
    );
  }
}

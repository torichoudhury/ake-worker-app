import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/section_card.dart';
import '../../sales/models/dropdown_options_model.dart';
import '../providers/due_bills_provider.dart';

class DueBillsScreen extends StatelessWidget {
  const DueBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DueBillsProvider(),
      child: const _DueBillsScreenContent(),
    );
  }
}

class _DueBillsScreenContent extends StatefulWidget {
  const _DueBillsScreenContent();

  @override
  State<_DueBillsScreenContent> createState() => _DueBillsScreenContentState();
}

class _DueBillsScreenContentState extends State<_DueBillsScreenContent> {
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DueBillsProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showSettlePopup(BuildContext context, dynamic bill, DueBillsProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SettlePopup(bill: bill, provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DueBillsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Due Bill Receipt', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A2340),
      ),
      body: Column(
        children: [
          _buildSearchSection(provider),
          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (provider.error.isNotEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(provider.error, style: GoogleFonts.inter(color: Colors.red.shade700)),
                ),
              ),
            )
          else if (provider.dueBills.isNotEmpty)
            Expanded(child: _buildResultsTable(provider)),
        ],
      ),
    );
  }

  Widget _buildSearchSection(DueBillsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppDropdown<CustomerOption>(
                  label: 'Customer Name',
                  value: provider.selectedCustomer,
                  items: provider.customers,
                  itemLabel: (c) => c.alias,
                  onChanged: provider.setSelectedCustomer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: provider.setSearchPhone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              FocusScope.of(context).unfocus();
              provider.search();
            },
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search Dues'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable(DueBillsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionCard(
        title: 'Pending Bills',
        icon: Icons.receipt_long_rounded,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.dueBills.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bill = provider.dueBills[index];
              return _DueBillItem(
                bill: bill,
                provider: provider,
                onSettle: () => _showSettlePopup(context, bill, provider),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DueBillItem extends StatefulWidget {
  final dynamic bill;
  final DueBillsProvider provider;
  final VoidCallback onSettle;

  const _DueBillItem({required this.bill, required this.provider, required this.onSettle});

  @override
  State<_DueBillItem> createState() => _DueBillItemState();
}

class _DueBillItemState extends State<_DueBillItem> {
  List<dynamic>? _history;
  bool _isLoading = false;

  Future<void> _fetchHistory() async {
    if (_history != null || _isLoading) return;
    setState(() => _isLoading = true);
    final transactionId = int.tryParse(widget.bill['transaction_id'].toString()) ?? 0;
    final history = await widget.provider.fetchHistory(transactionId);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      onExpansionChanged: (expanded) {
        if (expanded) _fetchHistory();
      },
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        '${widget.bill['party']}  •  ${widget.bill['date']}',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1A2340)),
      ),
      subtitle: Text('Total: ₹${widget.bill['amount']}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Due: ₹${widget.bill['due_amount']}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red.shade700),
        ),
      ),
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )
        else if (_history != null && _history!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payment History',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: _history!.map((h) {
                      final dateStr = h['date']?.toString() ?? 'N/A';
                      final amount = h['amount']?.toString() ?? '0';
                      final rem = h['due_amount']?.toString() ?? '0';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 4,
                          children: [
                            Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                            Wrap(
                              spacing: 16,
                              children: [
                                Text('- ₹$amount', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                Text('Rem: ₹$rem', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          )
        else if (_history != null && _history!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('No previous payments recorded.', style: GoogleFonts.inter(color: Colors.grey.shade500)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: widget.onSettle,
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('Settle Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SettlePopup extends StatefulWidget {
  final dynamic bill;
  final DueBillsProvider provider;

  const _SettlePopup({required this.bill, required this.provider});

  @override
  State<_SettlePopup> createState() => _SettlePopupState();
}

class _SettlePopupState extends State<_SettlePopup> {
  final _settleController = TextEditingController();
  final _dateController = TextEditingController();
  double _balanceSettled = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _settleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dueAmount = double.tryParse(widget.bill['due_amount'].toString()) ?? 0.0;
    final double newOutstanding = dueAmount - _balanceSettled;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Settle Due Bill', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoRow('Date', widget.bill['date']),
          const SizedBox(height: 8),
          _buildInfoRow('Total Amount', '₹${widget.bill['amount']}'),
          const SizedBox(height: 8),
          _buildInfoRow('Current Due', '₹$dueAmount', color: Colors.red.shade700),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Balance Settled',
            controller: _settleController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            onChanged: (val) {
              setState(() {
                _balanceSettled = double.tryParse(val) ?? 0.0;
              });
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: newOutstanding <= 0 ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: newOutstanding <= 0 ? Colors.green.shade200 : Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Outstanding', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '₹${newOutstanding.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: newOutstanding <= 0 ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _balanceSettled <= 0
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final transactionId = int.tryParse(widget.bill['transaction_id'].toString()) ?? 0;
                  final success = await widget.provider.settle(
                    transactionId, 
                    _balanceSettled,
                    date: _dateController.text.trim().isNotEmpty ? _dateController.text.trim() : null,
                  );
                  
                  if (!mounted) return;
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Payment recorded successfully!'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  } else {
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.provider.error),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A2340),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Payment'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: color ?? const Color(0xFF1A2340))),
      ],
    );
  }
}

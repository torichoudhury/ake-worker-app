import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/contact_form_provider.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_dropdown.dart';

class ContactFormScreen extends StatelessWidget {
  const ContactFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContactFormProvider(),
      child: const _ContactFormView(),
    );
  }
}

class _ContactFormView extends StatefulWidget {
  const _ContactFormView();

  @override
  State<_ContactFormView> createState() => _ContactFormViewState();
}

class _ContactFormViewState extends State<_ContactFormView> {
  final _aliasController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _aliasController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _whatsappController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    final provider = context.read<ContactFormProvider>();
    FocusScope.of(context).unfocus();
    final success = await provider.submit();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact successfully created!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.submitError, 
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          padding: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactFormProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Add Customer / Vendor', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type Selector
            Row(
              children: [
                Expanded(
                  child: AppDropdown<String>(
                    label: 'Contact Type',
                    value: provider.type,
                    items: const ['customer', 'vendor'],
                    itemLabel: (s) => s.toUpperCase(),
                    onChanged: (v) {
                      if (v != null) provider.setType(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AppTextField(
                    label: 'Short Name (Alias) *',
                    controller: _aliasController,
                    onChanged: provider.setAlias,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Full Name *',
                    controller: _nameController,
                    onChanged: provider.setName,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Address',
                    controller: _addressController,
                    onChanged: provider.setAddress,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'GST Number',
                    controller: _gstController,
                    onChanged: provider.setGst,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'WhatsApp Number (or Phone)',
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: provider.setWhatsapp,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Phone Number(s)',
                    hintText: 'Comma separated for multiple (e.g. 9876543210, 1234567890)',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: provider.setPhone,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: provider.setEmail,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: provider.isSubmitting ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: provider.type == 'customer' ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A),
              ),
              child: provider.isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Save ${provider.type.toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (provider.submitError.isNotEmpty)
              Text(
                provider.submitError,
                style: GoogleFonts.inter(color: Colors.red.shade600, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

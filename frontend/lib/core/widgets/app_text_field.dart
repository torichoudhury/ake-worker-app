// lib/core/widgets/app_text_field.dart
// Styled TextFormField wrapper for consistent look across the app

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool readOnly;
  final bool enabled;
  final String? hintText;
  final int? maxLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.hintText,
    this.maxLines = 1,
    this.suffixIcon,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        // Visually disabled style
        fillColor: (!enabled || readOnly)
            ? Colors.grey.shade50
            : Colors.white,
        labelStyle: GoogleFonts.inter(
          color: (!enabled || readOnly)
              ? Colors.grey.shade400
              : Colors.grey.shade600,
          fontSize: 16,
        ),
      ),
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

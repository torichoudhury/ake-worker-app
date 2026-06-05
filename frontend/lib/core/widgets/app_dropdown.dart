// lib/core/widgets/app_dropdown.dart
// Generic, styled dropdown widget used throughout the form.
// Wraps DropdownButtonFormField with consistent theming.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final String? hint;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      hint: Text(
        hint ?? 'Select $label',
        style: GoogleFonts.inter(
          color: Colors.grey.shade400,
          fontSize: 16,
        ),
      ),
      decoration: InputDecoration(
        labelText: label,
        enabled: enabled,
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemLabel(item),
            style: GoogleFonts.inter(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      icon: Icon(
        enabled ? Icons.keyboard_arrow_down_rounded : Icons.lock_rounded,
        color: enabled
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade400,
        size: enabled ? 24 : 20,
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
    );
  }
}

import 'package:flutter/material.dart';

class DarkInputField extends StatelessWidget {
  const DarkInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.prefixText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.onFieldSubmitted,
    this.validator,
    this.focusColor = const Color(0xFF1565C0),
    this.textStyle,
    this.hintStyle,
  });

  final TextEditingController controller;
  final String hintText;
  final String? label;
  final String? prefixText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final Color focusColor;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final input = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLength: maxLength,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: textStyle ??
          const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF252525),
        hintText: hintText,
        hintStyle: hintStyle ?? const TextStyle(color: Colors.white24, fontFamily: 'Poppins'),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: Colors.white54,
          fontFamily: 'Poppins',
          fontSize: 16,
        ),
        counterText: '',
        errorText: errorText,
        errorStyle: const TextStyle(color: Color(0xFFFF5252), fontFamily: 'Poppins'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5252)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
      ),
    );

    if (label == null) return input;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 8),
        input,
      ],
    );
  }
}

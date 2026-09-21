import 'package:flutter/services.dart';

/// Capitalizes just the first letter of the field's text as the user types
/// (even if they type it lowercase), leaving the rest of what they typed
/// untouched.
class FirstLetterCapitalizeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final capitalized = text[0].toUpperCase() + text.substring(1);
    if (capitalized == text) return newValue;
    return newValue.copyWith(text: capitalized);
  }
}

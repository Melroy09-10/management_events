import 'package:intl/intl.dart';

final _wholeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _decimalFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// Formats [amount] using Indian digit grouping, e.g. ₹1,500 or ₹1,00,000.
/// Only shows decimals when the amount actually has a fractional part.
String formatCurrency(double amount) {
  final isWhole = amount == amount.roundToDouble();
  return isWhole ? _wholeFormat.format(amount) : _decimalFormat.format(amount);
}

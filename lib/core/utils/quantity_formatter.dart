/// Helper to format quantities cleanly across the application.
/// Formats whole numbers without decimals (e.g. 5.0 -> '5'),
/// and preserves fractional decimals (e.g. 5.6 -> '5.6', 5.65 -> '5.65').
String formatQuantity(num? quantity) {
  if (quantity == null) return '0';
  if (quantity % 1 == 0) {
    return quantity.toInt().toString();
  }
  // Trim trailing decimal zeroes if needed
  String str = quantity.toString();
  if (str.contains('.')) {
    str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return str;
}

extension QuantityFormatting on num {
  String toQtyString() => formatQuantity(this);
}

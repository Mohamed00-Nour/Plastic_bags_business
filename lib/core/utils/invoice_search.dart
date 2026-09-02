String _normalizeInvoiceSearchText(Object? value) {
  return (value?.toString() ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('#', '')
      .trim();
}

/// Matches an invoice against the fields users commonly know when looking it
/// up. This is intentionally local so searching does not trigger extra
/// Firestore reads.
bool invoiceMatchesHistorySearch(
  Map<String, dynamic> invoice,
  String rawQuery,
) {
  final query = _normalizeInvoiceSearchText(rawQuery);
  if (query.isEmpty) return true;

  final searchableText = [
    invoice['invoiceNumber'],
    invoice['clientName'],
    invoice['clientPhone'],
    invoice['phone'],
    invoice['paymentMethod'],
  ].map(_normalizeInvoiceSearchText).join(' ');

  return searchableText.contains(query);
}

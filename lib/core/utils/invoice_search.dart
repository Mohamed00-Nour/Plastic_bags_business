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

/// The serial number of an invoice ("50" or "#50" → 50), or null for
/// old-style numbers such as "INV-1730000000".
int? invoiceSerialNumber(Object? invoiceNumber) {
  var text = invoiceNumber?.toString().trim() ?? '';
  if (text.startsWith('#')) text = text.substring(1).trim();
  if (!RegExp(r'^\d{1,9}$').hasMatch(text)) return null;
  return int.parse(text);
}

DateTime? _invoiceTime(Map<String, dynamic> invoice) {
  final raw = invoice['createdAt'] ?? invoice['date'];
  if (raw is DateTime) return raw;
  try {
    // Firestore Timestamp, without importing cloud_firestore here.
    final converted = (raw as dynamic)?.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Sorts invoices newest number first (#50, #11, #3, …). Old-style
/// numbers come after the serial ones, newest first by date.
int compareInvoicesByNumberDesc(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final na = invoiceSerialNumber(a['invoiceNumber']);
  final nb = invoiceSerialNumber(b['invoiceNumber']);
  if (na != null && nb != null && na != nb) return nb.compareTo(na);
  if (na != null && nb == null) return -1;
  if (na == null && nb != null) return 1;
  final ta = _invoiceTime(a);
  final tb = _invoiceTime(b);
  if (ta == null || tb == null) return 0;
  return tb.compareTo(ta);
}

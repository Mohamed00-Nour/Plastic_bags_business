/// Signed client balances: positive is debt; negative is credit for the client.
class ClientBalance {
  ClientBalance._();

  static double invoiceChange({
    required double totalAmount,
    required double paidAmount,
  }) {
    if (!totalAmount.isFinite || totalAmount < 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount');
    }
    if (!paidAmount.isFinite || paidAmount < 0) {
      throw ArgumentError.value(paidAmount, 'paidAmount');
    }
    return totalAmount - paidAmount;
  }

  /// Reverse the amount actually posted, including legacy invoices whose
  /// overpayment was clamped to zero. New postings use [invoiceChange].
  static double recordedInvoiceChange(Map<String, dynamic> invoice) {
    final recorded = invoice['remainingAmount'];
    if (recorded != null) return _asDouble(recorded);
    return invoiceChange(
      totalAmount: _asDouble(invoice['totalAmount']),
      paidAmount: _asDouble(invoice['paidAmount']),
    );
  }

  static String label(double balance, {required bool isArabic}) {
    if (balance < 0) return isArabic ? 'رصيد دائن للعميل' : 'Client Credit';
    return isArabic ? 'رصيد العميل' : 'Client Balance';
  }

  static String invoiceChangeLabel(double change, {required bool isArabic}) {
    if (change < 0) {
      return isArabic ? 'زيادة دفعة الفاتورة' : 'Invoice Overpayment';
    }
    return isArabic ? 'المتبقي من الفاتورة' : 'Invoice Remaining';
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

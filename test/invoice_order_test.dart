import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/core/utils/invoice_search.dart';

void main() {
  test('invoices sort by serial number, highest first', () {
    // Created in this order: #1, #2, #3, #50, then #11.
    final created = ['1', '2', '3', '50', '11'];
    final invoices = [
      for (var i = 0; i < created.length; i++)
        {
          'invoiceNumber': created[i],
          'createdAt': DateTime(2026, 11, 1).add(Duration(minutes: i)),
        },
    ]..sort(compareInvoicesByNumberDesc);

    expect(invoices.map((i) => i['invoiceNumber']), [
      '50',
      '11',
      '3',
      '2',
      '1',
    ]);
  });

  test('old-style numbers go after serial ones, newest first', () {
    final invoices = [
      {'invoiceNumber': 'INV-100', 'createdAt': DateTime(2025, 1, 1)},
      {'invoiceNumber': '#2', 'createdAt': DateTime(2026, 1, 1)},
      {'invoiceNumber': 'INV-200', 'createdAt': DateTime(2025, 6, 1)},
      {'invoiceNumber': '10', 'createdAt': DateTime(2026, 1, 2)},
    ]..sort(compareInvoicesByNumberDesc);

    expect(invoices.map((i) => i['invoiceNumber']), [
      '10',
      '#2',
      'INV-200',
      'INV-100',
    ]);
  });
}

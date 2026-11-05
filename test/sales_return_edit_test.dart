import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';

import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore store;
  late ClientInvoiceBalanceSyncService service;
  late String returnId;

  Map<String, dynamic> item(String productId, num qty, {num price = 10}) => {
    'productId': productId,
    'productName': productId == 'p1' ? 'Bag' : 'Box',
    'quantity': qty,
    'price': price,
    'total': qty * price,
  };

  /// Saves a return of 3 bags worth 30 with no refund. The fake store can't
  /// apply FieldValue.increment, so the balance and stock the real save would
  /// produce are written as plain numbers afterwards.
  setUp(() async {
    store = MemoryFirestore();
    store.documents['clients/client-1'] = {'name': 'Client', 'balance': 0.0};
    store.documents['products/p1'] = {'name': 'Bag', 'stockQuantity': 10.0};
    store.documents['products/p2'] = {'name': 'Box', 'stockQuantity': 20.0};
    service = ClientInvoiceBalanceSyncService(firestore: store);
    returnId = await service.processSalesReturn(
      clientId: 'client-1',
      clientName: 'Client',
      returnNumber: '7',
      returnedItems: [item('p1', 3)],
      subtotal: 30,
      discount: 0,
      returnTotalAmount: 30,
      refundAmount: 0,
      returnDate: DateTime(2026, 11, 1),
    );
    store.documents['clients/client-1']!['balance'] = -30.0;
    store.documents['products/p1']!['stockQuantity'] = 13.0;
  });

  Future<void> edit(
    List<Map<String, dynamic>> items, {
    double discount = 0,
    double refund = 0,
    DateTime? date,
    String reason = '',
  }) {
    final subtotal = items.fold<double>(
      0,
      (acc, i) => acc + (i['total'] as num).toDouble(),
    );
    return service.updateSalesReturn(
      returnId: returnId,
      returnedItems: items,
      subtotal: subtotal,
      discount: discount,
      returnTotalAmount: subtotal - discount,
      refundAmount: refund,
      returnDate: date ?? DateTime(2026, 11, 1),
      reason: reason,
    );
  }

  double balance() =>
      (store.documents['clients/client-1']!['balance'] as num).toDouble();
  double stock(String id) =>
      (store.documents['products/$id']!['stockQuantity'] as num).toDouble();
  List<Map<String, dynamic>> rows() => [
    for (final e in store.documents.entries)
      if (e.key.startsWith('clients/client-1/balanceHistory/') &&
          e.value['invoiceId'] == returnId)
        e.value,
  ];

  test('returning more adds the extra to stock and to the credit', () async {
    await edit([item('p1', 5)]);

    expect(stock('p1'), 15.0);
    expect(balance(), -50.0);
    final saved = store.documents['return_invoices/$returnId']!;
    expect(saved['totalAmount'], 50.0);
    expect(saved['returnNumber'], '7');
    expect((saved['items'] as List).single['quantity'], 5);
    expect(store.documents['sales_returns/$returnId']!['totalAmount'], 50.0);
    expect(rows().single['amount'], 50.0);
  });

  test('returning less takes the difference out of stock again', () async {
    await edit([item('p1', 1)]);

    expect(stock('p1'), 11.0);
    expect(balance(), -10.0);
    final log = store.documents.values.singleWhere(
      (d) => d['note'] == 'Sales return edit #7',
    );
    expect(log['type'], 'outgoing');
    expect(log['quantity'], 2.0);
    expect(log['stockBefore'], 13.0);
    expect(log['stockAfter'], 11.0);
  });

  test('swapping the product moves stock for both products', () async {
    await edit([item('p2', 2)]);

    expect(stock('p1'), 10.0);
    expect(stock('p2'), 22.0);
    expect(balance(), -20.0);
  });

  test('adding and removing a cash refund updates balance and rows', () async {
    await edit([item('p1', 3)], refund: 10);
    expect(balance(), -20.0);
    expect(rows(), hasLength(2));
    expect(stock('p1'), 13.0, reason: 'same items, stock unchanged');

    await edit([item('p1', 3)]);
    expect(balance(), -30.0);
    expect(rows(), hasLength(1));
  });

  test('a discount lowers the credit', () async {
    await edit([item('p1', 3)], discount: 5);

    expect(balance(), -25.0);
    expect(store.documents['return_invoices/$returnId']!['discount'], 5.0);
  });

  test('changing the date moves the history rows to the new date', () async {
    await edit([item('p1', 3)], date: DateTime(2026, 10, 20));

    expect(
      rows().single['timestamp'],
      Timestamp.fromDate(DateTime(2026, 10, 20)),
    );
    expect(
      store.documents['return_invoices/$returnId']!['date'],
      Timestamp.fromDate(DateTime(2026, 10, 20)),
    );
    expect(balance(), -30.0);
  });

  test('notes are saved', () async {
    await edit([item('p1', 3)], reason: 'damaged');

    expect(store.documents['return_invoices/$returnId']!['notes'], 'damaged');
  });

  test('an invoice with the same number keeps its history', () async {
    final invoice = await service.createSalesInvoice(
      clientId: 'client-1',
      clientName: 'Client',
      invoiceNumber: '7',
      paymentMethod: 'Cash',
      items: [],
      subtotal: 100,
      discount: 0,
      totalAmount: 100,
      paidAmount: 0,
      remainingAmount: 100,
      invoiceDate: DateTime(2026, 11, 2),
    );
    store.documents['clients/client-1']!['balance'] = 70.0;

    await edit([item('p1', 5)]);

    expect(balance(), 50.0);
    expect(
      store.documents.values.where(
        (d) => d['invoiceId'] == invoice.invoiceId && d['type'] != null,
      ),
      isNotEmpty,
    );
  });

  test('editing a deleted return fails and changes nothing', () async {
    store.documents.remove('return_invoices/$returnId');

    await expectLater(edit([item('p1', 5)]), throwsA(isA<StateError>()));

    expect(stock('p1'), 13.0);
    expect(balance(), -30.0);
    expect(rows().single['amount'], 30.0);
  });
}

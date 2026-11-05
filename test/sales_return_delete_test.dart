import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';
import 'package:store_manager/services/sales_invoice_actions_service.dart';

import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore store;
  late ClientInvoiceBalanceSyncService service;

  setUp(() {
    store = MemoryFirestore();
    store.documents['clients/client-1'] = {'name': 'Client', 'balance': 0.0};
    store.documents['products/p1'] = {'name': 'Bag', 'stockQuantity': 10.0};
    service = ClientInvoiceBalanceSyncService(firestore: store);
  });

  /// Saves a return of 3 bags. The fake store can't apply
  /// FieldValue.increment, so the balance and stock the real save would
  /// produce are written as plain numbers afterwards.
  Future<String> createReturn({
    String number = '1',
    double total = 40,
    double refund = 0,
    double balanceAfter = -40,
  }) async {
    final id = await service.processSalesReturn(
      clientId: 'client-1',
      clientName: 'Client',
      returnNumber: number,
      returnedItems: [
        {'productId': 'p1', 'productName': 'Bag', 'quantity': 3},
      ],
      subtotal: total,
      discount: 0,
      returnTotalAmount: total,
      refundAmount: refund,
      returnDate: DateTime(2026, 11, 5),
    );
    store.documents['clients/client-1']!['balance'] = balanceAfter;
    store.documents['products/p1']!['stockQuantity'] = 13.0;
    return id;
  }

  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    return result;
  }

  Future<bool> deleteReturn(
    WidgetTester tester,
    String id, {
    bool confirm = true,
  }) async {
    final context = await host(tester);
    final deletion = SalesInvoiceActionsService.deleteSalesReturn(
      context: context,
      database: store,
      returnData: {...?store.documents['return_invoices/$id'], 'id': id},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(confirm ? 'تأكيد الحذف' : 'إلغاء'));
    await tester.pumpAndSettle();
    return deletion;
  }

  List<Map<String, dynamic>> history() => [
    for (final entry in store.documents.entries)
      if (entry.key.startsWith('clients/client-1/balanceHistory/')) entry.value,
  ];

  testWidgets('deleting a return undoes balance, stock, history and number', (
    tester,
  ) async {
    final id = await createReturn();
    expect(history().where((r) => r['invoiceId'] == id), hasLength(1));

    expect(await deleteReturn(tester, id), isTrue);

    expect(store.documents.containsKey('return_invoices/$id'), isFalse);
    expect(store.documents.containsKey('sales_returns/$id'), isFalse);
    // The return lowered the balance by 40; deleting adds it back.
    expect(store.documents['clients/client-1']!['balance'], 0.0);
    // The 3 returned bags leave stock again.
    expect(store.documents['products/p1']!['stockQuantity'], 10.0);
    expect(history().where((r) => r['invoiceId'] == id), isEmpty);
    expect(store.documents.containsKey('invoice_numbers/return_1'), isFalse);

    final log = store.documents.entries.singleWhere(
      (e) =>
          e.key.startsWith('stock_logs/') &&
          e.value['note'] == 'Sales return deletion #1',
    );
    expect(log.value['type'], 'outgoing');
    expect(log.value['stockBefore'], 13.0);
    expect(log.value['stockAfter'], 10.0);
  });

  testWidgets('a return with a cash refund only reverses the net credit', (
    tester,
  ) async {
    // Return 40, 10 paid back in cash: the balance went down by 30.
    final id = await createReturn(refund: 10, balanceAfter: -30);
    expect(history().where((r) => r['invoiceId'] == id), hasLength(2));

    expect(await deleteReturn(tester, id), isTrue);

    expect(store.documents['clients/client-1']!['balance'], 0.0);
    expect(history().where((r) => r['invoiceId'] == id), isEmpty);
  });

  testWidgets('the deleted number can be used for a new return', (
    tester,
  ) async {
    final id = await createReturn(number: '4');
    expect(await deleteReturn(tester, id), isTrue);

    final newId = await createReturn(number: '4');
    expect(store.documents['invoice_numbers/return_4']!['documentId'], newId);
  });

  testWidgets('an invoice with the same number is not touched', (tester) async {
    final invoice = await service.createSalesInvoice(
      clientId: 'client-1',
      clientName: 'Client',
      invoiceNumber: '1',
      paymentMethod: 'Cash',
      items: [],
      subtotal: 100,
      discount: 0,
      totalAmount: 100,
      paidAmount: 0,
      remainingAmount: 100,
      invoiceDate: DateTime(2026, 11, 5),
    );
    final id = await createReturn(number: '1', balanceAfter: 60);

    expect(await deleteReturn(tester, id), isTrue);

    expect(
      store.documents.containsKey('sales_invoices/${invoice.invoiceId}'),
      isTrue,
    );
    expect(store.documents.containsKey('invoice_numbers/sales_1'), isTrue);
    expect(
      history().where((r) => r['invoiceId'] == invoice.invoiceId),
      isNotEmpty,
    );
    expect(store.documents['clients/client-1']!['balance'], 100.0);
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    final id = await createReturn();

    expect(await deleteReturn(tester, id, confirm: false), isFalse);

    expect(store.documents.containsKey('return_invoices/$id'), isTrue);
    expect(store.documents['clients/client-1']!['balance'], -40.0);
    expect(store.documents['products/p1']!['stockQuantity'], 13.0);
    expect(history().where((r) => r['invoiceId'] == id), hasLength(1));
  });

  testWidgets('deleting an already deleted return changes nothing', (
    tester,
  ) async {
    final id = await createReturn();
    expect(await deleteReturn(tester, id), isTrue);

    expect(await deleteReturn(tester, id), isFalse);

    expect(store.documents['clients/client-1']!['balance'], 0.0);
    expect(store.documents['products/p1']!['stockQuantity'], 10.0);
  });
}

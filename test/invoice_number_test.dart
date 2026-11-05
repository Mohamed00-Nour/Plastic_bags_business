import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';
import 'package:store_manager/services/invoice_number_service.dart';
import 'package:store_manager/services/sales_invoice_actions_service.dart';

import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore store;
  late ClientInvoiceBalanceSyncService service;
  late InvoiceNumberService numbers;

  setUp(() {
    store = MemoryFirestore();
    store.documents['clients/client-1'] = {'name': 'Client', 'balance': 0.0};
    service = ClientInvoiceBalanceSyncService(firestore: store);
    numbers = InvoiceNumberService(firestore: store);
  });

  Future<String> createInvoice(
    String number, {
    String client = 'client-1',
  }) async {
    final result = await service.createSalesInvoice(
      clientId: client,
      clientName: 'Client',
      invoiceNumber: number,
      paymentMethod: 'Cash',
      items: [],
      subtotal: 100,
      discount: 0,
      totalAmount: 100,
      paidAmount: 0,
      remainingAmount: 100,
      invoiceDate: DateTime(2026, 11, 5),
    );
    return result.invoiceId;
  }

  Future<String> createReturn(String number, {String client = 'client-1'}) {
    return service.processSalesReturn(
      clientId: client,
      clientName: 'Client',
      returnNumber: number,
      returnedItems: [],
      subtotal: 40,
      discount: 0,
      returnTotalAmount: 40,
      refundAmount: 0,
      returnDate: DateTime(2026, 11, 5),
    );
  }

  int countDocs(String collection) =>
      store.documents.keys
          .where(
            (k) =>
                k.startsWith('$collection/') &&
                k.split('/').length == collection.split('/').length + 1,
          )
          .length;

  bool reserved(String id) =>
      store.documents.containsKey('invoice_numbers/$id');

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

  Future<void> deleteInvoice(WidgetTester tester, String id) async {
    final context = await host(tester);
    final deletion = SalesInvoiceActionsService.deleteSalesInvoice(
      context: context,
      database: store,
      invoiceData: {...store.documents['sales_invoices/$id']!, 'id': id},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الحذف'));
    await tester.pumpAndSettle();
    expect(await deletion, isTrue);
  }

  group('parse', () {
    test('accepts whole numbers above zero, with or without #', () {
      expect(InvoiceNumberService.parse('5'), 5);
      expect(InvoiceNumberService.parse('#5'), 5);
      expect(InvoiceNumberService.parse(' 12 '), 12);
      expect(InvoiceNumberService.parse('007'), 7);
    });

    test('rejects everything else', () {
      for (final bad in [null, '', ' ', '0', '-1', '1.5', 'abc', 'INV-123']) {
        expect(InvoiceNumberService.parse(bad), isNull, reason: '$bad');
      }
    });
  });

  test('the first suggested number is 1', () async {
    expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 1);
    expect(await numbers.suggestNext(InvoiceSequence.salesReturn), 1);
  });

  test('1, 2, 3, skip 4, then 5 — suggestion continues at 6', () async {
    await createInvoice('1');
    expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 2);
    await createInvoice('2');
    await createInvoice('3');
    expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 4);
    await createInvoice('5');

    expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 6);
    expect(reserved('sales_4'), isFalse);
    for (final n in [1, 2, 3, 5]) {
      expect(reserved('sales_$n'), isTrue);
    }
  });

  test('a skipped number can be used later', () async {
    for (final n in ['1', '2', '3', '5']) {
      await createInvoice(n);
    }
    final id = await createInvoice('4');
    expect(store.documents['sales_invoices/$id']!['invoiceNumber'], '4');
    expect(store.documents['invoice_numbers/sales_4']!['documentId'], id);
    // Using a lower number does not move the suggestion back.
    expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 6);
  });

  test('"#7" typed with a hash is saved as 7', () async {
    final id = await createInvoice('#7');
    expect(reserved('sales_7'), isTrue);
    expect(store.documents['sales_invoices/$id']!['invoiceNumber'], '#7');
  });

  test('a duplicate invoice number is rejected and nothing is saved', () async {
    await createInvoice('1');
    await createInvoice('2');
    final balanceBefore = store.documents['clients/client-1']!['balance'];
    final invoicesBefore = countDocs('sales_invoices');
    final historyBefore = countDocs('clients/client-1/balanceHistory');

    await expectLater(
      createInvoice('2'),
      throwsA(
        isA<DuplicateInvoiceNumberException>()
            .having((e) => e.number, 'number', 2)
            .having((e) => e.nextAvailable, 'nextAvailable', 3),
      ),
    );

    expect(store.documents['clients/client-1']!['balance'], balanceBefore);
    expect(countDocs('sales_invoices'), invoicesBefore);
    expect(countDocs('clients/client-1/balanceHistory'), historyBefore);
  });

  test('a number is unique across clients', () async {
    store.documents['clients/client-2'] = {'name': 'Other', 'balance': 0.0};
    await createInvoice('1');
    await expectLater(
      createInvoice('1', client: 'client-2'),
      throwsA(isA<DuplicateInvoiceNumberException>()),
    );
  });

  test('old-style numbers are not part of the sequence', () async {
    await createInvoice('INV-82551453');
    await createInvoice('INV-82551453');
    expect(countDocs('invoice_numbers'), 0);
    expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 1);
  });

  group('sales returns', () {
    test('have their own sequence', () async {
      await createInvoice('1');
      await createInvoice('2');
      expect(await numbers.suggestNext(InvoiceSequence.salesReturn), 1);

      final returnId = await createReturn('1');
      expect(reserved('return_1'), isTrue);
      expect(
        store.documents['invoice_numbers/return_1']!['documentId'],
        returnId,
      );
      expect(
        store.documents['return_invoices/$returnId']!['returnNumber'],
        '1',
      );
      expect(await numbers.suggestNext(InvoiceSequence.salesReturn), 2);
      expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 3);
    });

    test(
      'a duplicate return number is rejected and nothing is saved',
      () async {
        final firstId = await createReturn('1');
        await expectLater(
          createReturn('1'),
          throwsA(
            isA<DuplicateInvoiceNumberException>().having(
              (e) => e.nextAvailable,
              'nextAvailable',
              2,
            ),
          ),
        );
        expect(countDocs('return_invoices'), 1);
        // The number still belongs to the first return.
        expect(
          store.documents['invoice_numbers/return_1']!['documentId'],
          firstId,
        );
      },
    );

    test('a failed save frees the number again', () async {
      // Saving fails because the client doesn't exist.
      await expectLater(
        createReturn('3', client: 'missing-client'),
        throwsA(isA<StateError>()),
      );
      expect(reserved('return_3'), isFalse);
      expect(countDocs('return_invoices'), 0);
      // The number can be used for the next attempt.
      await createReturn('3');
      expect(reserved('return_3'), isTrue);
    });
  });

  group('deleting an invoice', () {
    testWidgets('frees its number so it can be used again', (tester) async {
      await createInvoice('1');
      final secondId = await createInvoice('2');

      await deleteInvoice(tester, secondId);

      expect(reserved('sales_2'), isFalse);
      expect(reserved('sales_1'), isTrue);
      // The suggestion does not go back; #2 can still be typed in.
      expect(await numbers.suggestNext(InvoiceSequence.salesInvoice), 3);
      final newId = await createInvoice('2');
      expect(store.documents['invoice_numbers/sales_2']!['documentId'], newId);
    });

    testWidgets('keeps the history of a return with the same number', (
      tester,
    ) async {
      final invoiceId = await createInvoice('5');
      final returnId = await createReturn('5');
      // The fake store can't apply FieldValue.increment; use a plain number.
      store.documents['clients/client-1']!['balance'] = 60.0;

      await deleteInvoice(tester, invoiceId);

      final remaining = [
        for (final entry in store.documents.entries)
          if (entry.key.startsWith('clients/client-1/balanceHistory/'))
            entry.value,
      ];
      expect(
        remaining.where((r) => r['invoiceId'] == returnId),
        isNotEmpty,
        reason: 'return #5 history must survive deleting invoice #5',
      );
      expect(remaining.where((r) => r['invoiceId'] == invoiceId), isEmpty);
      expect(reserved('return_5'), isTrue);
      expect(reserved('sales_5'), isFalse);
    });

    testWidgets('does not free a number owned by another invoice', (
      tester,
    ) async {
      final id = await createInvoice('1');
      // Simulate the reservation belonging to a different document.
      store.documents['invoice_numbers/sales_1']!['documentId'] = 'other';

      await deleteInvoice(tester, id);

      expect(reserved('sales_1'), isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/core/utils/client_balance.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';
import 'package:store_manager/services/sales_invoice_actions_service.dart';
import 'package:store_manager/services/sales_invoice_image_service.dart';
import 'package:store_manager/services/sales_invoice_update_service.dart';
import 'package:store_manager/services/whatsapp_invoice_share_service.dart';

import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore store;
  late ClientInvoiceBalanceSyncService service;

  setUp(() {
    store = MemoryFirestore();
    store.documents['clients/client-1'] = {'name': 'Client', 'balance': 500.0};
    service = ClientInvoiceBalanceSyncService(firestore: store);
  });

  Future<SalesInvoiceCreationResult> create({double paid = 2000}) =>
      service.createSalesInvoice(
        clientId: 'client-1',
        clientName: 'Client',
        invoiceNumber: 'INV-1',
        paymentMethod: 'Cash',
        items: [],
        subtotal: 500,
        discount: 0,
        totalAmount: 500,
        paidAmount: paid,
        // Simulate an older caller sending the buggy clamped amount.
        remainingAmount: 0,
        invoiceDate: DateTime(2026, 10, 21),
      );

  Map<String, dynamic> invoice(String id) => {
    ...store.documents['sales_invoices/$id']!,
    'id': id,
  };

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

  test(
    'invoice payment posts full credit despite clamped caller input',
    () async {
      final result = await create();
      final saved = invoice(result.invoiceId);
      expect(result.previousBalance, 500);
      expect(result.balanceAfter, -1000);
      expect(store.documents['clients/client-1']!['balance'], -1000);
      expect(saved['remainingAmount'], -1500);
      expect(saved['paidAmount'], 2000);
      expect(saved['clientBalance'], -1000);

      final history =
          await store.collection('clients/client-1/balanceHistory').get();
      final ledger = ClientInvoiceBalanceSyncService.calculateBalanceHistory(
        records: history.docs.map(ClientBalanceRecord.fromFirestore).toList(),
        currentClientBalance: -1000,
      );
      expect(ledger.first.type, 'payment');
      expect(ledger.first.balanceBefore, 1000);
      expect(ledger.first.balanceAfter, -1000);
      expect(ledger.last.balanceBefore, 500);
    },
  );

  test('partial and exact account payments keep the expected debt', () async {
    await create(paid: 200);
    expect(store.documents['clients/client-1']!['balance'], 800);
    store.documents['clients/client-1']!['balance'] = 500.0;
    await create(paid: 1000);
    expect(store.documents['clients/client-1']!['balance'], 0);
  });

  test('credit carries forward into the next invoice', () async {
    await create();
    final result = await create(paid: 0);
    expect(result.previousBalance, -1000);
    expect(result.balanceAfter, -500);
  });

  test(
    'invoice with no payment increases debt and zero starting debt can become credit',
    () async {
      await create(paid: 0);
      expect(store.documents['clients/client-1']!['balance'], 1000);
      store.documents['clients/client-1']!['balance'] = 0.0;
      final result = await create();
      expect(result.balanceAfter, -1500);
    },
  );

  test(
    'negative and non-finite payments fail without changing the account',
    () async {
      for (final paid in [-1.0, double.nan, double.infinity]) {
        await expectLater(create(paid: paid), throwsArgumentError);
      }
      expect(store.documents.length, 1);
      expect(store.documents['clients/client-1']!['balance'], 500);
    },
  );

  testWidgets(
    'editing an overpayment updates account, invoice copies and ledger',
    (tester) async {
      final result = await create();
      final old = invoice(result.invoiceId);
      final context = await host(tester);
      final updated = await SalesInvoiceUpdateService.updateSalesInvoice(
        context: context,
        database: store,
        oldInvoice: old,
        newInvoice: {...old, 'paidAmount': 1500.0, 'remainingAmount': 0.0},
      );
      await tester.pumpAndSettle();
      expect(updated, isTrue);
      expect(store.documents['clients/client-1']!['balance'], -500);
      expect(invoice(result.invoiceId)['remainingAmount'], -1000);
      expect(
        store
            .documents['clients/client-1/invoices/${result.invoiceId}']!['remainingAmount'],
        -1000,
      );
      final history =
          await store.collection('clients/client-1/balanceHistory').get();
      final payment =
          history.docs
              .singleWhere((doc) => doc.data()['type'] == 'payment')
              .data();
      expect(payment['amount'], 1500);
      expect(payment['balanceAfter'], -500);
    },
  );

  testWidgets(
    'moving an overpaid invoice reverses old credit and credits new client',
    (tester) async {
      final result = await create();
      store.documents['clients/client-2'] = {'balance': 200.0};
      final old = invoice(result.invoiceId);
      final context = await host(tester);
      expect(
        await SalesInvoiceUpdateService.updateSalesInvoice(
          context: context,
          database: store,
          oldInvoice: old,
          newInvoice: {...old, 'clientId': 'client-2'},
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(store.documents['clients/client-1']!['balance'], 500);
      expect(store.documents['clients/client-2']!['balance'], -1300);
    },
  );

  testWidgets('editing credit back to debt preserves later account movements', (
    tester,
  ) async {
    final result = await create();
    final old = invoice(result.invoiceId);
    // A later invoice adds 300 after the overpayment.
    store.documents['clients/client-1']!['balance'] = -700.0;
    final context = await host(tester);
    expect(
      await SalesInvoiceUpdateService.updateSalesInvoice(
        context: context,
        database: store,
        oldInvoice: old,
        newInvoice: {...old, 'paidAmount': 0.0},
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(store.documents['clients/client-1']!['balance'], 1300);
    final history =
        await store.collection('clients/client-1/balanceHistory').get();
    expect(
      history.docs.where((doc) => doc.data()['type'] == 'payment'),
      isEmpty,
    );
  });

  testWidgets(
    'deleting a legacy clamped invoice does not reverse unposted credit',
    (tester) async {
      final result = await create();
      final staleInvoice = invoice(result.invoiceId);
      store.documents['sales_invoices/${result.invoiceId}']!['remainingAmount'] =
          0.0;
      store.documents['clients/client-1']!['balance'] = 500.0;
      final context = await host(tester);
      final deletion = SalesInvoiceActionsService.deleteSalesInvoice(
        context: context,
        database: store,
        invoiceData: staleInvoice,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الحذف'));
      await tester.pumpAndSettle();
      expect(await deletion, isTrue);
      expect(store.documents['clients/client-1']!['balance'], 500);
    },
  );

  testWidgets(
    'deleting an overpaid invoice restores the original account balance',
    (tester) async {
      final result = await create();
      final context = await host(tester);
      final deletion = SalesInvoiceActionsService.deleteSalesInvoice(
        context: context,
        database: store,
        invoiceData: invoice(result.invoiceId),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الحذف'));
      await tester.pumpAndSettle();
      expect(await deletion, isTrue);
      expect(store.documents['clients/client-1']!['balance'], 500);
      expect(
        store.documents.containsKey('sales_invoices/${result.invoiceId}'),
        isFalse,
      );
      expect(
        (await store.collection('clients/client-1/balanceHistory').get()).docs,
        isEmpty,
      );
    },
  );

  testWidgets('editing a legacy clamped invoice credits its excess only once', (
    tester,
  ) async {
    final result = await create();
    store.documents['clients/client-1']!['balance'] = 500.0;
    store.documents['sales_invoices/${result.invoiceId}']!['remainingAmount'] =
        0.0;
    store.documents['sales_invoices/${result.invoiceId}']!['balanceAfter'] =
        500.0;
    final context = await host(tester);
    final staleInvoice = invoice(result.invoiceId);
    for (var edit = 0; edit < 2; edit++) {
      expect(
        await SalesInvoiceUpdateService.updateSalesInvoice(
          context: context,
          database: store,
          oldInvoice: staleInvoice,
          newInvoice: staleInvoice,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(store.documents['clients/client-1']!['balance'], -1000);
    }
  });

  test('legacy invoice reversal respects its original posted amount', () {
    expect(
      ClientBalance.recordedInvoiceChange({
        'totalAmount': 500.0,
        'paidAmount': 2000.0,
        'remainingAmount': 0.0,
      }),
      0,
    );
    expect(
      ClientBalance.recordedInvoiceChange({
        'totalAmount': 500.0,
        'paidAmount': 2000.0,
      }),
      -1500,
    );
  });

  test(
    'shared invoice explains credit without hiding the signed balance',
    () async {
      final result = await create();
      final message = WhatsappInvoiceShareService.buildInvoiceMessage(
        invoice(result.invoiceId),
      );
      expect(message, contains('رصيد دائن للعميل:* \$-1000.00'));
      expect(message, contains('زيادة دفعة الفاتورة:* \$1500.00'));
    },
  );

  testWidgets('receipt shows client credit at phone and desktop widths', (
    tester,
  ) async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await font.load();
    final result = await create();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [375.0, 800.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Cairo'),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: InvoiceReceiptCard(
                    invoiceData: invoice(result.invoiceId),
                    pageItems: const [],
                    currentPage: 1,
                    totalPages: 1,
                    isSalesInvoice: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('رصيد دائن للعميل:'), findsOneWidget);
      expect(find.text('\$-1000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

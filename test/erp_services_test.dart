import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/core/utils/invoice_search.dart';
import 'package:store_manager/core/utils/quantity_formatter.dart';
import 'package:store_manager/data/models/product_model_new.dart';
import 'package:store_manager/data/models/order_model.dart';
import 'package:store_manager/data/models/user_model.dart';
import 'package:store_manager/features/users/bloc/user_event.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';
import 'package:store_manager/services/supplier_invoice_balance_sync_service.dart';
import 'package:store_manager/services/whatsapp_invoice_share_service.dart';

void main() {
  group('User Role & Permissions Tests', () {
    test('UserRole.accountant permissions and net profit visibility', () {
      expect(UserRole.accountant.label, equals('Accountant'));
      expect(UserRole.accountant.canSeeNetProfit, isFalse);
      expect(UserRole.admin.canSeeNetProfit, isTrue);
      expect(UserRole.employee.canSeeNetProfit, isTrue);
      expect(UserRole.viewer.canSeeNetProfit, isTrue);

      expect(UserRole.accountant.canManageUsers, isFalse);
      expect(UserRole.admin.canManageUsers, isTrue);
      expect(UserRole.accountant.canApproveOrders, isTrue);
      expect(UserRole.accountant.canEditInventory, isTrue);
      expect(UserRole.accountant.canCreateOrders, isTrue);
    });

    test('UserModel serialization with accountant role', () {
      final now = DateTime.now();
      final user = UserModel(
        id: 'acc1',
        email: 'accountant@example.com',
        name: 'Accountant User',
        role: UserRole.accountant,
        createdAt: now,
        updatedAt: now,
      );

      final data = user.toFirestore();
      expect(data['role'], equals('accountant'));
      expect(data['email'], equals('accountant@example.com'));

      final copy = user.copyWith(name: 'Updated Name');
      expect(copy.role, equals(UserRole.accountant));
      expect(copy.name, equals('Updated Name'));
    });

    test('UserManagementEvent update and delete events support props comparison', () {
      const updateEvent = UserManagementUpdateUserRequested(
        userId: 'u123',
        name: 'John Doe',
        role: UserRole.accountant,
        shopId: null,
        shopName: null,
      );

      expect(updateEvent.userId, equals('u123'));
      expect(updateEvent.name, equals('John Doe'));
      expect(updateEvent.role, equals(UserRole.accountant));
      expect(
        updateEvent,
        equals(const UserManagementUpdateUserRequested(
          userId: 'u123',
          name: 'John Doe',
          role: UserRole.accountant,
          shopId: null,
          shopName: null,
        )),
      );

      const deleteEvent = UserManagementDeleteRequested(userId: 'u123');
      expect(deleteEvent.userId, equals('u123'));
      expect(deleteEvent, equals(const UserManagementDeleteRequested(userId: 'u123')));
    });
  });
  group('Invoice History Search Tests', () {
    const invoice = {
      'invoiceNumber': 'INV-68908187',
      'clientName': 'الأستاذ أحمد عزوز',
      'clientPhone': '01123456789',
      'paymentMethod': 'Cash',
    };

    test('matches invoice number with or without hash', () {
      expect(invoiceMatchesHistorySearch(invoice, '#INV-6890'), isTrue);
      expect(invoiceMatchesHistorySearch(invoice, '68908187'), isTrue);
    });

    test('matches Arabic client names and ignores Arabic diacritics', () {
      expect(invoiceMatchesHistorySearch(invoice, 'احمد عزوز'), isTrue);
      expect(invoiceMatchesHistorySearch(invoice, 'أَحْمَد'), isTrue);
    });

    test('matches phone and payment method and rejects unrelated text', () {
      expect(invoiceMatchesHistorySearch(invoice, '011234'), isTrue);
      expect(invoiceMatchesHistorySearch(invoice, 'cash'), isTrue);
      expect(invoiceMatchesHistorySearch(invoice, 'محمد خالد'), isFalse);
    });
  });

  group('Quantity Formatter and Model Tests', () {
    test('formatQuantity handles integer and decimal quantities', () {
      expect(formatQuantity(5.0), equals('5'));
      expect(formatQuantity(5), equals('5'));
      expect(formatQuantity(5.6), equals('5.6'));
      expect(formatQuantity(0.25), equals('0.25'));
      expect(formatQuantity(10.50), equals('10.5'));
      expect(formatQuantity(null), equals('0'));
    });

    test('ProductModel supports double stockQuantity and threshold', () {
      final now = DateTime.now();
      final p = ProductModel(
        id: 'p1',
        name: 'Plastic Bag XL',
        size: '50x60',
        price: 25.0,
        costPrice: 18.5,
        stockQuantity: 5.6,
        lowStockThreshold: 2.5,
        createdAt: now,
        updatedAt: now,
      );

      expect(p.stockQuantity, equals(5.6));
      expect(p.lowStockThreshold, equals(2.5));
      expect(p.isLowStock, isFalse);

      final pLow = p.copyWith(stockQuantity: 2.0);
      expect(pLow.isLowStock, isTrue);
    });

    test('OrderItem supports double quantity and computes total', () {
      const item = OrderItem(
        productId: 'p1',
        productName: 'Bag',
        productSize: 'M',
        quantity: 5.6,
        unitPrice: 10.0,
      );

      expect(item.quantity, equals(5.6));
      expect(item.total, equals(56.0));
    });
  });

  group('ERP Safe Date Parsing Tests', () {
    test('parseInvoiceDate correctly handles null', () {
      final date = ClientInvoiceBalanceSyncService.parseInvoiceDate(null);
      expect(date, isNotNull);
    });

    test('parseInvoiceDate correctly handles DateTime', () {
      final now = DateTime.now();
      final date = ClientInvoiceBalanceSyncService.parseInvoiceDate(now);
      expect(date, equals(now));
    });

    test('parseInvoiceDate correctly handles ISO String', () {
      const isoStr = '2026-08-12T15:30:00.000Z';
      final date = ClientInvoiceBalanceSyncService.parseInvoiceDate(isoStr);
      expect(date.year, equals(2026));
      expect(date.month, equals(8));
      expect(date.day, equals(12));
    });

    test('parseInvoiceDate correctly handles int epoch milliseconds', () {
      const epochMs = 1700000000000;
      final date = ClientInvoiceBalanceSyncService.parseInvoiceDate(epochMs);
      expect(date, equals(DateTime.fromMillisecondsSinceEpoch(epochMs)));
    });

    test('parseInvoiceDate correctly handles int epoch seconds', () {
      const epochSec = 1700000000;
      final date = ClientInvoiceBalanceSyncService.parseInvoiceDate(epochSec);
      expect(
        date,
        equals(DateTime.fromMillisecondsSinceEpoch(epochSec * 1000)),
      );
    });
  });

  group('Supplier Safe Date Parsing Tests', () {
    test('Supplier parseInvoiceDate correctly handles ISO String', () {
      const isoStr = '2026-08-12T18:00:00.000Z';
      final date = SupplierInvoiceBalanceSyncService.parseInvoiceDate(isoStr);
      expect(date.year, equals(2026));
    });
  });

  group('Client Balance Ledger Tests', () {
    test(
      'invoice total is calculated before its payment deterministically',
      () {
        final openingTime = DateTime(2026, 9, 2, 13);
        final invoiceTime = DateTime(2026, 9, 2, 14);
        final records = [
          ClientBalanceRecord(
            id: 'payment',
            type: 'payment',
            invoiceId: 'invoice-1',
            invoiceNumber: 'INV-1',
            amount: 50,
            timestamp: invoiceTime,
            entryOrder: 1,
          ),
          ClientBalanceRecord(
            id: 'invoice',
            type: 'sales_invoice',
            invoiceId: 'invoice-1',
            invoiceNumber: 'INV-1',
            amount: 240,
            timestamp: invoiceTime,
            entryOrder: 0,
          ),
          ClientBalanceRecord(
            id: 'opening',
            type: 'opening',
            amount: 280,
            timestamp: openingTime,
          ),
        ];

        final ledger = ClientInvoiceBalanceSyncService.calculateBalanceHistory(
          records: records,
          currentClientBalance: 470,
        );

        expect(ledger.map((record) => record.type), [
          'payment',
          'sales_invoice',
          'opening',
        ]);
        expect(ledger[0].balanceBefore, 520);
        expect(ledger[0].balanceAfter, 470);
        expect(ledger[1].balanceBefore, 280);
        expect(ledger[1].balanceAfter, 520);
      },
    );

    test('newest balance is reconciled to the client document balance', () {
      final ledger = ClientInvoiceBalanceSyncService.calculateBalanceHistory(
        records: [
          ClientBalanceRecord(
            id: 'invoice',
            type: 'sales_invoice',
            amount: 100,
            timestamp: DateTime(2026, 9, 2),
          ),
        ],
        currentClientBalance: 125,
      );

      expect(ledger.first.balanceAfter, 125);
    });
  });

  group('Sales Invoice Sharing Tests', () {
    test('shared invoice includes balances before and after the invoice', () {
      final message = WhatsappInvoiceShareService.buildInvoiceMessage({
        'invoiceNumber': 'INV-1',
        'clientName': 'Test Client',
        'date': DateTime(2026, 9, 2),
        'totalAmount': 240.0,
        'paidAmount': 50.0,
        'remainingAmount': 190.0,
        'previousBalance': 280.0,
        'balanceAfter': 470.0,
        'items': <Map<String, dynamic>>[],
      });

      expect(message, contains('رصيد العميل السابق:* \$280.00'));
      expect(message, contains('رصيد العميل بعد الفاتورة:* \$470.00'));
    });

    test('shared invoice includes additional fees when provided', () {
      final message = WhatsappInvoiceShareService.buildInvoiceMessage({
        'invoiceNumber': 'INV-2',
        'clientName': 'Test Client',
        'date': DateTime(2026, 9, 2),
        'subtotal': 200.0,
        'additionalFees': [
          {'name': 'شحن ونقل', 'amount': 40.0},
        ],
        'items': <Map<String, dynamic>>[],
      });

      expect(message, contains('🚚 *شحن ونقل:* +\$40.00'));
    });

    test('shared invoice includes total quantity when items provided', () {
      final message = WhatsappInvoiceShareService.buildInvoiceMessage({
        'invoiceNumber': 'INV-3',
        'clientName': 'Test Client',
        'date': DateTime(2026, 9, 2),
        'subtotal': 300.0,
        'totalAmount': 300.0,
        'paidAmount': 300.0,
        'remainingAmount': 0.0,
        'previousBalance': 0.0,
        'balanceAfter': 0.0,
        'items': [
          {'productName': 'Item A', 'quantity': 12, 'price': 10.0},
          {'productName': 'Item B', 'quantity': 3.5, 'price': 20.0},
        ],
      });

      expect(message, contains('🔢 *إجمالي الكمية:* 15.5'));
    });
  });
}

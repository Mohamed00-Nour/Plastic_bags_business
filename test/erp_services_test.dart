import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/core/utils/quantity_formatter.dart';
import 'package:store_manager/data/models/product_model_new.dart';
import 'package:store_manager/data/models/order_model.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';
import 'package:store_manager/services/supplier_invoice_balance_sync_service.dart';

void main() {
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
      expect(date, equals(DateTime.fromMillisecondsSinceEpoch(epochSec * 1000)));
    });
  });

  group('Supplier Safe Date Parsing Tests', () {
    test('Supplier parseInvoiceDate correctly handles ISO String', () {
      const isoStr = '2026-08-12T18:00:00.000Z';
      final date = SupplierInvoiceBalanceSyncService.parseInvoiceDate(isoStr);
      expect(date.year, equals(2026));
    });
  });
}

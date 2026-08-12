import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:store_manager/services/client_invoice_balance_sync_service.dart';
import 'package:store_manager/services/supplier_invoice_balance_sync_service.dart';

void main() {
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

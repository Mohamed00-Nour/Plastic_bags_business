import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service handling Sales Invoice Actions (Deletion, Confirmation, Inventory Restoration, Balance Reversal).
class SalesInvoiceActionsService {
  SalesInvoiceActionsService._();

  /// Delete a Sales Invoice with full confirmation, inventory stock restoration, and client balance reversal.
  static Future<bool> deleteSalesInvoice({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    VoidCallback? onSuccess,
  }) async {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final invoiceId = invoiceData['id']?.toString() ?? invoiceData['invoiceId']?.toString() ?? '';

    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد معرف الفاتورة الحالية')),
      );
      return false;
    }

    // 1. Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: const Text('تأكيد حذف الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'هل أنت تأكد من حذف هذه الفاتورة رقم (#$invoiceNumber)؟\n(سيتم استرجاع كميات المنتجات إلى المخزن وتعديل رصيد العميل تلقائياً)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: const Text('تأكيد الحذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    // 2. Loading Overlay Dialog
    if (!context.mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => const Center(
        child: Card(
          color: Color(0xFF1E293B),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(width: 16),
                Text(
                  'جاري حذف الفاتورة وتعديل الرصيد والمخزون...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final items = (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final totalAmount = (invoiceData['totalAmount'] ?? 0.0).toDouble();
      final paidAmount = (invoiceData['paidAmount'] ?? 0.0).toDouble();
      final remainingOwed = (invoiceData['remainingAmount'] ?? (totalAmount - paidAmount)).toDouble();

      String clientId = invoiceData['clientId']?.toString() ?? '';
      final clientName = invoiceData['clientName']?.toString() ?? '';

      // If clientId is empty, query by clientName
      if (clientId.isEmpty && clientName.isNotEmpty) {
        try {
          final clientQuery = await firestore
              .collection('clients')
              .where('name', isEqualTo: clientName)
              .limit(1)
              .get();
          if (clientQuery.docs.isNotEmpty) {
            clientId = clientQuery.docs.first.id;
          }
        } catch (_) {}
      }

      // Execute Atomic Transaction
      await firestore.runTransaction((transaction) async {
        // A. Restore Stock Quantities
        for (final item in items) {
          final productId = item['productId']?.toString();
          final soldQty = (item['quantity'] ?? 1) is int
              ? (item['quantity'] as int)
              : double.parse(item['quantity'].toString()).toInt();

          DocumentReference? productRef;
          if (productId != null && productId.isNotEmpty) {
            productRef = firestore.collection('products').doc(productId);
          } else {
            final pName = item['productName'] ?? item['name'];
            if (pName != null) {
              final pQuery = await firestore
                  .collection('products')
                  .where('name', isEqualTo: pName)
                  .limit(1)
                  .get();
              if (pQuery.docs.isNotEmpty) {
                productRef = pQuery.docs.first.reference;
              }
            }
          }

          if (productRef != null) {
            final pSnap = await transaction.get(productRef);
            if (pSnap.exists) {
              final currentStock = (pSnap.data() as Map<String, dynamic>?)?['stockQuantity'] ??
                  (pSnap.data() as Map<String, dynamic>?)?['quantity'] ?? 0;
              final newStock = (currentStock is int ? currentStock : int.tryParse(currentStock.toString()) ?? 0) + soldQty;

              transaction.update(productRef, {
                'stockQuantity': newStock,
                'quantity': newStock,
              });

              // Log stock movement
              final changeRef = productRef.collection('changes').doc();
              transaction.set(changeRef, {
                'date': FieldValue.serverTimestamp(),
                'amount': soldQty,
                'type': 'increase',
                'notes': 'إلغاء فاتورة مبيعات #$invoiceNumber',
              });
            }
          }
        }

        // B. Reverse Client Balance
        if (clientId.isNotEmpty && remainingOwed > 0) {
          final clientRef = firestore.collection('clients').doc(clientId);
          final cSnap = await transaction.get(clientRef);
          if (cSnap.exists) {
            final data = cSnap.data() as Map<String, dynamic>;
            final currentBal = (data['balance'] ?? 0.0).toDouble();
            final newBal = currentBal - remainingOwed;

            transaction.update(clientRef, {'balance': newBal});

            final historyRef = clientRef.collection('balanceHistory').doc();
            transaction.set(historyRef, {
              'type': 'cancellation',
              'description': 'إلغاء فاتورة مبيعات #$invoiceNumber',
              'invoiceId': invoiceId,
              'invoiceNumber': invoiceNumber,
              'amount': remainingOwed,
              'balanceBefore': currentBal,
              'balanceAfter': newBal,
              'timestamp': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // C. Delete Root Invoice Document
        final rootInvoiceRef = firestore.collection('sales_invoices').doc(invoiceId);
        transaction.delete(rootInvoiceRef);

        // D. Delete Client Sub-document Invoice (if exists)
        if (clientId.isNotEmpty) {
          final subInvoiceRef = firestore
              .collection('clients')
              .doc(clientId)
              .collection('invoices')
              .doc(invoiceId);
          transaction.delete(subInvoiceRef);
        }
      });

      // Cleanup balance history docs matching this invoice number
      if (clientId.isNotEmpty) {
        try {
          final bhQuery = await firestore
              .collection('clients')
              .doc(clientId)
              .collection('balanceHistory')
              .where('invoiceNumber', isEqualTo: invoiceNumber)
              .get();
          for (final doc in bhQuery.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // Close Loading Overlay
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف الفاتورة رقم (#$invoiceNumber) واسترجاع المخزون ورصيد العميل بنجاح')),
        );
      }

      if (onSuccess != null) onSuccess();
      return true;
    } catch (e) {
      // Close Loading Overlay on error
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حذف الفاتورة: $e')),
        );
      }
      return false;
    }
  }
}

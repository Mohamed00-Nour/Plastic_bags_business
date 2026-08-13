import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service handling Sales Invoice Editing & Updating (Inventory Diffing, Client Debt Adjustments, Client Reassignments).
class SalesInvoiceUpdateService {
  SalesInvoiceUpdateService._();

  /// Update an existing Sales Invoice with automatic inventory diffing and client balance re-calculations.
  static Future<bool> updateSalesInvoice({
    required BuildContext context,
    required Map<String, dynamic> oldInvoice,
    required Map<String, dynamic> newInvoice,
    VoidCallback? onSuccess,
  }) async {
    final invoiceId = oldInvoice['id']?.toString() ?? oldInvoice['invoiceId']?.toString() ?? '';
    final invoiceNumber = oldInvoice['invoiceNumber']?.toString() ?? newInvoice['invoiceNumber']?.toString() ?? 'INV-000';

    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد معرف الفاتورة المراد تعديلها')),
      );
      return false;
    }

    // Show Progress Loading Dialog
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
                CircularProgressIndicator(color: Color(0xFF38BDF8)),
                SizedBox(width: 16),
                Text(
                  'جاري تحديث الفاتورة وتعديل المخزون والحسابات...',
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

      final oldItems = (oldInvoice['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final newItems = (newInvoice['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final oldTotal = (oldInvoice['totalAmount'] ?? 0.0).toDouble();
      final oldPaid = (oldInvoice['paidAmount'] ?? 0.0).toDouble();
      final oldNetDebt = (oldInvoice['remainingAmount'] ?? (oldTotal - oldPaid)).toDouble();

      final newTotal = (newInvoice['totalAmount'] ?? 0.0).toDouble();
      final newPaid = (newInvoice['paidAmount'] ?? 0.0).toDouble();
      final newNetDebt = (newInvoice['remainingAmount'] ?? (newTotal - newPaid)).toDouble();

      final oldClientId = oldInvoice['clientId']?.toString() ?? '';
      final newClientId = newInvoice['clientId']?.toString() ?? '';
      final isClientChanged = oldClientId.isNotEmpty && newClientId.isNotEmpty && oldClientId != newClientId;

      await firestore.runTransaction((transaction) async {
        // 1. Inventory Stock Adjustment (Quantity Diffing)
        final Map<String, int> oldQtyMap = {};
        final Map<String, int> newQtyMap = {};

        for (final item in oldItems) {
          final key = item['productId']?.toString() ?? item['productName'] ?? item['name'] ?? '';
          final qty = (item['quantity'] ?? 1) is int ? (item['quantity'] as int) : int.tryParse(item['quantity'].toString()) ?? 1;
          oldQtyMap[key] = (oldQtyMap[key] ?? 0) + qty;
        }

        for (final item in newItems) {
          final key = item['productId']?.toString() ?? item['productName'] ?? item['name'] ?? '';
          final qty = (item['quantity'] ?? 1) is int ? (item['quantity'] as int) : int.tryParse(item['quantity'].toString()) ?? 1;
          newQtyMap[key] = (newQtyMap[key] ?? 0) + qty;
        }

        final allKeys = {...oldQtyMap.keys, ...newQtyMap.keys};

        for (final key in allKeys) {
          final oldQty = oldQtyMap[key] ?? 0;
          final newQty = newQtyMap[key] ?? 0;
          final diff = newQty - oldQty; // diff > 0 means more sold, diff < 0 means returned

          if (diff != 0) {
            DocumentReference? productRef;
            if (key.length >= 20) {
              productRef = firestore.collection('products').doc(key);
            } else {
              final pQuery = await firestore
                  .collection('products')
                  .where('name', isEqualTo: key)
                  .limit(1)
                  .get();
              if (pQuery.docs.isNotEmpty) {
                productRef = pQuery.docs.first.reference;
              }
            }

            if (productRef != null) {
              final pSnap = await transaction.get(productRef);
              if (pSnap.exists) {
                final currentStock = (pSnap.data() as Map<String, dynamic>?)?['stockQuantity'] ??
                    (pSnap.data() as Map<String, dynamic>?)?['quantity'] ?? 0;
                final curInt = currentStock is int ? currentStock : int.tryParse(currentStock.toString()) ?? 0;
                final updatedStock = curInt - diff; // if diff > 0, stock decreases; if diff < 0, stock increases

                transaction.update(productRef, {
                  'stockQuantity': updatedStock,
                  'quantity': updatedStock,
                });

                final changeRef = productRef.collection('changes').doc();
                transaction.set(changeRef, {
                  'date': FieldValue.serverTimestamp(),
                  'amount': diff.abs(),
                  'type': diff > 0 ? 'decrease' : 'increase',
                  'notes': 'تعديل فاتورة مبيعات #$invoiceNumber',
                });
              }
            }
          }
        }

        // 2. Client Balance Adjustment & Re-assignment
        if (isClientChanged) {
          // Remove oldNetDebt from Old Client A
          final oldClientRef = firestore.collection('clients').doc(oldClientId);
          final oldCSnap = await transaction.get(oldClientRef);
          if (oldCSnap.exists) {
            final oldData = oldCSnap.data() as Map<String, dynamic>;
            final oldBal = (oldData['balance'] ?? 0.0).toDouble();
            final updatedOldBal = oldBal - oldNetDebt;
            transaction.update(oldClientRef, {'balance': updatedOldBal});

            final oldHistoryRef = oldClientRef.collection('balanceHistory').doc();
            transaction.set(oldHistoryRef, {
              'type': 'cancellation',
              'description': 'نقل فاتورة #$invoiceNumber إلى عميل آخر',
              'invoiceId': invoiceId,
              'amount': oldNetDebt,
              'balanceAfter': updatedOldBal,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }

          // Add newNetDebt to New Client B
          final newClientRef = firestore.collection('clients').doc(newClientId);
          final newCSnap = await transaction.get(newClientRef);
          if (newCSnap.exists) {
            final newData = newCSnap.data() as Map<String, dynamic>;
            final newBal = (newData['balance'] ?? 0.0).toDouble();
            final updatedNewBal = newBal + newNetDebt;
            transaction.update(newClientRef, {'balance': updatedNewBal});

            final newHistoryRef = newClientRef.collection('balanceHistory').doc();
            transaction.set(newHistoryRef, {
              'type': 'sales_invoice',
              'description': 'فاتورة مبيعات معدلة #$invoiceNumber',
              'invoiceId': invoiceId,
              'amount': newNetDebt,
              'balanceAfter': updatedNewBal,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }

          // Move invoice sub-document from Client A to Client B
          final oldSubDocRef = oldClientRef.collection('invoices').doc(invoiceId);
          transaction.delete(oldSubDocRef);

          final newSubDocRef = newClientRef.collection('invoices').doc(invoiceId);
          transaction.set(newSubDocRef, newInvoice);
        } else if (newClientId.isNotEmpty) {
          // Same client, adjust debt diff
          final debtDiff = newNetDebt - oldNetDebt;
          if (debtDiff != 0) {
            final clientRef = firestore.collection('clients').doc(newClientId);
            final cSnap = await transaction.get(clientRef);
            if (cSnap.exists) {
              final cData = cSnap.data() as Map<String, dynamic>;
              final currentBal = (cData['balance'] ?? 0.0).toDouble();
              final updatedBal = currentBal + debtDiff;
              transaction.update(clientRef, {'balance': updatedBal});

              final historyRef = clientRef.collection('balanceHistory').doc();
              transaction.set(historyRef, {
                'type': debtDiff > 0 ? 'sales_invoice' : 'payment',
                'description': 'تعديل قيمة فاتورة #$invoiceNumber',
                'invoiceId': invoiceId,
                'amount': debtDiff.abs(),
                'balanceAfter': updatedBal,
                'timestamp': FieldValue.serverTimestamp(),
              });
            }
          }

          // Update matching sub-doc
          final subDocRef = firestore.collection('clients').doc(newClientId).collection('invoices').doc(invoiceId);
          transaction.set(subDocRef, newInvoice, SetOptions(merge: true));
        }

        // 3. Update Root Sales Invoice Document
        final rootInvoiceRef = firestore.collection('sales_invoices').doc(invoiceId);
        transaction.update(rootInvoiceRef, {
          'items': newInvoice['items'],
          'subtotal': newInvoice['subtotal'],
          'discount': newInvoice['discount'],
          'totalAmount': newTotal,
          'paidAmount': newPaid,
          'remainingAmount': newNetDebt,
          'clientName': newInvoice['clientName'],
          'clientId': newClientId,
          'clientPhone': newInvoice['clientPhone'],
          'paymentMethod': newInvoice['paymentMethod'],
          'notes': newInvoice['notes'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Close Loading Overlay
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الفاتورة رقم (#$invoiceNumber) وتعديل المخزون والحسابات بنجاح')),
        );
      }

      if (onSuccess != null) onSuccess();
      return true;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تعديل الفاتورة: $e')),
        );
      }
      return false;
    }
  }
}

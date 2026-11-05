import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/services/current_user_service.dart';
import '../core/utils/client_balance.dart';
import 'invoice_number_service.dart';

/// Service handling Sales Invoice Actions (Deletion, Confirmation, Inventory Restoration, Balance Reversal).
class SalesInvoiceActionsService {
  SalesInvoiceActionsService._();

  /// Delete a Sales Invoice with full confirmation, inventory stock restoration, and client balance reversal.
  static Future<bool> deleteSalesInvoice({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    FirebaseFirestore? database,
    VoidCallback? onSuccess,
  }) async {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final invoiceId =
        invoiceData['id']?.toString() ??
        invoiceData['invoiceId']?.toString() ??
        '';

    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد معرف الفاتورة الحالية')),
      );
      return false;
    }

    final confirmed = await _confirmDeletion(
      context,
      title: 'تأكيد حذف الفاتورة',
      message:
          'هل أنت تأكد من حذف هذه الفاتورة رقم (#$invoiceNumber)؟\n(سيتم استرجاع كميات المنتجات إلى المخزن وتعديل رصيد العميل تلقائياً)',
    );
    if (!confirmed || !context.mounted) return false;

    final closeLoading = _showProgress(
      context,
      'جاري حذف الفاتورة وتعديل الرصيد والمخزون...',
    );

    try {
      final firestore = database ?? FirebaseFirestore.instance;
      final items =
          (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      String clientId = invoiceData['clientId']?.toString() ?? '';
      final clientName = invoiceData['clientName']?.toString() ?? '';

      // If clientId is empty, query by clientName
      if (clientId.isEmpty && clientName.isNotEmpty) {
        try {
          final clientQuery =
              await firestore
                  .collection('clients')
                  .where('name', isEqualTo: clientName)
                  .limit(1)
                  .get();
          if (clientQuery.docs.isNotEmpty) {
            clientId = clientQuery.docs.first.id;
          }
        } catch (_) {}
      }

      // Resolve all product references before transaction
      final productRefs = <DocumentReference, double>{};
      for (final item in items) {
        final productId = item['productId']?.toString();
        final soldQty =
            (item['quantity'] ?? 1.0) is num
                ? (item['quantity'] as num).toDouble()
                : double.tryParse(item['quantity'].toString()) ?? 1.0;

        DocumentReference? productRef;
        if (productId != null && productId.isNotEmpty) {
          productRef = firestore.collection('products').doc(productId);
        } else {
          final pName = item['productName'] ?? item['name'];
          if (pName != null) {
            final pQuery =
                await firestore
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
          productRefs.update(
            productRef,
            (currentQuantity) => currentQuantity + soldQty,
            ifAbsent: () => soldQty,
          );
        }
      }

      final clientRef =
          clientId.isNotEmpty
              ? firestore.collection('clients').doc(clientId)
              : null;
      final rootInvoiceRef = firestore
          .collection('sales_invoices')
          .doc(invoiceId);
      final serialNumber = InvoiceNumberService.parse(invoiceNumber);
      final numberReservationRef =
          serialNumber == null
              ? null
              : InvoiceNumberService(
                firestore: firestore,
              ).reservationRef(InvoiceSequence.salesInvoice, serialNumber);

      // Execute Atomic Transaction: ALL READS FIRST, THEN ALL WRITES
      await firestore.runTransaction((transaction) async {
        // --- PHASE 1: ALL READS ---
        final invoiceSnapshot = await transaction.get(rootInvoiceRef);
        if (!invoiceSnapshot.exists) return;
        final currentInvoice = invoiceSnapshot.data()!;
        final currentClientId = currentInvoice['clientId']?.toString() ?? '';
        if (currentClientId.isNotEmpty && currentClientId != clientId) {
          throw StateError('Invoice client changed. Reload before deleting.');
        }
        final remainingOwed = ClientBalance.recordedInvoiceChange(
          currentInvoice,
        );
        final productSnapshots = <DocumentReference, DocumentSnapshot>{};
        for (final pRef in productRefs.keys) {
          productSnapshots[pRef] = await transaction.get(pRef);
        }

        DocumentSnapshot? cSnap;
        if (clientRef != null && remainingOwed != 0) {
          cSnap = await transaction.get(clientRef);
        }

        // The serial number is freed only if it belongs to this invoice.
        final reservationSnap =
            numberReservationRef == null
                ? null
                : await transaction.get(numberReservationRef);

        // --- PHASE 2: ALL WRITES ---
        // A. Restore Stock Quantities
        for (final entry in productRefs.entries) {
          final pRef = entry.key;
          final soldQty = entry.value;
          final pSnap = productSnapshots[pRef];

          if (pSnap != null && pSnap.exists) {
            final currentStock =
                (pSnap.data() as Map<String, dynamic>?)?['stockQuantity'] ??
                (pSnap.data() as Map<String, dynamic>?)?['quantity'] ??
                0;
            final curDouble =
                currentStock is num
                    ? currentStock.toDouble()
                    : double.tryParse(currentStock.toString()) ?? 0.0;
            final newStock = curDouble + soldQty;

            transaction.update(pRef, {
              'stockQuantity': newStock,
              'quantity': newStock,
            });

            // Log stock movement
            final changeRef = pRef.collection('changes').doc();
            transaction.set(changeRef, {
              'date': FieldValue.serverTimestamp(),
              'amount': soldQty,
              'type': 'increase',
              'notes': 'إلغاء فاتورة مبيعات #$invoiceNumber',
            });

            final stockLogRef = firestore.collection('stock_logs').doc();
            transaction.set(stockLogRef, {
              'productId': pRef.id,
              'productName':
                  (pSnap.data() as Map<String, dynamic>?)?['name']
                      ?.toString() ??
                  '',
              'type': 'incoming',
              'quantity': soldQty,
              'stockBefore': curDouble,
              'stockAfter': newStock,
              'referenceId': invoiceId,
              'note': 'Sales invoice deletion #$invoiceNumber',
              'createdBy': CurrentUserService.instance.userName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // B. Reverse Client Balance
        if (clientRef != null &&
            cSnap != null &&
            cSnap.exists &&
            remainingOwed != 0) {
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

        // C. Delete Root Invoice Document
        transaction.delete(rootInvoiceRef);

        // Free the serial number so it can be typed in again.
        if (reservationSnap != null &&
            reservationSnap.exists &&
            reservationSnap.data()?['documentId'] == invoiceId) {
          transaction.delete(numberReservationRef!);
        }

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
          final bhQuery =
              await firestore
                  .collection('clients')
                  .doc(clientId)
                  .collection('balanceHistory')
                  .where('invoiceNumber', isEqualTo: invoiceNumber)
                  .get();
          final cleanupBatch = firestore.batch();
          for (final doc in bhQuery.docs) {
            // Returns have their own numbers, so a return can share this
            // number. Only remove rows of this invoice (or legacy rows
            // saved without an invoice id).
            final rowInvoiceId = doc.data()['invoiceId']?.toString() ?? '';
            if (rowInvoiceId.isNotEmpty && rowInvoiceId != invoiceId) continue;
            cleanupBatch.delete(doc.reference);
          }
          await cleanupBatch.commit();
        } catch (_) {}
      }

      // Close Loading Overlay
      closeLoading();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف الفاتورة رقم (#$invoiceNumber) واسترجاع المخزون ورصيد العميل بنجاح',
            ),
          ),
        );
      }

      if (onSuccess != null) onSuccess();
      return true;
    } catch (e) {
      // Close Loading Overlay on error
      closeLoading();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حذف الفاتورة: $e')),
        );
      }
      return false;
    }
  }

  static Future<bool> _confirmDeletion(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(message),
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
    return confirmed == true;
  }

  /// Shows a blocking progress dialog and returns a function that closes it.
  static VoidCallback _showProgress(BuildContext context, String message) {
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) {
        dialogContext = loadingCtx;
        return Center(
          child: Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(width: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return () {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
        dialogContext = null;
      } else if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    };
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  /// Deletes a sales return and undoes everything saving it did: takes the
  /// returned quantities out of stock again, cancels its effect on the client
  /// balance, removes its balance-history rows and frees its serial number.
  static Future<bool> deleteSalesReturn({
    required BuildContext context,
    required Map<String, dynamic> returnData,
    FirebaseFirestore? database,
  }) async {
    final returnNumber =
        (returnData['returnNumber'] ?? returnData['invoiceNumber'])
            ?.toString() ??
        '';
    final returnId = returnData['id']?.toString() ?? '';
    if (returnId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحديد معرف المرتجع')));
      return false;
    }

    final confirmed = await _confirmDeletion(
      context,
      title: 'تأكيد حذف المرتجع',
      message:
          'هل أنت متأكد من حذف المرتجع رقم (#$returnNumber)؟\n(سيتم خصم الكميات المرتجعة من المخزن مرة أخرى وإلغاء أثر المرتجع على رصيد العميل)',
    );
    if (!confirmed || !context.mounted) return false;

    final closeLoading = _showProgress(
      context,
      'جاري حذف المرتجع وتعديل الرصيد والمخزون...',
    );

    try {
      final firestore = database ?? FirebaseFirestore.instance;
      final returnRef = firestore.collection('return_invoices').doc(returnId);
      final mirrorRef = firestore.collection('sales_returns').doc(returnId);

      // Work from the saved return, not the (possibly stale) card data.
      final saved = await returnRef.get();
      if (!saved.exists) {
        throw StateError('المرتجع غير موجود أو تم حذفه بالفعل');
      }
      final data = saved.data()!;

      var clientId = data['clientId']?.toString() ?? '';
      final clientName = data['clientName']?.toString() ?? '';
      if (clientId.isEmpty && clientName.isNotEmpty) {
        final clientQuery =
            await firestore
                .collection('clients')
                .where('name', isEqualTo: clientName)
                .limit(1)
                .get();
        if (clientQuery.docs.isNotEmpty) clientId = clientQuery.docs.first.id;
      }
      final clientRef =
          clientId.isEmpty
              ? null
              : firestore.collection('clients').doc(clientId);

      // Same rule as saving: only items with a product id and a quantity
      // above zero were added to stock.
      final returnedQty = <String, double>{};
      final productNames = <String, String>{};
      for (final item in (data['items'] as List?) ?? const []) {
        if (item is! Map) continue;
        final productId = item['productId']?.toString() ?? '';
        final qty = _toDouble(item['quantity']);
        if (productId.isEmpty || qty <= 0) continue;
        returnedQty.update(productId, (q) => q + qty, ifAbsent: () => qty);
        productNames[productId] = item['productName']?.toString() ?? '';
      }

      final historyRows =
          clientRef == null
              ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
              : (await clientRef
                      .collection('balanceHistory')
                      .where('invoiceId', isEqualTo: returnId)
                      .get())
                  .docs;

      final returnTotal = _toDouble(
        data['returnTotalAmount'] ?? data['totalAmount'],
      );
      final refund = _toDouble(data['paidAmount']);
      // Saving lowered the balance by this amount; deleting adds it back.
      final netCredit = returnTotal - refund;

      final serialNumber = InvoiceNumberService.parse(returnNumber);
      final reservationRef =
          serialNumber == null
              ? null
              : InvoiceNumberService(
                firestore: firestore,
              ).reservationRef(InvoiceSequence.salesReturn, serialNumber);

      await firestore.runTransaction((transaction) async {
        // --- ALL READS ---
        final current = await transaction.get(returnRef);
        if (!current.exists) {
          throw StateError('المرتجع غير موجود أو تم حذفه بالفعل');
        }
        final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final productId in returnedQty.keys) {
          productSnaps[productId] = await transaction.get(
            firestore.collection('products').doc(productId),
          );
        }
        final clientSnap =
            clientRef == null ? null : await transaction.get(clientRef);
        final reservationSnap =
            reservationRef == null
                ? null
                : await transaction.get(reservationRef);

        // --- ALL WRITES ---
        // A. Take the returned quantities out of stock again.
        for (final entry in returnedQty.entries) {
          final snap = productSnaps[entry.key]!;
          if (!snap.exists) continue;
          final productData = snap.data()!;
          final before = _toDouble(
            productData['stockQuantity'] ?? productData['quantity'],
          );
          final after = before - entry.value;
          transaction.update(snap.reference, {
            'stockQuantity': after,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(snap.reference.collection('changes').doc(), {
            'timestamp': FieldValue.serverTimestamp(),
            'quantityChange': -entry.value,
            'operationType': 'sales_return_deleted',
            'invoiceId': returnId,
            'invoiceNumber': returnNumber,
            'productName': productNames[entry.key] ?? '',
          });
          transaction.set(firestore.collection('stock_logs').doc(), {
            'productId': entry.key,
            'productName':
                productData['name']?.toString() ??
                productNames[entry.key] ??
                '',
            'type': 'outgoing',
            'quantity': entry.value,
            'stockBefore': before,
            'stockAfter': after,
            'referenceId': returnId,
            'note': 'Sales return deletion #$returnNumber',
            'createdBy': CurrentUserService.instance.userName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // B. Cancel the return's effect on the client balance.
        if (clientSnap != null && clientSnap.exists && netCredit != 0) {
          final balance = _toDouble(clientSnap.data()?['balance']);
          transaction.update(clientRef!, {
            'balance': balance + netCredit,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // C. Remove its balance-history rows (return total and cash refund).
        for (final row in historyRows) {
          transaction.delete(row.reference);
        }

        // D. Delete the return and free its number if it owns it.
        transaction.delete(returnRef);
        transaction.delete(mirrorRef);
        if (reservationSnap != null &&
            reservationSnap.exists &&
            reservationSnap.data()?['documentId'] == returnId) {
          transaction.delete(reservationRef!);
        }
      });

      closeLoading();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف المرتجع رقم (#$returnNumber) وتعديل المخزون ورصيد العميل بنجاح',
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      closeLoading();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حذف المرتجع: $e')),
        );
      }
      return false;
    }
  }
}

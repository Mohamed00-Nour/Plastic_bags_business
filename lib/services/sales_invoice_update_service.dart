import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/services/current_user_service.dart';
import '../core/utils/client_balance.dart';

/// Service handling Sales Invoice Editing & Updating (Inventory Diffing, Client Debt Adjustments, Client Reassignments).
class SalesInvoiceUpdateService {
  SalesInvoiceUpdateService._();

  /// Update an existing Sales Invoice with automatic inventory diffing and client balance re-calculations.
  static Future<bool> updateSalesInvoice({
    required BuildContext context,
    required Map<String, dynamic> oldInvoice,
    required Map<String, dynamic> newInvoice,
    FirebaseFirestore? database,
    VoidCallback? onSuccess,
  }) async {
    final invoiceId =
        oldInvoice['id']?.toString() ??
        oldInvoice['invoiceId']?.toString() ??
        '';
    final invoiceNumber =
        oldInvoice['invoiceNumber']?.toString() ??
        newInvoice['invoiceNumber']?.toString() ??
        'INV-000';

    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد معرف الفاتورة المراد تعديلها'),
        ),
      );
      return false;
    }

    // Show Progress Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (loadingCtx) => const Center(
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    try {
      final firestore = database ?? FirebaseFirestore.instance;

      final oldItems =
          (oldInvoice['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final newItems =
          (newInvoice['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final newTotal = (newInvoice['totalAmount'] ?? 0.0).toDouble();
      final newPaid = (newInvoice['paidAmount'] ?? 0.0).toDouble();
      final newNetDebt = ClientBalance.invoiceChange(
        totalAmount: newTotal,
        paidAmount: newPaid,
      );

      final oldClientId = oldInvoice['clientId']?.toString() ?? '';
      final newClientId = newInvoice['clientId']?.toString() ?? '';
      final isClientChanged =
          oldClientId.isNotEmpty &&
          newClientId.isNotEmpty &&
          oldClientId != newClientId;

      // Resolve product references before starting the transaction. Firestore
      // transactions cannot run queries, and every transactional read must be
      // completed before the first write.
      final oldQtyMap = _quantitiesByProduct(oldItems);
      final newQtyMap = _quantitiesByProduct(newItems);
      final productDiffs = <DocumentReference<Map<String, dynamic>>, double>{};

      for (final key in {...oldQtyMap.keys, ...newQtyMap.keys}) {
        final diff = (newQtyMap[key] ?? 0.0) - (oldQtyMap[key] ?? 0.0);
        if (diff == 0) continue;

        final productRef = await _resolveProductReference(firestore, key);
        if (productRef != null) {
          productDiffs.update(
            productRef,
            (existingDiff) => existingDiff + diff,
            ifAbsent: () => diff,
          );
        }
      }
      productDiffs.removeWhere((_, diff) => diff == 0);

      final oldClientRef =
          isClientChanged
              ? firestore.collection('clients').doc(oldClientId)
              : null;
      final newClientRef =
          isClientChanged
              ? firestore.collection('clients').doc(newClientId)
              : null;
      final sameClientRef =
          !isClientChanged && newClientId.isNotEmpty
              ? firestore.collection('clients').doc(newClientId)
              : null;
      final invoiceTimestamp = _asTimestamp(newInvoice['date']);
      final editTimestamp = Timestamp.now();
      final rootInvoiceRef = firestore.collection('sales_invoices').doc(invoiceId);

      // Resolve the invoice's existing ledger rows before the transaction so
      // an edit can update those rows instead of appending a generic debt
      // difference. Their contents are read again transactionally below.
      final sameClientHistoryRefs = <DocumentReference<Map<String, dynamic>>>[];
      if (sameClientRef != null) {
        var historyQuery =
            await sameClientRef
                .collection('balanceHistory')
                .where('invoiceId', isEqualTo: invoiceId)
                .get();
        if (historyQuery.docs.isEmpty && invoiceNumber.isNotEmpty) {
          historyQuery =
              await sameClientRef
                  .collection('balanceHistory')
                  .where('invoiceNumber', isEqualTo: invoiceNumber)
                  .get();
        }
        sameClientHistoryRefs.addAll(
          historyQuery.docs.map((document) => document.reference),
        );
      }

      await firestore.runTransaction((transaction) async {
        // PHASE 1: read every document before issuing any write.
        final invoiceSnapshot = await transaction.get(rootInvoiceRef);
        if (!invoiceSnapshot.exists) {
          throw StateError('Invoice no longer exists. Reload before editing.');
        }
        final currentInvoice = invoiceSnapshot.data()!;
        if ((currentInvoice['clientId']?.toString() ?? '') != oldClientId) {
          throw StateError('Invoice client changed. Reload before editing.');
        }
        // Use the live posting so saving a stale legacy invoice cannot restore
        // the same previously clamped credit twice.
        final oldNetDebt = ClientBalance.recordedInvoiceChange(currentInvoice);
        final oldTotal = _asDouble(currentInvoice['totalAmount']);
        final oldPaid = _asDouble(currentInvoice['paidAmount']);
        final debtDiff = newNetDebt - oldNetDebt;
        final productSnapshots =
            <
              DocumentReference<Map<String, dynamic>>,
              DocumentSnapshot<Map<String, dynamic>>
            >{};
        for (final productRef in productDiffs.keys) {
          productSnapshots[productRef] = await transaction.get(productRef);
        }

        DocumentSnapshot<Map<String, dynamic>>? oldClientSnapshot;
        DocumentSnapshot<Map<String, dynamic>>? newClientSnapshot;
        DocumentSnapshot<Map<String, dynamic>>? sameClientSnapshot;
        if (oldClientRef != null) {
          oldClientSnapshot = await transaction.get(oldClientRef);
        }
        if (newClientRef != null) {
          newClientSnapshot = await transaction.get(newClientRef);
        }
        if (sameClientRef != null) {
          sameClientSnapshot = await transaction.get(sameClientRef);
        }
        final sameClientHistorySnapshots =
            <
              DocumentReference<Map<String, dynamic>>,
              DocumentSnapshot<Map<String, dynamic>>
            >{};
        for (final historyRef in sameClientHistoryRefs) {
          sameClientHistorySnapshots[historyRef] = await transaction.get(
            historyRef,
          );
        }

        final storedPreviousValue =
            oldInvoice['previousBalance'] ??
            oldInvoice['clientPreviousBalance'] ??
            newInvoice['previousBalance'] ??
            newInvoice['clientPreviousBalance'];
        double? invoicePreviousBalance =
            storedPreviousValue == null ? null : _asDouble(storedPreviousValue);

        if (isClientChanged &&
            newClientSnapshot != null &&
            newClientSnapshot.exists) {
          invoicePreviousBalance = _asDouble(
            newClientSnapshot.data()?['balance'],
          );
        } else if (!isClientChanged &&
            sameClientSnapshot != null &&
            sameClientSnapshot.exists) {
          invoicePreviousBalance ??=
              _asDouble(sameClientSnapshot.data()?['balance']) - oldNetDebt;
        }
        invoicePreviousBalance ??= _asDouble(newInvoice['previousBalance']);
        final invoiceBalanceAfter = invoicePreviousBalance + newNetDebt;
        final persistedInvoice = <String, dynamic>{
          ...newInvoice,
          'remainingAmount': newNetDebt,
          'previousBalance': invoicePreviousBalance,
          'clientPreviousBalance': invoicePreviousBalance,
          'balanceAfter': invoiceBalanceAfter,
          'clientBalance': invoiceBalanceAfter,
        };

        // PHASE 2: apply inventory writes using the snapshots above.
        for (final entry in productDiffs.entries) {
          final productRef = entry.key;
          final diff = entry.value;
          final productSnapshot = productSnapshots[productRef];
          if (productSnapshot == null || !productSnapshot.exists) continue;

          final productData = productSnapshot.data();
          final currentStock =
              productData?['stockQuantity'] ?? productData?['quantity'] ?? 0;
          final currentStockValue =
              currentStock is num
                  ? currentStock.toDouble()
                  : double.tryParse(currentStock.toString()) ?? 0.0;
          final updatedStock = currentStockValue - diff;
          final isMoreSold = diff > 0;

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

          final stockLogRef = firestore.collection('stock_logs').doc();
          transaction.set(stockLogRef, {
            'productId': productRef.id,
            'productName': productData?['name']?.toString() ?? '',
            'type': isMoreSold ? 'outgoing' : 'incoming',
            'quantity': diff.abs(),
            'stockBefore': currentStockValue,
            'stockAfter': updatedStock,
            'referenceId': invoiceId,
            'note': 'Sales invoice edit #$invoiceNumber',
            'createdBy': CurrentUserService.instance.userName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // PHASE 3: update client balances and invoice documents.
        if (isClientChanged) {
          if (oldClientRef != null &&
              oldClientSnapshot != null &&
              oldClientSnapshot.exists) {
            final oldData = oldClientSnapshot.data()!;
            final oldBal = (oldData['balance'] ?? 0.0).toDouble();
            final updatedOldBal = oldBal - oldNetDebt;
            transaction.update(oldClientRef, {'balance': updatedOldBal});

            final oldHistoryRef =
                oldClientRef.collection('balanceHistory').doc();
            transaction.set(oldHistoryRef, {
              'type': 'cancellation',
              'description': 'نقل فاتورة #$invoiceNumber إلى عميل آخر',
              'invoiceId': invoiceId,
              'invoiceNumber': invoiceNumber,
              'amount': oldNetDebt,
              'totalAmount': oldTotal,
              'paidAmount': oldPaid,
              'balanceBefore': oldBal,
              'balanceAfter': updatedOldBal,
              'timestamp': editTimestamp,
              'entryOrder': 2,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          if (newClientRef != null &&
              newClientSnapshot != null &&
              newClientSnapshot.exists) {
            final newData = newClientSnapshot.data()!;
            final newBal = (newData['balance'] ?? 0.0).toDouble();
            final updatedNewBal = newBal + newNetDebt;
            transaction.update(newClientRef, {'balance': updatedNewBal});

            final invoiceHistoryRef =
                newClientRef.collection('balanceHistory').doc();
            transaction.set(invoiceHistoryRef, {
              'type': 'sales_invoice',
              'invoiceId': invoiceId,
              'invoiceNumber': invoiceNumber,
              'amount': newTotal,
              'totalAmount': newTotal,
              'paidAmount': newPaid,
              'balanceBefore': newBal,
              'balanceAfter': newBal + newTotal,
              'timestamp': invoiceTimestamp,
              'entryOrder': 0,
              'createdAt': FieldValue.serverTimestamp(),
            });

            if (newPaid > 0) {
              final paymentHistoryRef =
                  newClientRef.collection('balanceHistory').doc();
              transaction.set(paymentHistoryRef, {
                'type': 'payment',
                'description': 'تحصيل من فاتورة #$invoiceNumber',
                'invoiceId': invoiceId,
                'invoiceNumber': invoiceNumber,
                'amount': newPaid,
                'totalAmount': newTotal,
                'paidAmount': newPaid,
                'balanceBefore': newBal + newTotal,
                'balanceAfter': updatedNewBal,
                'timestamp': invoiceTimestamp,
                'entryOrder': 1,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }

          if (oldClientRef != null && newClientRef != null) {
            final oldSubDocRef = oldClientRef
                .collection('invoices')
                .doc(invoiceId);
            transaction.delete(oldSubDocRef);

            final newSubDocRef = newClientRef
                .collection('invoices')
                .doc(invoiceId);
            transaction.set(newSubDocRef, persistedInvoice);
          }
        } else if (newClientId.isNotEmpty) {
          if (sameClientRef != null &&
              sameClientSnapshot != null &&
              sameClientSnapshot.exists &&
              debtDiff != 0) {
            final clientData = sameClientSnapshot.data()!;
            final currentBal = (clientData['balance'] ?? 0.0).toDouble();
            final updatedBal = currentBal + debtDiff;
            transaction.update(sameClientRef, {'balance': updatedBal});
          }

          if (sameClientRef != null) {
            DocumentReference<Map<String, dynamic>>? invoiceHistoryRef;
            DocumentReference<Map<String, dynamic>>? paymentHistoryRef;
            DocumentReference<Map<String, dynamic>>? fallbackInvoiceRef;
            final extraHistoryRefs =
                <DocumentReference<Map<String, dynamic>>>[];

            for (final entry in sameClientHistorySnapshots.entries) {
              final snapshot = entry.value;
              if (!snapshot.exists) continue;
              final data = snapshot.data() ?? const <String, dynamic>{};
              final type = data['type']?.toString() ?? '';
              final description = data['description']?.toString() ?? '';

              if (type == 'sales_invoice') {
                fallbackInvoiceRef ??= entry.key;
                if (invoiceHistoryRef == null &&
                    !description.startsWith('تعديل قيمة فاتورة #')) {
                  invoiceHistoryRef = entry.key;
                  continue;
                }
              } else if (type == 'payment' && paymentHistoryRef == null) {
                paymentHistoryRef = entry.key;
                continue;
              }
              extraHistoryRefs.add(entry.key);
            }

            invoiceHistoryRef ??= fallbackInvoiceRef;
            invoiceHistoryRef ??=
                sameClientRef.collection('balanceHistory').doc();
            extraHistoryRefs.remove(invoiceHistoryRef);

            transaction.set(invoiceHistoryRef, {
              'type': 'sales_invoice',
              'description': '',
              'notes': newInvoice['notes']?.toString() ?? '',
              'invoiceId': invoiceId,
              'invoiceNumber': invoiceNumber,
              'amount': newTotal,
              'totalAmount': newTotal,
              'paidAmount': newPaid,
              'balanceBefore': invoicePreviousBalance,
              'balanceAfter': invoicePreviousBalance + newTotal,
              'timestamp': invoiceTimestamp,
              'entryOrder': 0,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (newPaid > 0) {
              paymentHistoryRef ??=
                  sameClientRef.collection('balanceHistory').doc();
              extraHistoryRefs.remove(paymentHistoryRef);
              transaction.set(paymentHistoryRef, {
                'type': 'payment',
                'description': 'تحصيل من فاتورة #$invoiceNumber',
                'notes': '',
                'invoiceId': invoiceId,
                'invoiceNumber': invoiceNumber,
                'amount': newPaid,
                'totalAmount': newTotal,
                'paidAmount': newPaid,
                'balanceBefore': invoicePreviousBalance + newTotal,
                'balanceAfter': invoiceBalanceAfter,
                'timestamp': invoiceTimestamp,
                'entryOrder': 1,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } else if (paymentHistoryRef != null) {
              transaction.delete(paymentHistoryRef);
              extraHistoryRefs.remove(paymentHistoryRef);
            }

            for (final extraHistoryRef in extraHistoryRefs.toSet()) {
              transaction.delete(extraHistoryRef);
            }
          }

          final subDocRef = firestore
              .collection('clients')
              .doc(newClientId)
              .collection('invoices')
              .doc(invoiceId);
          transaction.set(subDocRef, persistedInvoice, SetOptions(merge: true));
        }

        transaction.update(rootInvoiceRef, {
          'items': newInvoice['items'],
          'subtotal': newInvoice['subtotal'],
          'discount': newInvoice['discount'],
          'additionalFees': newInvoice['additionalFees'] ?? [],
          'additionalFeeAmount':
              (newInvoice['additionalFeeAmount'] ?? 0.0).toDouble(),
          'totalAmount': newTotal,
          'paidAmount': newPaid,
          'remainingAmount': newNetDebt,
          'previousBalance': invoicePreviousBalance,
          'clientPreviousBalance': invoicePreviousBalance,
          'balanceAfter': invoiceBalanceAfter,
          'clientBalance': invoiceBalanceAfter,
          'clientName': newInvoice['clientName'],
          'clientId': newClientId,
          'clientPhone': newInvoice['clientPhone'],
          'paymentMethod': newInvoice['paymentMethod'],
          'notes': newInvoice['notes'],
          'date': invoiceTimestamp,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Close Loading Overlay
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث الفاتورة رقم (#$invoiceNumber) وتعديل المخزون والحسابات بنجاح',
            ),
          ),
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

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static Timestamp _asTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is int) {
      final milliseconds = value < 10000000000 ? value * 1000 : value;
      return Timestamp.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return Timestamp.now();
  }

  static Map<String, double> _quantitiesByProduct(
    List<Map<String, dynamic>> items,
  ) {
    final quantities = <String, double>{};

    for (final item in items) {
      final productId = item['productId']?.toString() ?? '';
      final productName =
          item['productName']?.toString() ?? item['name']?.toString() ?? '';
      if (productId.isEmpty && productName.isEmpty) continue;

      final key = productId.isNotEmpty ? 'id:$productId' : 'name:$productName';
      final rawQuantity = item['quantity'] ?? 1.0;
      final quantity =
          rawQuantity is num
              ? rawQuantity.toDouble()
              : double.tryParse(rawQuantity.toString()) ?? 1.0;
      quantities.update(
        key,
        (currentQuantity) => currentQuantity + quantity,
        ifAbsent: () => quantity,
      );
    }

    return quantities;
  }

  static Future<DocumentReference<Map<String, dynamic>>?>
  _resolveProductReference(FirebaseFirestore firestore, String key) async {
    if (key.startsWith('id:')) {
      final productId = key.substring(3);
      return productId.isEmpty
          ? null
          : firestore.collection('products').doc(productId);
    }

    if (!key.startsWith('name:')) return null;
    final productName = key.substring(5);
    if (productName.isEmpty) return null;

    final productQuery =
        await firestore
            .collection('products')
            .where('name', isEqualTo: productName)
            .limit(1)
            .get();
    return productQuery.docs.isEmpty ? null : productQuery.docs.first.reference;
  }
}

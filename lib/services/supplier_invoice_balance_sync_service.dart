import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Helper class to represent a supplier balance history item
class SupplierBalanceRecord {
  final String id;
  final String type; // 'opening', 'buying_invoice', 'purchase_return', 'payment', 'cancellation'
  final String invoiceId;
  final String invoiceNumber;
  final String description;
  final String notes;
  final double amount;
  final double totalAmount;
  final double paidAmount;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime timestamp;

  SupplierBalanceRecord({
    required this.id,
    required this.type,
    this.invoiceId = '',
    this.invoiceNumber = '',
    this.description = '',
    this.notes = '',
    required this.amount,
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    this.balanceBefore = 0.0,
    this.balanceAfter = 0.0,
    required this.timestamp,
  });

  factory SupplierBalanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawNotes = data['notes']?.toString().trim() ?? '';
    final rawDesc = data['description']?.toString().trim() ?? '';
    return SupplierBalanceRecord(
      id: doc.id,
      type: data['type'] ?? 'transaction',
      invoiceId: data['invoiceId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      description: rawDesc,
      notes: rawNotes.isNotEmpty ? rawNotes : rawDesc,
      amount: (data['amount'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      balanceBefore: (data['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (data['balanceAfter'] ?? 0).toDouble(),
      timestamp: SupplierInvoiceBalanceSyncService.parseInvoiceDate(data['timestamp']),
    );
  }
}

class SupplierInvoiceBalanceSyncService {
  final FirebaseFirestore _firestore;

  SupplierInvoiceBalanceSyncService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Safe Date Parsing Helper
  /// Handles Firestore Timestamp, Dart DateTime, ISO String, and int epoch timestamps.
  static DateTime parseInvoiceDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      if (raw < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Check online in Firestore for duplicate supplier name before creation
  Future<bool> isDuplicateSupplierName(String name, {String? excludeId}) async {
    final query = await _firestore
        .collection('suppliers')
        .where('name', isEqualTo: name.trim())
        .get();

    if (excludeId != null) {
      return query.docs.any((doc) => doc.id != excludeId);
    }
    return query.docs.isNotEmpty;
  }

  /// Create a new Supplier document with opening balance & balanceHistory
  Future<String> createSupplier({
    required String name,
    required String phone,
    String? address,
    double openingBalance = 0.0,
  }) async {
    final trimmedName = name.trim();

    // Check duplicate
    final isDup = await isDuplicateSupplierName(trimmedName);
    if (isDup) {
      throw Exception('Supplier with name "$trimmedName" already exists.');
    }

    final supplierRef = _firestore.collection('suppliers').doc();
    final supplierId = supplierRef.id;

    final batch = _firestore.batch();

    batch.set(supplierRef, {
      'name': trimmedName,
      'phone': phone.trim(),
      'address': address?.trim() ?? '',
      'totalBalance': openingBalance,
      'balance': openingBalance,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write opening document in suppliers/{id}/balanceHistory
    final historyRef = supplierRef.collection('balanceHistory').doc();
    batch.set(historyRef, {
      'type': 'opening',
      'invoiceId': '',
      'invoiceNumber': 'OPENING',
      'amount': openingBalance,
      'totalAmount': openingBalance,
      'paidAmount': 0.0,
      'balanceBefore': 0.0,
      'balanceAfter': openingBalance,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return supplierId;
  }

  /// Create Buying Invoice with atomic WriteBatch:
  /// 1. Increment Stock level in products/{id} (FieldValue.increment(+qty))
  /// 2. Log stock movement in products/{id}/changes
  /// 3. Create document in buying_invoices
  /// 4. Write audit entry into suppliers/{id}/balanceHistory
  /// 5. Update supplier totalBalance/balance in suppliers/{id}
  Future<String> createBuyingInvoice({
    required String supplierId,
    required String supplierName,
    required String invoiceNumber,
    required String paymentMethod, // 'Cash', 'Credit', 'Card', 'Check'
    required List<Map<String, dynamic>> items, // [{productId, productName, quantity, costPrice, total}]
    required double subtotal,
    required double discount,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    final batch = _firestore.batch();
    final invoiceRef = _firestore.collection('buying_invoices').doc();
    final invoiceId = invoiceRef.id;
    final timestamp = invoiceDate != null ? Timestamp.fromDate(invoiceDate) : FieldValue.serverTimestamp();

    // 1. Write Buying Invoice document
    batch.set(invoiceRef, {
      'invoiceNumber': invoiceNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'paymentMethod': paymentMethod,
      'items': items,
      'subtotal': subtotal,
      'discount': discount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'notes': notes ?? '',
      'isReturn': false,
      'date': timestamp,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Increment inventory stock & log changes
    for (final item in items) {
      final String productId = item['productId'] ?? '';
      final int qty = (item['quantity'] ?? 0) is int
          ? item['quantity']
          : (item['quantity'] as num).toInt();

      if (productId.isNotEmpty && qty > 0) {
        final productRef = _firestore.collection('products').doc(productId);
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(qty),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final changeRef = productRef.collection('changes').doc();
        batch.set(changeRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'quantityChange': qty,
          'operationType': 'buying_invoice',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'productName': item['productName'] ?? '',
        });
      }
    }

    // 3. Update Supplier Balance & write balanceHistory
    if (supplierId.isNotEmpty) {
      final supplierRef = _firestore.collection('suppliers').doc(supplierId);
      batch.update(supplierRef, {
        'totalBalance': FieldValue.increment(remainingAmount),
        'balance': FieldValue.increment(remainingAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final historyRef = supplierRef.collection('balanceHistory').doc();
      batch.set(historyRef, {
        'type': 'buying_invoice',
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'amount': remainingAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return invoiceId;
  }

  /// Process Purchase Return with atomic WriteBatch:
  /// 1. Decrement Stock level in products/{id} (FieldValue.increment(-qty))
  /// 2. Log stock movement in products/{id}/changes
  /// 3. Create document in purchase_returns
  /// 4. Write entry into suppliers/{id}/balanceHistory (type: 'purchase_return')
  /// 5. Decrement supplier balance in suppliers/{id}
  Future<String> processPurchaseReturn({
    required String supplierId,
    required String supplierName,
    required String originalInvoiceId,
    required String originalInvoiceNumber,
    required String returnNumber,
    required List<Map<String, dynamic>> returnedItems, // [{productId, productName, quantity, costPrice, total}]
    required double returnTotalAmount,
    String? reason,
  }) async {
    final batch = _firestore.batch();
    final returnRef = _firestore.collection('purchase_returns').doc();
    final returnId = returnRef.id;

    // 1. Write Purchase Return document
    batch.set(returnRef, {
      'returnNumber': returnNumber,
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': returnedItems,
      'returnTotalAmount': returnTotalAmount,
      'reason': reason ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Decrement Stock level & log changes
    for (final item in returnedItems) {
      final String productId = item['productId'] ?? '';
      final int qty = (item['quantity'] ?? 0) is int
          ? item['quantity']
          : (item['quantity'] as num).toInt();

      if (productId.isNotEmpty && qty > 0) {
        final productRef = _firestore.collection('products').doc(productId);
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(-qty),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final changeRef = productRef.collection('changes').doc();
        batch.set(changeRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'quantityChange': -qty,
          'operationType': 'purchase_return',
          'invoiceId': returnId,
          'invoiceNumber': returnNumber,
          'productName': item['productName'] ?? '',
        });
      }
    }

    // 3. Update Supplier Balance & write balanceHistory
    if (supplierId.isNotEmpty) {
      final supplierRef = _firestore.collection('suppliers').doc(supplierId);
      batch.update(supplierRef, {
        'totalBalance': FieldValue.increment(-returnTotalAmount),
        'balance': FieldValue.increment(-returnTotalAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final historyRef = supplierRef.collection('balanceHistory').doc();
      batch.set(historyRef, {
        'type': 'purchase_return',
        'invoiceId': returnId,
        'invoiceNumber': returnNumber,
        'amount': -returnTotalAmount,
        'totalAmount': returnTotalAmount,
        'paidAmount': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return returnId;
  }

  /// Get Suppliers Stream from Firestore
  Stream<List<Map<String, dynamic>>> getSuppliersStream() {
    return _firestore
        .collection('suppliers')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Fetch & calculate Supplier Balance History
  /// Rules:
  /// - `type: 'opening'` MUST always evaluate as item #1 (starting at balanceBefore: 0.00).
  /// - UI movement table displays transactions in descending order (newest top),
  ///   with `type: 'opening'` anchored cleanly at the very bottom.
  Stream<List<SupplierBalanceRecord>> getSupplierBalanceHistoryStream(String supplierId) {
    return _firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('balanceHistory')
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => SupplierBalanceRecord.fromFirestore(doc))
          .toList();

      if (records.isEmpty) return [];

      SupplierBalanceRecord? openingRecord;
      final otherRecords = <SupplierBalanceRecord>[];

      for (final r in records) {
        if (r.type == 'opening' && openingRecord == null) {
          openingRecord = r;
        } else {
          otherRecords.add(r);
        }
      }

      // Sort other records chronologically for math evaluation
      otherRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final calculatedRecords = <SupplierBalanceRecord>[];
      double currentBalance = 0.0;

      if (openingRecord != null) {
        currentBalance = openingRecord.amount;
        calculatedRecords.add(SupplierBalanceRecord(
          id: openingRecord.id,
          type: 'opening',
          invoiceId: openingRecord.invoiceId,
          invoiceNumber: openingRecord.invoiceNumber,
          description: openingRecord.description,
          notes: openingRecord.notes,
          amount: openingRecord.amount,
          totalAmount: openingRecord.totalAmount,
          paidAmount: openingRecord.paidAmount,
          balanceBefore: 0.0,
          balanceAfter: currentBalance,
          timestamp: openingRecord.timestamp,
        ));
      }

      for (final r in otherRecords) {
        final double before = currentBalance;
        final double delta = r.amount;
        currentBalance += delta;

        calculatedRecords.add(SupplierBalanceRecord(
          id: r.id,
          type: r.type,
          invoiceId: r.invoiceId,
          invoiceNumber: r.invoiceNumber,
          description: r.description,
          notes: r.notes,
          amount: r.amount,
          totalAmount: r.totalAmount,
          paidAmount: r.paidAmount,
          balanceBefore: before,
          balanceAfter: currentBalance,
          timestamp: r.timestamp,
        ));
      }

      // Prepare UI list: descending order (newest first), with 'opening' anchored at the bottom
      final nonOpeningDesc = calculatedRecords
          .where((r) => r.type != 'opening')
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final openingItems = calculatedRecords.where((r) => r.type == 'opening').toList();

      return [...nonOpeningDesc, ...openingItems];
    });
  }

  /// Delete a Buying / Purchase Invoice with full confirmation,
  /// inventory stock deduction (reversing the purchase), and supplier balance reversal.
  static Future<bool> deleteBuyingInvoice({
    required BuildContext context,
    required Map<String, dynamic> invoiceData,
    VoidCallback? onSuccess,
  }) async {
    final invoiceNumber = invoiceData['invoiceNumber']?.toString() ?? 'INV-000';
    final invoiceId = invoiceData['id']?.toString() ?? invoiceData['invoiceId']?.toString() ?? '';

    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد معرف فاتورة الشراء')),
      );
      return false;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // 1. Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: Text(
            isArabic ? 'تأكيد حذف فاتورة الشراء' : 'Confirm Delete Buying Invoice',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isArabic
                ? 'هل أنت متأكد من حذف فاتورة الشراء رقم (#$invoiceNumber)؟\n(سيتم خصم الكميات المشتراة من المخزن وتعديل مستحقات المورد تلقائياً)'
                : 'Are you sure you want to delete Buying Invoice (#$invoiceNumber)?\n(Purchased stock quantities will be deducted from inventory and supplier balance will be adjusted automatically)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    // 2. Loading Overlay Dialog
    BuildContext? loadingDialogContext;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingCtx) {
          loadingDialogContext = loadingCtx;
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
                      isArabic
                          ? 'جاري حذف فاتورة الشراء وتعديل المخزون ورصيد المورد...'
                          : 'Deleting invoice & recalculating stock & balance...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    void closeLoading() {
      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      } else if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final items = (invoiceData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final totalAmount = (invoiceData['totalAmount'] ?? 0.0).toDouble();
      final paidAmount = (invoiceData['paidAmount'] ?? 0.0).toDouble();
      final remainingOwed = (invoiceData['remainingAmount'] ?? (totalAmount - paidAmount)).toDouble();

      String supplierId = invoiceData['supplierId']?.toString() ?? '';
      final supplierName = invoiceData['supplierName']?.toString() ?? '';

      if (supplierId.isEmpty && supplierName.isNotEmpty) {
        try {
          final sQuery = await firestore
              .collection('suppliers')
              .where('name', isEqualTo: supplierName)
              .limit(1)
              .get();
          if (sQuery.docs.isNotEmpty) {
            supplierId = sQuery.docs.first.id;
          }
        } catch (_) {}
      }

      // Resolve all product references before transaction
      final productRefs = <DocumentReference, int>{};
      for (final item in items) {
        final productId = item['productId']?.toString();
        final boughtQty = (item['quantity'] ?? 1) is int
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
          productRefs[productRef] = boughtQty;
        }
      }

      final supplierRef = supplierId.isNotEmpty ? firestore.collection('suppliers').doc(supplierId) : null;

      // Execute Atomic Transaction: ALL READS FIRST, THEN ALL WRITES
      await firestore.runTransaction((transaction) async {
        // --- PHASE 1: ALL READS ---
        final productSnapshots = <DocumentReference, DocumentSnapshot>{};
        for (final pRef in productRefs.keys) {
          productSnapshots[pRef] = await transaction.get(pRef);
        }

        DocumentSnapshot? sSnap;
        if (supplierRef != null && remainingOwed > 0) {
          sSnap = await transaction.get(supplierRef);
        }

        // --- PHASE 2: ALL WRITES ---
        // A. Reverse Stock Quantities (Deduct the purchased goods from warehouse)
        for (final entry in productRefs.entries) {
          final pRef = entry.key;
          final boughtQty = entry.value;
          final pSnap = productSnapshots[pRef];

          if (pSnap != null && pSnap.exists) {
            final currentStock = (pSnap.data() as Map<String, dynamic>?)?['stockQuantity'] ??
                (pSnap.data() as Map<String, dynamic>?)?['quantity'] ?? 0;
            final curInt = currentStock is int ? currentStock : int.tryParse(currentStock.toString()) ?? 0;
            final newStock = (curInt - boughtQty) < 0 ? 0 : (curInt - boughtQty);

            transaction.update(pRef, {
              'stockQuantity': newStock,
              'quantity': newStock,
            });

            // Log stock deduction in product changes
            final changeRef = pRef.collection('changes').doc();
            transaction.set(changeRef, {
              'date': FieldValue.serverTimestamp(),
              'amount': -boughtQty,
              'type': 'decrease',
              'notes': 'إلغاء فاتورة شراء #$invoiceNumber',
            });
          }
        }

        // B. Reverse Supplier Balance
        if (supplierRef != null && sSnap != null && sSnap.exists && remainingOwed > 0) {
          final data = sSnap.data() as Map<String, dynamic>;
          final currentBal = (data['balance'] ?? 0.0).toDouble();
          final newBal = currentBal - remainingOwed;

          transaction.update(supplierRef, {'balance': newBal});

          final historyRef = supplierRef.collection('balanceHistory').doc();
          transaction.set(historyRef, {
            'type': 'cancellation',
            'description': 'إلغاء فاتورة شراء #$invoiceNumber',
            'invoiceId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'amount': -remainingOwed,
            'balanceBefore': currentBal,
            'balanceAfter': newBal,
            'timestamp': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // C. Delete Root Buying Invoice Document
        final rootInvoiceRef = firestore.collection('buying_invoices').doc(invoiceId);
        transaction.delete(rootInvoiceRef);

        // D. Delete Supplier Sub-document Invoice (if exists)
        if (supplierId.isNotEmpty) {
          final subInvoiceRef = firestore
              .collection('suppliers')
              .doc(supplierId)
              .collection('invoices')
              .doc(invoiceId);
          transaction.delete(subInvoiceRef);
        }
      });

      // Cleanup balance history docs matching this invoice number
      if (supplierId.isNotEmpty) {
        try {
          final bhQuery = await firestore
              .collection('suppliers')
              .doc(supplierId)
              .collection('balanceHistory')
              .where('invoiceNumber', isEqualTo: invoiceNumber)
              .get();
          final cleanupBatch = firestore.batch();
          for (final doc in bhQuery.docs) {
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
              isArabic
                  ? 'تم حذف فاتورة الشراء (#$invoiceNumber) وتعديل المخزون ورصيد المورد بنجاح'
                  : 'Buying invoice (#$invoiceNumber) deleted & stock/balance updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      onSuccess?.call();
      return true;
    } catch (e) {
      closeLoading();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting buying invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Delete Supplier and clean up subcollections from Firebase
  Future<void> deleteSupplier(String supplierId) async {
    final supplierRef = _firestore.collection('suppliers').doc(supplierId);

    // Delete subcollections
    final subcollections = ['invoices', 'balanceHistory', 'returns'];
    for (final sub in subcollections) {
      final snap = await supplierRef.collection(sub).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    // Delete root document
    await supplierRef.delete();
  }

  /// Delete a supplier balance history record & adjust supplier balance
  Future<void> deleteBalanceRecord({
    required String supplierId,
    required SupplierBalanceRecord record,
  }) async {
    final supplierRef = _firestore.collection('suppliers').doc(supplierId);
    final historyRef = supplierRef.collection('balanceHistory').doc(record.id);

    final isPayment = record.type == 'payment' || record.type == 'purchase_return';
    final double balanceAdjustment;

    if (isPayment) {
      // Reversing a payment: add the amount back to supplier's owed balance
      balanceAdjustment = record.amount.abs();
    } else {
      // Reversing a debt/invoice: subtract from supplier's owed balance
      balanceAdjustment = -record.amount.abs();
    }

    final batch = _firestore.batch();
    batch.update(supplierRef, {
      'balance': FieldValue.increment(balanceAdjustment),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(historyRef);
    await batch.commit();
  }
}

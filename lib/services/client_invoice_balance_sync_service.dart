import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/services/current_user_service.dart';

class SalesInvoiceCreationResult {
  final String invoiceId;
  final double previousBalance;
  final double balanceAfter;

  const SalesInvoiceCreationResult({
    required this.invoiceId,
    required this.previousBalance,
    required this.balanceAfter,
  });
}

/// Helper class to represent a client balance history item
class ClientBalanceRecord {
  final String id;
  final String type; // 'opening', 'sales_invoice', 'sales_return', 'payment'
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
  final int entryOrder;

  ClientBalanceRecord({
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
    this.entryOrder = 0,
  });

  factory ClientBalanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final type = data['type']?.toString() ?? 'transaction';
    final rawNotes = data['notes']?.toString().trim() ?? '';
    final rawDesc = data['description']?.toString().trim() ?? '';
    var invoiceNumber = data['invoiceNumber']?.toString().trim() ?? '';
    if (invoiceNumber.isEmpty) {
      invoiceNumber =
          RegExp(r'#([^\s]+)').firstMatch(rawDesc)?.group(1)?.trim() ?? '';
    }
    final isGeneric =
        rawDesc == 'تحصيل دفعة نقداً' ||
        rawDesc == 'تحصيل دفعة مالية' ||
        rawDesc == 'إضافة مديونية' ||
        rawDesc.startsWith('تحصيل من فاتورة #') ||
        rawDesc.startsWith('تعديل قيمة فاتورة #') ||
        rawDesc.startsWith('فاتورة مبيعات معدلة #') ||
        rawDesc.startsWith('نقل فاتورة #');
    final extractedNotes =
        rawNotes.isNotEmpty
            ? rawNotes
            : (!isGeneric && rawDesc.isNotEmpty ? rawDesc : '');

    return ClientBalanceRecord(
      id: doc.id,
      type: type,
      invoiceId: data['invoiceId'] ?? '',
      invoiceNumber: invoiceNumber,
      description: rawDesc,
      notes: extractedNotes,
      amount: (data['amount'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      balanceBefore: (data['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (data['balanceAfter'] ?? 0).toDouble(),
      timestamp: ClientInvoiceBalanceSyncService.parseInvoiceDate(
        data['timestamp'] ?? data['createdAt'],
      ),
      entryOrder:
          (data['entryOrder'] as num?)?.toInt() ??
          ClientInvoiceBalanceSyncService.defaultEntryOrder(type),
    );
  }
}

class ClientInvoiceBalanceSyncService {
  final FirebaseFirestore _firestore;

  ClientInvoiceBalanceSyncService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Safe Date Parsing Helper
  /// Handles Firestore Timestamp, Dart DateTime, ISO String, and int epoch timestamps.
  static DateTime parseInvoiceDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      // Handles both second and millisecond epochs
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

  /// Check online in Firestore for duplicate client name before creation
  Future<bool> isDuplicateClientName(String name, {String? excludeId}) async {
    final query =
        await _firestore
            .collection('clients')
            .where('name', isEqualTo: name.trim())
            .get();

    if (excludeId != null) {
      return query.docs.any((doc) => doc.id != excludeId);
    }
    return query.docs.isNotEmpty;
  }

  /// Create a new Client document with opening balance & balanceHistory
  Future<String> createClient({
    required String name,
    required String phone,
    String? address,
    double openingBalance = 0.0,
  }) async {
    final trimmedName = name.trim();

    // Check duplicate
    final isDup = await isDuplicateClientName(trimmedName);
    if (isDup) {
      throw Exception('Client with name "$trimmedName" already exists.');
    }

    final clientRef = _firestore.collection('clients').doc();
    final clientId = clientRef.id;

    final batch = _firestore.batch();

    batch.set(clientRef, {
      'name': trimmedName,
      'phone': phone.trim(),
      'address': address?.trim() ?? '',
      'balance': openingBalance,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write opening document in clients/{id}/balanceHistory
    final historyRef = clientRef.collection('balanceHistory').doc();
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
      'entryOrder': 0,
    });

    await batch.commit();
    return clientId;
  }

  /// Create a sales invoice atomically, using the client's live balance as the
  /// invoice's previous balance.
  /// 1. Decrement Stock level in products/{id} (FieldValue.increment(-qty))
  /// 2. Log stock movement in products/{id}/changes
  /// 3. Create document in sales_invoices
  /// 4. Write audit entry into clients/{id}/balanceHistory
  /// 5. Update client remaining balance in clients/{id}
  Future<SalesInvoiceCreationResult> createSalesInvoice({
    required String clientId,
    required String clientName,
    String? clientPhone,
    required String invoiceNumber,
    required String paymentMethod, // 'Cash', 'Credit', 'Card', 'Check'
    required List<Map<String, dynamic>>
    items, // [{productId, productName, quantity, price, total}]
    required double subtotal,
    required double discount,
    List<Map<String, dynamic>>? additionalFees,
    String? additionalFeeName,
    double additionalFeeAmount = 0.0,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    final invoiceRef = _firestore.collection('sales_invoices').doc();
    final invoiceId = invoiceRef.id;
    final timestamp =
        invoiceDate != null
            ? Timestamp.fromDate(invoiceDate)
            : FieldValue.serverTimestamp();

    final clientRef = _firestore.collection('clients').doc(clientId);
    final productRefs = _productRefsById(items);

    return _firestore.runTransaction((transaction) async {
      // Firestore requires every read to happen before the first write.
      final clientSnapshot = await transaction.get(clientRef);
      final productSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in productRefs.entries) {
        productSnapshots[entry.key] = await transaction.get(entry.value);
      }
      final runningProductStock = {
        for (final entry in productSnapshots.entries)
          entry.key: _stockFromSnapshot(entry.value),
      };
      if (!clientSnapshot.exists) {
        throw StateError('Client $clientId no longer exists.');
      }

      final clientData = clientSnapshot.data() ?? const <String, dynamic>{};
      final rawBalance = clientData['balance'] ?? 0.0;
      final previousBalance =
          rawBalance is num
              ? rawBalance.toDouble()
              : double.tryParse(rawBalance.toString()) ?? 0.0;
      final balanceAfter = previousBalance + remainingAmount;

      transaction.set(invoiceRef, {
        'invoiceNumber': invoiceNumber,
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': clientPhone ?? '',
        'paymentMethod': paymentMethod,
        'items': items,
        'subtotal': subtotal,
        'discount': discount,
        'additionalFees': additionalFees ?? [],
        'additionalFeeName': additionalFeeName ?? '',
        'additionalFeeAmount': additionalFeeAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'previousBalance': previousBalance,
        'clientPreviousBalance': previousBalance,
        'balanceAfter': balanceAfter,
        'clientBalance': balanceAfter,
        'notes': notes ?? '',
        'isReturn': false,
        'date': timestamp,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final item in items) {
        final productId = item['productId']?.toString() ?? '';
        final rawQuantity = item['quantity'] ?? 0.0;
        final quantity =
            rawQuantity is num
                ? rawQuantity.toDouble()
                : double.tryParse(rawQuantity.toString()) ?? 0.0;

        if (productId.isEmpty || quantity <= 0) continue;
        final productRef = productRefs[productId]!;
        final stockBefore = runningProductStock[productId] ?? 0.0;
        final stockAfter = stockBefore - quantity;
        runningProductStock[productId] = stockAfter;
        transaction.update(productRef, {
          'stockQuantity': FieldValue.increment(-quantity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(productRef.collection('changes').doc(), {
          'timestamp': FieldValue.serverTimestamp(),
          'quantityChange': -quantity,
          'operationType': 'sales_invoice',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'productName': item['productName'] ?? '',
        });
        _setStockLog(
          transaction,
          productId: productId,
          productName: item['productName']?.toString() ?? '',
          type: 'outgoing',
          quantity: quantity,
          stockBefore: stockBefore,
          stockAfter: stockAfter,
          referenceId: invoiceId,
          note: 'Sales invoice #$invoiceNumber',
        );
      }

      transaction.update(clientRef, {
        'balance': balanceAfter,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(clientRef.collection('balanceHistory').doc(), {
        'type': 'sales_invoice',
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'amount': totalAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'balanceBefore': previousBalance,
        'balanceAfter': previousBalance + totalAmount,
        'timestamp': timestamp,
        'entryOrder': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (paidAmount > 0) {
        transaction.set(clientRef.collection('balanceHistory').doc(), {
          'type': 'payment',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'description': 'تحصيل من فاتورة #$invoiceNumber',
          'amount': paidAmount,
          'totalAmount': totalAmount,
          'paidAmount': paidAmount,
          'balanceBefore': previousBalance + totalAmount,
          'balanceAfter': balanceAfter,
          'timestamp': timestamp,
          'entryOrder': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return SalesInvoiceCreationResult(
        invoiceId: invoiceId,
        previousBalance: previousBalance,
        balanceAfter: balanceAfter,
      );
    });
  }

  /// Process Sales Return with atomic WriteBatch:
  /// 1. Increment Stock level in products/{id} (FieldValue.increment(+qty))
  /// 2. Log stock movement in products/{id}/changes
  /// 3. Create document in return_invoices & sales_returns
  /// 4. Write entry into clients/{id}/balanceHistory (type: 'sales_return')
  /// 5. Decrement client balance in clients/{id}
  Future<String> processSalesReturn({
    required String clientId,
    required String clientName,
    required String returnNumber,
    required List<Map<String, dynamic>> returnedItems,
    required double subtotal,
    required double discount,
    required double returnTotalAmount,
    required double refundAmount,
    DateTime? returnDate,
    String? reason,
    String? originalInvoiceId,
    String? originalInvoiceNumber,
  }) async {
    final batch = _firestore.batch();
    final returnRef = _firestore.collection('return_invoices').doc();
    final returnId = returnRef.id;
    final timestamp =
        returnDate != null
            ? Timestamp.fromDate(returnDate)
            : FieldValue.serverTimestamp();

    // 1. Write Sales Return document
    final returnData = {
      'returnNumber': returnNumber,
      'invoiceNumber': returnNumber,
      'originalInvoiceId': originalInvoiceId ?? '',
      'originalInvoiceNumber': originalInvoiceNumber ?? '',
      'clientId': clientId,
      'clientName': clientName,
      'items': returnedItems,
      'subtotal': subtotal,
      'discount': discount,
      'returnTotalAmount': returnTotalAmount,
      'totalAmount': returnTotalAmount,
      'paidAmount': refundAmount,
      'remainingAmount':
          (returnTotalAmount - refundAmount) < 0
              ? 0.0
              : (returnTotalAmount - refundAmount),
      'isReturn': true,
      'reason': reason ?? '',
      'notes': reason ?? '',
      'date': timestamp,
      'createdAt': FieldValue.serverTimestamp(),
    };

    batch.set(returnRef, returnData);
    batch.set(_firestore.collection('sales_returns').doc(returnId), returnData);

    // 2. Increment Stock level & log changes
    for (final item in returnedItems) {
      final String productId = item['productId'] ?? '';
      final double qty =
          (item['quantity'] ?? 0.0) is num
              ? (item['quantity'] as num).toDouble()
              : double.tryParse(item['quantity'].toString()) ?? 0.0;

      if (productId.isNotEmpty && qty > 0) {
        final productRef = _firestore.collection('products').doc(productId);
        final productSnapshot = await productRef.get();
        final stockBefore = _stockFromSnapshot(productSnapshot);
        final stockAfter = stockBefore + qty;
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(qty),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final changeRef = productRef.collection('changes').doc();
        batch.set(changeRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'quantityChange': qty,
          'operationType': 'sales_return',
          'invoiceId': returnId,
          'invoiceNumber': returnNumber,
          'productName': item['productName'] ?? '',
        });
        _setStockLogInBatch(
          batch,
          productId: productId,
          productName: item['productName']?.toString() ?? '',
          type: 'incoming',
          quantity: qty,
          stockBefore: stockBefore,
          stockAfter: stockAfter,
          referenceId: returnId,
          note: 'Sales return #$returnNumber',
        );
      }
    }

    // 3. Update Client Balance & write balanceHistory
    if (clientId.isNotEmpty) {
      final clientRef = _firestore.collection('clients').doc(clientId);
      final netCredit = returnTotalAmount - refundAmount;
      batch.update(clientRef, {
        'balance': FieldValue.increment(-netCredit),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record 1: Return Invoice Total (Reduces debt by returnTotalAmount)
      final historyRef1 = clientRef.collection('balanceHistory').doc();
      batch.set(historyRef1, {
        'type': 'sales_return',
        'invoiceId': returnId,
        'invoiceNumber': returnNumber,
        'amount': returnTotalAmount,
        'totalAmount': returnTotalAmount,
        'paidAmount': refundAmount,
        'timestamp': timestamp,
        'entryOrder': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Record 2: Refunded Cash Amount (if refundAmount > 0)
      if (refundAmount > 0) {
        final historyRef2 = clientRef.collection('balanceHistory').doc();
        batch.set(historyRef2, {
          'type': 'manual_debt',
          'invoiceId': returnId,
          'invoiceNumber': returnNumber,
          'description': 'استرداد نقدي لمرتجع #$returnNumber',
          'amount': refundAmount,
          'totalAmount': returnTotalAmount,
          'paidAmount': refundAmount,
          'timestamp': timestamp,
          'entryOrder': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return returnId;
  }

  /// Get Client Stream from Firestore
  Stream<List<Map<String, dynamic>>> getClientsStream() {
    return _firestore.collection('clients').orderBy('name').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Fetch & calculate Client Balance History
  /// Rules:
  /// - `type: 'opening'` MUST always evaluate as item #1 (starting at balanceBefore: 0.00).
  /// - UI movement table displays transactions in descending order (newest top),
  ///   with `type: 'opening'` anchored cleanly at the very bottom.
  Stream<List<ClientBalanceRecord>> getClientBalanceHistoryStream(
    String clientId,
  ) {
    final clientRef = _firestore.collection('clients').doc(clientId);
    return clientRef.collection('balanceHistory').snapshots().asyncMap((
      snapshot,
    ) async {
      final records =
          snapshot.docs
              .map((doc) => ClientBalanceRecord.fromFirestore(doc))
              .toList();

      if (records.isEmpty) return [];

      double? clientBalance;
      try {
        final clientSnapshot = await clientRef.get();
        final rawBalance = clientSnapshot.data()?['balance'];
        clientBalance =
            rawBalance is num
                ? rawBalance.toDouble()
                : double.tryParse(rawBalance?.toString() ?? '');
      } catch (_) {
        // The history can still be displayed from its own ledger if the
        // client document is temporarily unavailable.
      }

      return calculateBalanceHistory(
        records: records,
        currentClientBalance: clientBalance,
      );
    });
  }

  /// Builds a deterministic newest-first ledger and recalculates every
  /// balance. [currentClientBalance] is treated as the source of truth, so the
  /// newest record always matches the balance stored on the client document.
  static List<ClientBalanceRecord> calculateBalanceHistory({
    required List<ClientBalanceRecord> records,
    double? currentClientBalance,
  }) {
    if (records.isEmpty) return [];

    ClientBalanceRecord? openingRecord;
    final chronological = <ClientBalanceRecord>[];
    for (final record in records) {
      if (record.type == 'opening' && openingRecord == null) {
        openingRecord = record;
      } else {
        chronological.addAll(_expandLegacyInvoiceRecord(record));
      }
    }

    chronological.sort(_compareChronologically);
    final ordered = <ClientBalanceRecord>[
      if (openingRecord != null) openingRecord,
      ...chronological,
    ];

    final ledgerDelta = ordered.fold<double>(
      0.0,
      (total, record) => total + signedAmount(record),
    );
    var runningBalance =
        currentClientBalance == null ? 0.0 : currentClientBalance - ledgerDelta;

    final calculated = <ClientBalanceRecord>[];
    for (final record in ordered) {
      final balanceBefore = runningBalance;
      runningBalance += signedAmount(record);
      calculated.add(
        ClientBalanceRecord(
          id: record.id,
          type: record.type,
          invoiceId: record.invoiceId,
          invoiceNumber: record.invoiceNumber,
          description: record.description,
          notes: record.notes,
          amount: record.amount,
          totalAmount: record.totalAmount,
          paidAmount: record.paidAmount,
          balanceBefore: balanceBefore,
          balanceAfter: runningBalance,
          timestamp: record.timestamp,
          entryOrder: record.entryOrder,
        ),
      );
    }

    // Reversing the exact calculation order is important. A payment created
    // with an invoice is calculated after its total and therefore appears
    // above that total in the newest-first UI with the final balance.
    final nonOpeningNewestFirst =
        calculated
            .where((record) => record.type != 'opening')
            .toList()
            .reversed
            .toList();
    final openingItems =
        calculated.where((record) => record.type == 'opening').toList();

    return [...nonOpeningNewestFirst, ...openingItems];
  }

  static List<ClientBalanceRecord> _expandLegacyInvoiceRecord(
    ClientBalanceRecord record,
  ) {
    final needsSplit =
        record.type == 'sales_invoice' &&
        record.totalAmount > 0 &&
        record.paidAmount > 0 &&
        record.amount != record.totalAmount;
    if (!needsSplit) return [record];

    return [
      ClientBalanceRecord(
        id: '${record.id}_total',
        type: 'sales_invoice',
        invoiceId: record.invoiceId,
        invoiceNumber: record.invoiceNumber,
        description: record.description,
        notes: record.notes,
        amount: record.totalAmount,
        totalAmount: record.totalAmount,
        paidAmount: record.paidAmount,
        timestamp: record.timestamp,
        entryOrder: 0,
      ),
      ClientBalanceRecord(
        id: '${record.id}_paid',
        type: 'payment',
        invoiceId: record.invoiceId,
        invoiceNumber: record.invoiceNumber,
        description: record.description,
        notes: record.notes,
        amount: record.paidAmount,
        totalAmount: record.totalAmount,
        paidAmount: record.paidAmount,
        timestamp: record.timestamp,
        entryOrder: 1,
      ),
    ];
  }

  static int _compareChronologically(
    ClientBalanceRecord a,
    ClientBalanceRecord b,
  ) {
    final timestampComparison = a.timestamp.compareTo(b.timestamp);
    if (timestampComparison != 0) return timestampComparison;

    final orderComparison = a.entryOrder.compareTo(b.entryOrder);
    if (orderComparison != 0) return orderComparison;
    return a.id.compareTo(b.id);
  }

  static int defaultEntryOrder(String type) => type == 'payment' ? 1 : 0;

  static double signedAmount(ClientBalanceRecord record) {
    return _isReductionType(record.type) ? -record.amount : record.amount;
  }

  static bool _isReductionType(String type) {
    return type == 'payment' ||
        type == 'sales_return' ||
        type == 'cancellation' ||
        type == 'discount' ||
        type == 'decrease';
  }

  /// Update Client Info (Name, Phone, Address)
  Future<void> updateClient({
    required String clientId,
    required String name,
    required String phone,
    required String address,
  }) async {
    await _firestore.collection('clients').doc(clientId).update({
      'name': name,
      'phone': phone,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, DocumentReference<Map<String, dynamic>>> _productRefsById(
    List<Map<String, dynamic>> items,
  ) {
    final refs = <String, DocumentReference<Map<String, dynamic>>>{};

    for (final item in items) {
      final productId = item['productId']?.toString() ?? '';
      final rawQuantity = item['quantity'] ?? 0.0;
      final quantity =
          rawQuantity is num
              ? rawQuantity.toDouble()
              : double.tryParse(rawQuantity.toString()) ?? 0.0;
      if (productId.isEmpty || quantity <= 0) continue;
      refs[productId] = _firestore.collection('products').doc(productId);
    }

    return refs;
  }

  static double _stockFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final data = snapshot?.data();
    final rawStock = data?['stockQuantity'] ?? data?['quantity'] ?? 0;
    return rawStock is num
        ? rawStock.toDouble()
        : double.tryParse(rawStock.toString()) ?? 0.0;
  }

  static void _setStockLog(
    Transaction transaction, {
    required String productId,
    required String productName,
    required String type,
    required double quantity,
    required double stockBefore,
    required double stockAfter,
    required String referenceId,
    required String note,
  }) {
    final logRef = FirebaseFirestore.instance.collection('stock_logs').doc();
    transaction.set(
      logRef,
      _stockLogData(
        productId: productId,
        productName: productName,
        type: type,
        quantity: quantity,
        stockBefore: stockBefore,
        stockAfter: stockAfter,
        referenceId: referenceId,
        note: note,
      ),
    );
  }

  static void _setStockLogInBatch(
    WriteBatch batch, {
    required String productId,
    required String productName,
    required String type,
    required double quantity,
    required double stockBefore,
    required double stockAfter,
    required String referenceId,
    required String note,
  }) {
    final logRef = FirebaseFirestore.instance.collection('stock_logs').doc();
    batch.set(
      logRef,
      _stockLogData(
        productId: productId,
        productName: productName,
        type: type,
        quantity: quantity,
        stockBefore: stockBefore,
        stockAfter: stockAfter,
        referenceId: referenceId,
        note: note,
      ),
    );
  }

  static Map<String, dynamic> _stockLogData({
    required String productId,
    required String productName,
    required String type,
    required double quantity,
    required double stockBefore,
    required double stockAfter,
    required String referenceId,
    required String note,
  }) {
    return {
      'productId': productId,
      'productName': productName,
      'type': type,
      'quantity': quantity,
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
      'referenceId': referenceId,
      'note': note,
      'createdBy': CurrentUserService.instance.userName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Delete Client and clean up client sub-collections
  Future<void> deleteClient(String clientId) async {
    final clientRef = _firestore.collection('clients').doc(clientId);
    final batch = _firestore.batch();

    final subcollections = ['invoices', 'balanceHistory', 'returns'];
    for (final sub in subcollections) {
      final snap = await clientRef.collection(sub).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    // Delete root document
    batch.delete(clientRef);
    await batch.commit();
  }

  /// Delete a client balance history record & adjust client balance
  Future<void> deleteBalanceRecord({
    required String clientId,
    required ClientBalanceRecord record,
  }) async {
    final docId = record.id.split('_').first;
    final batch = _firestore.batch();
    final historyRef = _firestore
        .collection('clients')
        .doc(clientId)
        .collection('balanceHistory')
        .doc(docId);

    final isReduction =
        record.type == 'payment' ||
        record.type == 'sales_return' ||
        record.type == 'cancellation' ||
        record.type == 'discount' ||
        record.type == 'decrease';

    final double adjustment = isReduction ? record.amount : -record.amount;

    final clientRef = _firestore.collection('clients').doc(clientId);
    batch.update(clientRef, {
      'balance': FieldValue.increment(adjustment),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(historyRef);
    await batch.commit();
  }

  /// Update a client balance history record & adjust client balance
  Future<void> updateBalanceRecord({
    required String clientId,
    required ClientBalanceRecord oldRecord,
    required double newAmount,
    required String newType,
    DateTime? newDate,
    String? newNotes,
  }) async {
    final docId = oldRecord.id.split('_').first;
    final batch = _firestore.batch();
    final historyRef = _firestore
        .collection('clients')
        .doc(clientId)
        .collection('balanceHistory')
        .doc(docId);

    // 1. Revert old record impact
    final oldIsReduction =
        oldRecord.type == 'payment' ||
        oldRecord.type == 'sales_return' ||
        oldRecord.type == 'cancellation' ||
        oldRecord.type == 'discount' ||
        oldRecord.type == 'decrease';
    final double revertAdjustment =
        oldIsReduction ? oldRecord.amount : -oldRecord.amount;

    // 2. Apply new record impact
    final newIsReduction =
        newType == 'payment' ||
        newType == 'sales_return' ||
        newType == 'cancellation' ||
        newType == 'discount' ||
        newType == 'decrease';
    final double applyAdjustment = newIsReduction ? -newAmount : newAmount;

    final double totalBalanceChange = revertAdjustment + applyAdjustment;

    final clientRef = _firestore.collection('clients').doc(clientId);
    batch.update(clientRef, {
      'balance': FieldValue.increment(totalBalanceChange),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final Map<String, dynamic> updateData = {
      'amount': newAmount,
      'type': newType,
      'entryOrder': defaultEntryOrder(newType),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newDate != null) updateData['timestamp'] = Timestamp.fromDate(newDate);
    if (newNotes != null) {
      updateData['description'] = newNotes;
      updateData['notes'] = newNotes;
    }

    batch.update(historyRef, updateData);
    await batch.commit();
  }
}

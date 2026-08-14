import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory ClientBalanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawNotes = data['notes']?.toString().trim() ?? '';
    final rawDesc = data['description']?.toString().trim() ?? '';
    final isGeneric = rawDesc == 'تحصيل دفعة نقداً' ||
        rawDesc == 'تحصيل دفعة مالية' ||
        rawDesc == 'إضافة مديونية' ||
        rawDesc.startsWith('تحصيل من فاتورة #') ||
        rawDesc.startsWith('تعديل قيمة فاتورة #') ||
        rawDesc.startsWith('فاتورة مبيعات معدلة #') ||
        rawDesc.startsWith('نقل فاتورة #');
    final extractedNotes = rawNotes.isNotEmpty
        ? rawNotes
        : (!isGeneric && rawDesc.isNotEmpty ? rawDesc : '');

    return ClientBalanceRecord(
      id: doc.id,
      type: data['type'] ?? 'transaction',
      invoiceId: data['invoiceId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      description: rawDesc,
      notes: extractedNotes,
      amount: (data['amount'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      balanceBefore: (data['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (data['balanceAfter'] ?? 0).toDouble(),
      timestamp: ClientInvoiceBalanceSyncService.parseInvoiceDate(data['timestamp']),
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
    final query = await _firestore
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
    });

    await batch.commit();
    return clientId;
  }

  /// Create Sales Invoice with atomic WriteBatch:
  /// 1. Decrement Stock level in products/{id} (FieldValue.increment(-qty))
  /// 2. Log stock movement in products/{id}/changes
  /// 3. Create document in sales_invoices
  /// 4. Write audit entry into clients/{id}/balanceHistory
  /// 5. Update client remaining balance in clients/{id}
  Future<String> createSalesInvoice({
    required String clientId,
    required String clientName,
    required String invoiceNumber,
    required String paymentMethod, // 'Cash', 'Credit', 'Card', 'Check'
    required List<Map<String, dynamic>> items, // [{productId, productName, quantity, price, total}]
    required double subtotal,
    required double discount,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    final batch = _firestore.batch();
    final invoiceRef = _firestore.collection('sales_invoices').doc();
    final invoiceId = invoiceRef.id;
    final timestamp = invoiceDate != null ? Timestamp.fromDate(invoiceDate) : FieldValue.serverTimestamp();

    // 1. Write Invoice document
    batch.set(invoiceRef, {
      'invoiceNumber': invoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
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

    // 2. Decrement inventory stock & log changes
    for (final item in items) {
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
          'operationType': 'sales_invoice',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'productName': item['productName'] ?? '',
        });
      }
    }

    // 3. Update Client Balance & write balanceHistory
    if (clientId.isNotEmpty) {
      final clientRef = _firestore.collection('clients').doc(clientId);
      batch.update(clientRef, {
        'balance': FieldValue.increment(remainingAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record 1: Full Invoice Total
      final historyRef1 = clientRef.collection('balanceHistory').doc();
      batch.set(historyRef1, {
        'type': 'sales_invoice',
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'amount': totalAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Record 2: Paid Amount (if > 0)
      if (paidAmount > 0) {
        final historyRef2 = clientRef.collection('balanceHistory').doc();
        batch.set(historyRef2, {
          'type': 'payment',
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'description': 'تحصيل من فاتورة #$invoiceNumber',
          'amount': paidAmount,
          'totalAmount': totalAmount,
          'paidAmount': paidAmount,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return invoiceId;
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
    final timestamp = returnDate != null ? Timestamp.fromDate(returnDate) : FieldValue.serverTimestamp();

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
      'remainingAmount': (returnTotalAmount - refundAmount) < 0 ? 0.0 : (returnTotalAmount - refundAmount),
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
          'operationType': 'sales_return',
          'invoiceId': returnId,
          'invoiceNumber': returnNumber,
          'productName': item['productName'] ?? '',
        });
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
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return returnId;
  }

  /// Get Client Stream from Firestore
  Stream<List<Map<String, dynamic>>> getClientsStream() {
    return _firestore
        .collection('clients')
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

  /// Fetch & calculate Client Balance History
  /// Rules:
  /// - `type: 'opening'` MUST always evaluate as item #1 (starting at balanceBefore: 0.00).
  /// - UI movement table displays transactions in descending order (newest top),
  ///   with `type: 'opening'` anchored cleanly at the very bottom.
  Stream<List<ClientBalanceRecord>> getClientBalanceHistoryStream(String clientId) {
    return _firestore
        .collection('clients')
        .doc(clientId)
        .collection('balanceHistory')
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => ClientBalanceRecord.fromFirestore(doc))
          .toList();

      if (records.isEmpty) return [];

      // Separate opening and normal records
      ClientBalanceRecord? openingRecord;
      final otherRecords = <ClientBalanceRecord>[];

      for (final r in records) {
        if (r.type == 'opening' && openingRecord == null) {
          openingRecord = r;
        } else {
          otherRecords.add(r);
        }
      }

      // Sort other records chronologically for math evaluation
      otherRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final calculatedRecords = <ClientBalanceRecord>[];
      double currentBalance = 0.0;

      if (openingRecord != null) {
        currentBalance = openingRecord.amount;
        calculatedRecords.add(ClientBalanceRecord(
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
        if (r.type == 'sales_invoice' && r.totalAmount > 0 && r.paidAmount > 0 && r.amount != r.totalAmount) {
          // Legacy single record split into 2 accounting entries:
          // 1. Invoice Total entry (+)
          final double beforeTotal = currentBalance;
          currentBalance += r.totalAmount;
          calculatedRecords.add(ClientBalanceRecord(
            id: '${r.id}_total',
            type: 'sales_invoice',
            invoiceId: r.invoiceId,
            invoiceNumber: r.invoiceNumber,
            description: r.description,
            notes: r.notes,
            amount: r.totalAmount,
            totalAmount: r.totalAmount,
            paidAmount: r.paidAmount,
            balanceBefore: beforeTotal,
            balanceAfter: currentBalance,
            timestamp: r.timestamp,
          ));

          // 2. Paid Amount entry (-)
          final double beforePaid = currentBalance;
          currentBalance -= r.paidAmount;
          calculatedRecords.add(ClientBalanceRecord(
            id: '${r.id}_paid',
            type: 'payment',
            invoiceId: r.invoiceId,
            invoiceNumber: r.invoiceNumber,
            description: r.description,
            notes: r.notes,
            amount: r.paidAmount,
            totalAmount: r.totalAmount,
            paidAmount: r.paidAmount,
            balanceBefore: beforePaid,
            balanceAfter: currentBalance,
            timestamp: r.timestamp,
          ));
        } else {
          final double before = currentBalance;
          final double delta = r.amount;

          final isReduction = r.type == 'payment' ||
              r.type == 'sales_return' ||
              r.type == 'cancellation' ||
              r.type == 'discount' ||
              r.type == 'decrease';

          if (isReduction) {
            currentBalance -= delta;
          } else {
            currentBalance += delta;
          }

          calculatedRecords.add(ClientBalanceRecord(
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

    final isReduction = record.type == 'payment' ||
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
    final oldIsReduction = oldRecord.type == 'payment' ||
        oldRecord.type == 'sales_return' ||
        oldRecord.type == 'cancellation' ||
        oldRecord.type == 'discount' ||
        oldRecord.type == 'decrease';
    final double revertAdjustment = oldIsReduction ? oldRecord.amount : -oldRecord.amount;

    // 2. Apply new record impact
    final newIsReduction = newType == 'payment' ||
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

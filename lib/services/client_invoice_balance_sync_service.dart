import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to represent a client balance history item
class ClientBalanceRecord {
  final String id;
  final String type; // 'opening', 'sales_invoice', 'sales_return', 'payment'
  final String invoiceId;
  final String invoiceNumber;
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
    required this.amount,
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    this.balanceBefore = 0.0,
    this.balanceAfter = 0.0,
    required this.timestamp,
  });

  factory ClientBalanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClientBalanceRecord(
      id: doc.id,
      type: data['type'] ?? 'transaction',
      invoiceId: data['invoiceId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
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

      final historyRef = clientRef.collection('balanceHistory').doc();
      batch.set(historyRef, {
        'type': 'sales_invoice',
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

  /// Process Sales Return with atomic WriteBatch:
  /// 1. Increment Stock level in products/{id} (FieldValue.increment(+qty))
  /// 2. Log stock movement in products/{id}/changes
  /// 3. Create document in sales_returns
  /// 4. Write entry into clients/{id}/balanceHistory (type: 'sales_return')
  /// 5. Decrement client balance in clients/{id}
  Future<String> processSalesReturn({
    required String clientId,
    required String clientName,
    required String originalInvoiceId,
    required String originalInvoiceNumber,
    required String returnNumber,
    required List<Map<String, dynamic>> returnedItems, // [{productId, productName, quantity, price, total}]
    required double returnTotalAmount,
    String? reason,
  }) async {
    final batch = _firestore.batch();
    final returnRef = _firestore.collection('sales_returns').doc();
    final returnId = returnRef.id;

    // 1. Write Sales Return document
    batch.set(returnRef, {
      'returnNumber': returnNumber,
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'items': returnedItems,
      'returnTotalAmount': returnTotalAmount,
      'reason': reason ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

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
      batch.update(clientRef, {
        'balance': FieldValue.increment(-returnTotalAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final historyRef = clientRef.collection('balanceHistory').doc();
      batch.set(historyRef, {
        'type': 'sales_return',
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

    // Delete subcollections
    final invoicesSnap = await clientRef.collection('invoices').get();
    for (final doc in invoicesSnap.docs) {
      await doc.reference.delete();
    }

    final historySnap = await clientRef.collection('balanceHistory').get();
    for (final doc in historySnap.docs) {
      await doc.reference.delete();
    }

    // Delete root document
    await clientRef.delete();
  }
}

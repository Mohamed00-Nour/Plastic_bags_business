import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/current_user_service.dart';
import '../models/supplier_model_new.dart';

class SupplierRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('suppliers');

  Stream<List<SupplierModel>> getSuppliers() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupplierModel.fromFirestore(doc))
            .toList());
  }

  Future<SupplierModel> getSupplier(String id) async {
    final doc = await _collection.doc(id).get();
    return SupplierModel.fromFirestore(doc);
  }

  Future<void> addSupplier(SupplierModel supplier) async {
    final data = supplier.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _collection.doc(supplier.id).set(data);
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    final data = supplier.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _collection.doc(supplier.id).update(data);
  }

  Future<void> deleteSupplier(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBalance(String supplierId, double amount) async {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      final snapshot = await _collection.doc(supplierId).get();
      final currentBalance =
          ((snapshot.data() as Map<String, dynamic>)['balance'] ?? 0.0 as num)
              .toDouble();
      await _collection.doc(supplierId).update({
        'balance': currentBalance + amount,
        'modifiedBy': CurrentUserService.instance.userName,
        'updatedAt': Timestamp.now(),
      });
    } else {
      await _firestore.runTransaction((transaction) async {
        final doc = _collection.doc(supplierId);
        final snapshot = await transaction.get(doc);
        final currentBalance =
            ((snapshot.data() as Map<String, dynamic>)['balance'] ?? 0.0 as num)
                .toDouble();
        transaction.update(doc, {
          'balance': currentBalance + amount,
          'modifiedBy': CurrentUserService.instance.userName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  Future<void> addToTotalSupplied(String supplierId, double amount) async {
    await _collection.doc(supplierId).update({
      'totalSupplied': FieldValue.increment(amount),
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

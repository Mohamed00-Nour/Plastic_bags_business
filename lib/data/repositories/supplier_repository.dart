import 'package:cloud_firestore/cloud_firestore.dart';
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
    await _collection.doc(supplier.id).set(supplier.toFirestore());
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    await _collection.doc(supplier.id).update(supplier.toFirestore());
  }

  Future<void> deleteSupplier(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBalance(String supplierId, double amount) async {
    await _firestore.runTransaction((transaction) async {
      final doc = _collection.doc(supplierId);
      final snapshot = await transaction.get(doc);
      final currentBalance =
          (snapshot.data() as Map<String, dynamic>)['balance'] ?? 0.0;
      transaction.update(doc, {
        'balance': (currentBalance as num).toDouble() + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addToTotalSupplied(String supplierId, double amount) async {
    await _collection.doc(supplierId).update({
      'totalSupplied': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

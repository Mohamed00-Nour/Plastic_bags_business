import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('transactions');

  Stream<List<TransactionModel>> getTransactions() {
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<TransactionModel>> getTransactionsByShop(String shopId) {
    return _collection
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<TransactionModel>> getTransactionsBySupplier(String supplierId) {
    return _collection
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _collection.doc(transaction.id).set(transaction.toFirestore());
  }

  Future<List<TransactionModel>> getTransactionsBetween(
      DateTime start, DateTime end) async {
    final snapshot = await _collection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
  }

  Future<List<TransactionModel>> getTransactionsByType(
      TransactionType type) async {
    final snapshot = await _collection
        .where('type', isEqualTo: type.name)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock_log_model.dart';

class StockLogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('stock_logs');

  Stream<List<StockLogModel>> getStockLogs() {
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockLogModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<StockLogModel>> getStockLogsByProduct(String productId) {
    return _collection
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockLogModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addLog(StockLogModel log) async {
    await _collection.doc(log.id).set(log.toFirestore());
  }

  Future<List<StockLogModel>> getLogsBetween(
      DateTime start, DateTime end) async {
    final snapshot = await _collection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => StockLogModel.fromFirestore(doc))
        .toList();
  }
}

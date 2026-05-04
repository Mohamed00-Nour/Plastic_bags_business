import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('orders');

  Stream<List<OrderModel>> getOrders() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<OrderModel>> getOrdersByStatus(OrderStatus status) {
    return _collection
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<OrderModel>> getOrdersByShop(String shopId) {
    return _collection
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Future<OrderModel> getOrder(String id) async {
    final doc = await _collection.doc(id).get();
    return OrderModel.fromFirestore(doc);
  }

  Future<void> createOrder(OrderModel order) async {
    await _collection.doc(order.id).set(order.toFirestore());
  }

  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? approvedBy,
    String? rejectionReason,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (approvedBy != null) updates['approvedBy'] = approvedBy;
    if (rejectionReason != null) updates['rejectionReason'] = rejectionReason;
    await _collection.doc(orderId).update(updates);
  }

  Future<List<OrderModel>> getOrdersBetween(
      DateTime start, DateTime end) async {
    final snapshot = await _collection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .toList();
  }
}

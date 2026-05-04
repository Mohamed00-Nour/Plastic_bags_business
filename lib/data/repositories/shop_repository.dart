import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model_new.dart';

class ShopRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('shops');

  Stream<List<ShopModel>> getShops() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShopModel.fromFirestore(doc)).toList());
  }

  Future<ShopModel> getShop(String id) async {
    final doc = await _collection.doc(id).get();
    return ShopModel.fromFirestore(doc);
  }

  Future<void> addShop(ShopModel shop) async {
    await _collection.doc(shop.id).set(shop.toFirestore());
  }

  Future<void> updateShop(ShopModel shop) async {
    await _collection.doc(shop.id).update(shop.toFirestore());
  }

  Future<void> deleteShop(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addToTotalPurchases(String shopId, double amount) async {
    await _collection.doc(shopId).update({
      'totalPurchases': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<ShopModel>> searchShops(String query) async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    final lowerQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => ShopModel.fromFirestore(doc))
        .where((shop) =>
            shop.name.toLowerCase().contains(lowerQuery) ||
            shop.phone.contains(query))
        .toList();
  }
}

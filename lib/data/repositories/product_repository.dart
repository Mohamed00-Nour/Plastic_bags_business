import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model_new.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('products');

  Stream<List<ProductModel>> getProducts() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  Future<ProductModel> getProduct(String id) async {
    final doc = await _collection.doc(id).get();
    return ProductModel.fromFirestore(doc);
  }

  Future<void> addProduct(ProductModel product) async {
    await _collection.doc(product.id).set(product.toFirestore());
  }

  Future<void> updateProduct(ProductModel product) async {
    await _collection.doc(product.id).update(product.toFirestore());
  }

  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStock(String productId, int newQuantity) async {
    await _collection.doc(productId).update({
      'stockQuantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementStock(String productId, int amount) async {
    await _collection.doc(productId).update({
      'stockQuantity': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decrementStock(String productId, int amount) async {
    await _firestore.runTransaction((transaction) async {
      final doc = _collection.doc(productId);
      final snapshot = await transaction.get(doc);
      final currentStock =
          (snapshot.data() as Map<String, dynamic>)['stockQuantity'] ?? 0;
      final newStock = (currentStock as int) - amount;
      if (newStock < 0) throw Exception('Insufficient stock');
      transaction.update(doc, {
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    final snapshot =
        await _collection.where('isActive', isEqualTo: true).get();
    return snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .where((p) => p.isLowStock)
        .toList();
  }

  Future<List<ProductModel>> getProductsBySupplier(String supplierId) async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .where('supplierId', isEqualTo: supplierId)
        .get();
    return snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .toList();
  }
}

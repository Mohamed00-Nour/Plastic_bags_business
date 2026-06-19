import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/current_user_service.dart';
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

  Future<ProductModel?> findByName(String name) async {
    final lower = name.toLowerCase();
    final snapshot =
        await _collection.where('isActive', isEqualTo: true).get();
    for (final doc in snapshot.docs) {
      final product = ProductModel.fromFirestore(doc);
      if (product.name.toLowerCase() == lower) return product;
    }
    return null;
  }

  Future<void> addProduct(ProductModel product) async {
    final data = product.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _collection.doc(product.id).set(data);
  }

  Future<void> updateProduct(ProductModel product) async {
    final data = product.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _collection.doc(product.id).update(data);
  }

  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStock(String productId, int newQuantity) async {
    await _collection.doc(productId).update({
      'stockQuantity': newQuantity,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementStock(String productId, int amount) async {
    await _collection.doc(productId).update({
      'stockQuantity': FieldValue.increment(amount),
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stockIn(String productId, int deltaQty, double newCostPrice) async {
    await _collection.doc(productId).update({
      'stockQuantity': FieldValue.increment(deltaQty),
      'costPrice': newCostPrice,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decrementStock(String productId, int amount) async {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      final snapshot = await _collection.doc(productId).get();
      final currentStock =
          ((snapshot.data() as Map<String, dynamic>)['stockQuantity'] ?? 0 as num)
              .toInt();
      final newStock = currentStock - amount;
      if (newStock < 0) throw Exception('Insufficient stock');
      await _collection.doc(productId).update({
        'stockQuantity': newStock,
        'modifiedBy': CurrentUserService.instance.userName,
        'updatedAt': Timestamp.now(),
      });
    } else {
      await _firestore.runTransaction((transaction) async {
        final doc = _collection.doc(productId);
        final snapshot = await transaction.get(doc);
        final currentStock =
            ((snapshot.data() as Map<String, dynamic>)['stockQuantity'] ?? 0
                    as num)
                .toInt();
        final newStock = currentStock - amount;
        if (newStock < 0) throw Exception('Insufficient stock');
        transaction.update(doc, {
          'stockQuantity': newStock,
          'modifiedBy': CurrentUserService.instance.userName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
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

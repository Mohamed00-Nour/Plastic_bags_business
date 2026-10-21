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
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            if (a.sortOrder != b.sortOrder) {
              return a.sortOrder.compareTo(b.sortOrder);
            }
            return a.name.compareTo(b.name);
          });
          return list;
        });
  }

  Future<void> reorderProducts(List<ProductModel> products) async {
    final batch = _firestore.batch();
    for (int i = 0; i < products.length; i++) {
      final docRef = _collection.doc(products[i].id);
      batch.update(docRef, {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
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
    final docRef = _collection.doc(id);
    final batch = _firestore.batch();
    try {
      final changesSnap = await docRef.collection('changes').get();
      for (final doc in changesSnap.docs) {
        batch.delete(doc.reference);
      }
    } catch (_) {}
    batch.delete(docRef);
    await batch.commit();
  }

  Future<void> updateStock(String productId, double newQuantity) async {
    await _collection.doc(productId).update({
      'stockQuantity': newQuantity,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementStock(String productId, double amount) async {
    await _collection.doc(productId).update({
      'stockQuantity': FieldValue.increment(amount),
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stockIn(String productId, double deltaQty, double newCostPrice) async {
    await _collection.doc(productId).update({
      'stockQuantity': FieldValue.increment(deltaQty),
      'costPrice': newCostPrice,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decrementStock(String productId, double amount) async {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      final snapshot = await _collection.doc(productId).get();
      final currentStock =
          ((snapshot.data() as Map<String, dynamic>)['stockQuantity'] ?? 0 as num)
              .toDouble();
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
                .toDouble();
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

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/material_supplier_model.dart';

class MaterialSupplierRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('material_suppliers');

  Stream<List<MaterialSupplierModel>> getAll() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(MaterialSupplierModel.fromFirestore).toList());
  }

  Stream<List<MaterialSupplierModel>> getActive() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(MaterialSupplierModel.fromFirestore).toList());
  }

  Future<MaterialSupplierModel?> findByName(String name) async {
    final lower = name.toLowerCase();
    final s = await _col.get();
    for (final doc in s.docs) {
      final supplier = MaterialSupplierModel.fromFirestore(doc);
      if (supplier.name.toLowerCase() == lower) return supplier;
    }
    return null;
  }

  Future<void> add(MaterialSupplierModel supplier) async {
    final data = supplier.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(supplier.id).set(data);
  }

  Future<void> update(MaterialSupplierModel supplier) async {
    final data = supplier.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _col.doc(supplier.id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).update({
      'isActive': false,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}

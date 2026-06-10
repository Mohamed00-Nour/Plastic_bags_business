import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/raw_material_model.dart';

class RawMaterialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('manufacturing_materials');

  Stream<List<RawMaterialModel>> getAll() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(RawMaterialModel.fromFirestore).toList());
  }

  Future<List<RawMaterialModel>> getAllOnce() async {
    final s = await _col.orderBy('name').get();
    return s.docs.map(RawMaterialModel.fromFirestore).toList();
  }

  Future<void> add(RawMaterialModel material) async {
    final data = material.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(material.id).set(data);
  }

  Future<void> update(RawMaterialModel material) async {
    final data = material.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _col.doc(material.id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

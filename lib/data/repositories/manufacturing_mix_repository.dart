import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/manufacturing_mix_model.dart';

class ManufacturingMixRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('manufacturing_mixes');

  Stream<List<ManufacturingMixModel>> getAll() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((s) =>
            s.docs.map(ManufacturingMixModel.fromFirestore).toList());
  }

  Future<List<ManufacturingMixModel>> getAllOnce() async {
    final s = await _col.orderBy('name').get();
    return s.docs.map(ManufacturingMixModel.fromFirestore).toList();
  }

  Future<ManufacturingMixModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ManufacturingMixModel.fromFirestore(doc);
  }

  Future<void> add(ManufacturingMixModel mix) async {
    final data = mix.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(mix.id).set(data);
  }

  Future<void> update(ManufacturingMixModel mix) async {
    final data = mix.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _col.doc(mix.id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

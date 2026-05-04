import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> add(ManufacturingMixModel mix) async {
    await _col.doc(mix.id).set(mix.toFirestore());
  }

  Future<void> update(ManufacturingMixModel mix) async {
    await _col.doc(mix.id).update(mix.toFirestore());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/waste_machine_model.dart';

class WasteMachineRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col => _firestore.collection('waste_machines');

  Stream<List<WasteMachineModel>> getAll() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(WasteMachineModel.fromFirestore).toList());
  }

  Future<void> add(WasteMachineModel machine) async {
    final data = machine.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(machine.id).set(data);
  }

  Future<void> update(WasteMachineModel machine) async {
    final data = machine.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _col.doc(machine.id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

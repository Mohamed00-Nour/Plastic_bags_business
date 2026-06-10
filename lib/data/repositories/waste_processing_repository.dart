import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/waste_processing_run_model.dart';

class WasteProcessingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('waste_processing_runs');

  Stream<List<WasteProcessingRunModel>> getAll() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(WasteProcessingRunModel.fromFirestore).toList());
  }

  Future<List<WasteProcessingRunModel>> getByMachine(
      String machineId) async {
    final s = await _col
        .where('machineId', isEqualTo: machineId)
        .orderBy('date', descending: true)
        .get();
    return s.docs.map(WasteProcessingRunModel.fromFirestore).toList();
  }

  Future<List<WasteProcessingRunModel>> getBetween(
      DateTime start, DateTime end) async {
    final s = await _col
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();
    return s.docs.map(WasteProcessingRunModel.fromFirestore).toList();
  }

  Future<void> add(WasteProcessingRunModel run) async {
    await _col.doc(run.id).set(run.toFirestore());
  }

  Future<void> update(WasteProcessingRunModel run) async {
    final data = run.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _col.doc(run.id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

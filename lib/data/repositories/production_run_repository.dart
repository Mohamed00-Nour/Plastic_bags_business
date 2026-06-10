import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/production_run_model.dart';

class ProductionRunRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('production_runs');

  Stream<List<ProductionRunModel>> getAll() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(ProductionRunModel.fromFirestore).toList());
  }

  Future<List<ProductionRunModel>> getBetween(
      DateTime start, DateTime end) async {
    final s = await _col
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();
    return s.docs.map(ProductionRunModel.fromFirestore).toList();
  }

  Future<void> add(ProductionRunModel run) async {
    final data = run.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(run.id).set(data);
  }

  Future<void> update(ProductionRunModel run) async {
    final data = run.toFirestore();
    data['modifiedBy'] = CurrentUserService.instance.userName;
    await _col.doc(run.id).update(data);
  }

  Future<void> executeRun(String runId) async {
    await _col.doc(runId).update({
      'status': 'executed',
      'modifiedBy': CurrentUserService.instance.userName,
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

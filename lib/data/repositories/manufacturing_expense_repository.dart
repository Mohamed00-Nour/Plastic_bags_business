import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/manufacturing_expense_model.dart';

class ManufacturingExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('manufacturing_expenses');

  Stream<List<ManufacturingExpenseModel>> getAll() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(ManufacturingExpenseModel.fromFirestore).toList());
  }

  Future<List<ManufacturingExpenseModel>> getBetween(
      DateTime start, DateTime end) async {
    final s = await _col
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();
    return s.docs.map(ManufacturingExpenseModel.fromFirestore).toList();
  }

  Future<List<ManufacturingExpenseModel>> getByProductionRun(
      String runId) async {
    final s = await _col
        .where('productionRunId', isEqualTo: runId)
        .orderBy('createdAt', descending: true)
        .get();
    return s.docs.map(ManufacturingExpenseModel.fromFirestore).toList();
  }

  Future<void> add(ManufacturingExpenseModel expense) async {
    await _col.doc(expense.id).set(expense.toFirestore());
  }

  Future<void> update(ManufacturingExpenseModel expense) async {
    await _col.doc(expense.id).update(expense.toFirestore());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

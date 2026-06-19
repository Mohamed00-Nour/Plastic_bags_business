import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/damaged_inventory_model.dart';

class DamagedInventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('damaged_inventory');

  Future<List<DamagedInventoryModel>> getAllOnce() async {
    final s = await _col.orderBy('date', descending: true).get();
    return s.docs.map(DamagedInventoryModel.fromFirestore).toList();
  }

  Future<double> getTotalKg() async {
    final items = await getAllOnce();
    return items.fold<double>(
      0.0,
      (double sum, item) => sum + item.signedKg,
    );
  }

  Stream<List<DamagedInventoryModel>> getAll() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(DamagedInventoryModel.fromFirestore).toList());
  }

  Future<List<DamagedInventoryModel>> getBetween(
      DateTime start, DateTime end) async {
    final s = await _col
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();
    return s.docs.map(DamagedInventoryModel.fromFirestore).toList();
  }

  Future<void> add(DamagedInventoryModel entry) async {
    final data = entry.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(entry.id).set(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}

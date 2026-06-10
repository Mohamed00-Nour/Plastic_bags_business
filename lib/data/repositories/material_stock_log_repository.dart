import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/material_stock_log_model.dart';

class MaterialStockLogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col =>
      _firestore.collection('material_stock_logs');

  Stream<List<MaterialStockLogModel>> getAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(MaterialStockLogModel.fromFirestore).toList());
  }

  Stream<List<MaterialStockLogModel>> getForMaterial(String materialId) {
    return _col
        .where('materialId', isEqualTo: materialId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(MaterialStockLogModel.fromFirestore).toList());
  }

  Future<void> add(MaterialStockLogModel log) async {
    final data = log.toFirestore();
    data['createdBy'] = CurrentUserService.instance.userName;
    await _col.doc(log.id).set(data);
  }
}

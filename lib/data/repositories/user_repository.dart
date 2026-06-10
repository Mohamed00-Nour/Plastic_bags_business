import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('users');

  Stream<List<UserModel>> getUsers() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  Future<List<UserModel>> getUsersOnce() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  Future<UserModel> getUser(String id) async {
    final doc = await _collection.doc(id).get();
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUser(UserModel user) async {
    await _collection.doc(user.id).update(user.toFirestore());
  }

  Future<void> updateRole(String userId, UserRole role) async {
    await _collection.doc(userId).update({
      'role': role.name,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleActive(String userId, bool isActive) async {
    await _collection.doc(userId).update({
      'isActive': isActive,
      'modifiedBy': CurrentUserService.instance.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

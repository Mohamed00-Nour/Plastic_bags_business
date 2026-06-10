import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/current_user_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // First try users collection
    final userDoc =
        await _firestore.collection('users').doc(credential.user!.uid).get();

    if (userDoc.exists) {
      final user = UserModel.fromFirestore(userDoc);
      if (!user.isActive) {
        await _auth.signOut();
        throw Exception('Account is deactivated. Contact admin.');
      }
      return user;
    }

    // If not found in 'users', check 'shops'
    final shopQuery =
        await _firestore
            .collection('shops')
            .where('loginEmail', isEqualTo: email.trim())
            .limit(1)
            .get();

    if (shopQuery.docs.isNotEmpty) {
      final shopData = shopQuery.docs.first.data();
      if (shopData['isActive'] == false) {
        await _auth.signOut();
        throw Exception('Shop is deactivated. Contact admin.');
      }
      return UserModel(
        id: credential.user!.uid,
        email: email.trim(),
        name: shopData['name'] ?? 'Shop',
        role: UserRole.employee, // Shop acts as an employee
        shopId: shopQuery.docs.first.id,
        shopName: shopData['name'],
        createdAt:
            (shopData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt:
            (shopData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }

    await _auth.signOut();
    throw Exception('User profile not found. Contact admin.');
  }

  Future<void> createShopAuthAccount({
    required String email,
    required String password,
  }) async {
    try {
      await Firebase.app('tempUserCreation').delete();
    } catch (_) {}

    final tempApp = await Firebase.initializeApp(
      name: 'tempUserCreation',
      options: Firebase.app().options,
    );
    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }
  }

  Future<UserModel> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? shopId,
    String? shopName,
  }) async {
    // Use a secondary Firebase App to create the user without
    // signing out the currently logged-in admin.
    // Delete any leftover temp app from a previous failed attempt.
    try {
      await Firebase.app('tempUserCreation').delete();
    } catch (_) {
      // App doesn't exist yet – that's fine.
    }

    final tempApp = await Firebase.initializeApp(
      name: 'tempUserCreation',
      options: Firebase.app().options,
    );
    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final now = DateTime.now();
      final user = UserModel(
        id: credential.user!.uid,
        email: email,
        name: name,
        role: role,
        shopId: shopId,
        shopName: shopName,
        createdAt: now,
        updatedAt: now,
      );
      
      try {
        final data = user.toFirestore();
        data['createdBy'] = CurrentUserService.instance.userName;
        await _firestore.collection('users').doc(user.id).set(data);
      } catch (e) {
        await credential.user?.delete();
        throw Exception('Failed to add user to Firestore: $e');
      }
      
      await tempAuth.signOut();
      return user;
    } finally {
      await tempApp.delete();
    }
  }

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // First try users collection
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) return UserModel.fromFirestore(doc);

    // If not in users, check shops collection
    final shopQuery =
        await _firestore
            .collection('shops')
            .where('loginEmail', isEqualTo: user.email)
            .limit(1)
            .get();

    if (shopQuery.docs.isNotEmpty) {
      final shopData = shopQuery.docs.first.data();
      return UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: shopData['name'] ?? 'Shop',
        role: UserRole.employee, // Shop acts as an employee
        shopId: shopQuery.docs.first.id,
        shopName: shopData['name'],
        createdAt:
            (shopData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt:
            (shopData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }

    return null;
  }

  /// Creates the first admin account (no one is logged in yet).
  /// Uses the primary auth instance since this IS the initial sign-in.
  Future<UserModel> createInitialAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Now that the user is authenticated, we can securely check if any users exist
    final usersExist = await hasAnyUsers();
    if (usersExist) {
      // Abort! Users already exist. Rollback.
      await credential.user?.delete();
      throw Exception(
        'System is already setup. Initial admin cannot be created.',
      );
    }

    final now = DateTime.now();
    final user = UserModel(
      id: credential.user!.uid,
      email: email,
      name: name,
      role: UserRole.admin,
      createdAt: now,
      updatedAt: now,
    );
    
    try {
      final data = user.toFirestore();
      data['createdBy'] = name;
      await _firestore.collection('users').doc(user.id).set(data);
    } catch (e) {
      await credential.user?.delete();
      throw Exception('Failed to save admin to Firestore: $e');
    }
    
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> hasAnyUsers() async {
    final snapshot = await _firestore.collection('users').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }
}

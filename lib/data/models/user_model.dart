import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole { admin, employee, viewer }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  bool get canManageUsers => this == UserRole.admin;
  bool get canApproveOrders =>
      this == UserRole.admin || this == UserRole.employee;
  bool get canEditInventory =>
      this == UserRole.admin || this == UserRole.employee;
  bool get canViewReports => true;
  bool get canCreateOrders =>
      this == UserRole.admin || this == UserRole.employee;
  bool get canManageShops =>
      this == UserRole.admin || this == UserRole.employee;
  bool get canManageSuppliers =>
      this == UserRole.admin || this == UserRole.employee;
}

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? shopId;
  final String? shopName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.shopId,
    this.shopName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.viewer,
      ),
      shopId: data['shopId'],
      shopName: data['shopName'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'name': name,
        'role': role.name,
        'shopId': shopId,
        'shopName': shopName,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? shopId,
    String? shopName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, email, name, role, shopId, shopName, isActive];
}

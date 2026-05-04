import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';

abstract class UserManagementEvent extends Equatable {
  const UserManagementEvent();
  @override
  List<Object?> get props => [];
}

class UserManagementLoadRequested extends UserManagementEvent {}

class UserManagementCreateRequested extends UserManagementEvent {
  final String email;
  final String password;
  final String name;
  final UserRole role;
  final String? shopId;
  final String? shopName;
  const UserManagementCreateRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.shopId,
    this.shopName,
  });
  @override
  List<Object?> get props => [email, name, role, shopId, shopName];
}

class UserManagementUpdateRoleRequested extends UserManagementEvent {
  final String userId;
  final UserRole role;
  const UserManagementUpdateRoleRequested({
    required this.userId,
    required this.role,
  });
  @override
  List<Object?> get props => [userId, role];
}

class UserManagementToggleActiveRequested extends UserManagementEvent {
  final String userId;
  final bool isActive;
  const UserManagementToggleActiveRequested({
    required this.userId,
    required this.isActive,
  });
  @override
  List<Object?> get props => [userId, isActive];
}

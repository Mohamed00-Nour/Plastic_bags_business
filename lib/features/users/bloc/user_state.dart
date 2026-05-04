import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';

abstract class UserManagementState extends Equatable {
  const UserManagementState();
  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {}

class UserManagementLoading extends UserManagementState {}

class UserManagementLoaded extends UserManagementState {
  final List<UserModel> users;
  const UserManagementLoaded({required this.users});
  @override
  List<Object?> get props => [users];
}

class UserManagementOperationSuccess extends UserManagementState {
  final String message;
  const UserManagementOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class UserManagementError extends UserManagementState {
  final String message;
  const UserManagementError({required this.message});
  @override
  List<Object?> get props => [message];
}

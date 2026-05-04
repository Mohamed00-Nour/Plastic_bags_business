import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserManagementBloc
    extends Bloc<UserManagementEvent, UserManagementState> {
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  UserManagementBloc({
    required UserRepository userRepository,
    required AuthRepository authRepository,
  })  : _userRepository = userRepository,
        _authRepository = authRepository,
        super(UserManagementInitial()) {
    on<UserManagementLoadRequested>(_onLoad);
    on<UserManagementCreateRequested>(_onCreate);
    on<UserManagementUpdateRoleRequested>(_onUpdateRole);
    on<UserManagementToggleActiveRequested>(_onToggleActive);
  }

  Future<void> _onLoad(
    UserManagementLoadRequested event,
    Emitter<UserManagementState> emit,
  ) async {
    emit(UserManagementLoading());
    try {
      // On desktop (Windows/macOS/Linux) the Firestore stream fires callbacks
      // from a background thread which causes a Flutter platform-thread warning.
      // Use a one-time fetch on desktop; use real-time stream on mobile/web.
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await emit.forEach<List<dynamic>>(
          _userRepository.getUsers(),
          onData: (users) => UserManagementLoaded(users: users.cast()),
          onError: (_, __) =>
              const UserManagementError(message: 'Failed to load users'),
        );
      } else {
        final users = await _userRepository.getUsersOnce();
        emit(UserManagementLoaded(users: users));
      }
    } catch (e) {
      emit(UserManagementError(message: e.toString()));
    }
  }

  Future<void> _onCreate(
    UserManagementCreateRequested event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      await _authRepository.createUser(
        email: event.email,
        password: event.password,
        name: event.name,
        role: event.role,
        shopId: event.shopId,
        shopName: event.shopName,
      );
      emit(const UserManagementOperationSuccess(
          message: 'User created successfully'));
      add(UserManagementLoadRequested());
    } catch (e) {
      emit(UserManagementError(message: e.toString()));
    }
  }

  Future<void> _onUpdateRole(
    UserManagementUpdateRoleRequested event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      await _userRepository.updateRole(event.userId, event.role);
      emit(const UserManagementOperationSuccess(
          message: 'Role updated successfully'));
    } catch (e) {
      emit(UserManagementError(message: e.toString()));
    }
  }

  Future<void> _onToggleActive(
    UserManagementToggleActiveRequested event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      await _userRepository.toggleActive(event.userId, event.isActive);
      emit(UserManagementOperationSuccess(
          message: event.isActive ? 'User activated' : 'User deactivated'));
    } catch (e) {
      emit(UserManagementError(message: e.toString()));
    }
  }
}

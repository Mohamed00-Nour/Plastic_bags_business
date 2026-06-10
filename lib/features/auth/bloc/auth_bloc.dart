import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/current_user_service.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

// Private event — fired whenever Firebase auth state changes on disk/token
class _AuthUserChanged extends AuthEvent {
  final User? user;
  const _AuthUserChanged(this.user);
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _authSubscription;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<_AuthUserChanged>(_onAuthUserChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthResetPasswordRequested>(_onResetPassword);
    on<AuthAdminSetupRequested>((event, emit) => emit(AdminSetupRequired()));
    on<AdminSetupSubmitted>(_onAdminSetup);

    // Subscribe once; every auth-state change (including session restoration
    // from disk on Windows) will dispatch _AuthUserChanged into the bloc.
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) => add(_AuthUserChanged(user)),
    );
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }

  // Just show loading — the stream subscription above handles the actual check.
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
  }

  Future<void> _onAuthUserChanged(
    _AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user == null) {
      CurrentUserService.instance.clear();
      emit(AuthUnauthenticated());
      return;
    }
    try {
      final userModel = await _authRepository.getCurrentUserProfile();
      if (userModel != null && userModel.isActive) {
        CurrentUserService.instance.set(userModel.id, userModel.name);
        emit(AuthAuthenticated(user: userModel));
      } else {
        CurrentUserService.instance.clear();
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      CurrentUserService.instance.clear();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signIn(
        event.email.trim(),
        event.password,
      );
      CurrentUserService.instance.set(user.id, user.name);
      emit(AuthAuthenticated(user: user));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    CurrentUserService.instance.clear();
    emit(AuthUnauthenticated());
  }

  Future<void> _onResetPassword(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(event.email.trim());
      emit(AuthPasswordResetSent());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onAdminSetup(
    AdminSetupSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.createInitialAdmin(
        email: event.email.trim(),
        password: event.password,
        name: event.name.trim(),
      );
      CurrentUserService.instance.set(user.id, user.name);
      emit(AuthAuthenticated(user: user));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: _mapFirebaseError(e.code)));
      emit(AdminSetupRequired());
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(AdminSetupRequired());
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

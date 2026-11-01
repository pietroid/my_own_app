import 'package:auth/src/data/auth_repository.dart';
import 'package:auth/src/models/app_user.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// {@template auth_bloc}
/// Manages authentication state and sign-in flows.
/// {@endtemplate}
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// {@macro auth_bloc}
  AuthBloc({required this._authRepository}) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthFailureOccurred>(_onFailureOccurred);

    add(const AuthStarted());
  }

  final AuthRepository _authRepository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await emit.forEach(
      _authRepository.user,
      onData: (user) => user != null
          ? state.copyWith(status: AuthStatus.authenticated, user: user)
          : state.status == AuthStatus.loading
          ? state
          : const AuthState(status: AuthStatus.unauthenticated),
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      await _authRepository.signInWithGoogle();

      // On the web the page is on its way to Google, and stays loading
      // until it is gone. On a phone, no user means the picker was closed.
      if (kIsWeb) return;

      final user = _authRepository.currentUser;
      emit(
        user == null
            ? const AuthState(status: AuthStatus.unauthenticated)
            : state.copyWith(status: AuthStatus.authenticated, user: user),
      );
    } on AuthFailure catch (failure) {
      emit(
        AuthState(
          status: AuthStatus.failure,
          errorMessage: failure.message,
        ),
      );
    } on Object {
      emit(const AuthState(status: AuthStatus.failure));
    }
  }

  void _onFailureOccurred(
    AuthFailureOccurred event,
    Emitter<AuthState> emit,
  ) {
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        errorMessage: event.message,
      ),
    );
  }
}

part of 'auth_bloc.dart';

/// {@template auth_status}
/// Possible authentication statuses.
/// {@endtemplate}
enum AuthStatus {
  /// Initial state before any status is known.
  initial,

  /// A sign-in flow is in progress.
  loading,

  /// A user is signed in.
  authenticated,

  /// No user is signed in.
  unauthenticated,

  /// An error occurred during authentication.
  failure,
}

/// {@template auth_state}
/// State of the authentication flow.
/// {@endtemplate}
class AuthState extends Equatable {
  /// {@macro auth_state}
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// Current authentication status.
  final AuthStatus status;

  /// Currently signed-in user, when available.
  final AppUser? user;

  /// Error message when [status] is [AuthStatus.failure].
  final String? errorMessage;

  /// Creates a copy of this state with the given fields replaced.
  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}

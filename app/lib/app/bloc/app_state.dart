part of 'app_bloc.dart';

/// {@template app_status}
/// Possible application-wide authentication statuses.
/// {@endtemplate}
enum AppStatus {
  /// A user is signed in.
  authenticated,

  /// No user is signed in.
  unauthenticated,
}

/// {@template app_state}
/// Application-wide state.
/// {@endtemplate}
class AppState extends Equatable {
  /// {@macro app_state}
  const AppState({
    this.status = AppStatus.unauthenticated,
    this.user,
  });

  /// Current application status.
  final AppStatus status;

  /// Currently signed-in user, when available.
  final AppUser? user;

  /// The first name of the authenticated user.
  String? get firstName {
    final name = user?.name;
    if (name == null || name.isEmpty) return null;

    return name.trim().split(' ').first;
  }

  /// Creates a copy of this state with the given fields replaced.
  AppState copyWith({
    AppStatus? status,
    AppUser? user,
  }) {
    return AppState(
      status: status ?? this.status,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props => [status, user];
}

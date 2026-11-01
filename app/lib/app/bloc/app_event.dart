part of 'app_bloc.dart';

/// {@template app_event}
/// Base class for all application events.
/// {@endtemplate}
abstract class AppEvent extends Equatable {
  /// {@macro app_event}
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// {@template app_user_changed}
/// Emitted when the authenticated user changes.
/// {@endtemplate}
class AppUserChanged extends AppEvent {
  /// {@macro app_user_changed}
  const AppUserChanged(this.user);

  /// The currently signed-in user, or `null` when no user is signed in.
  final AppUser? user;

  @override
  List<Object?> get props => [user];
}

/// {@template app_logout_requested}
/// Requested when the user wants to sign out.
/// {@endtemplate}
class AppLogoutRequested extends AppEvent {
  /// {@macro app_logout_requested}
  const AppLogoutRequested();
}

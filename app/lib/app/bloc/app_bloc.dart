import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:auth/auth.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'app_event.dart';
part 'app_state.dart';

/// {@template app_bloc}
/// Manages application-wide state derived from the authenticated user.
///
/// It also tells [Analytics] who is behind the session: the account's id,
/// never a name or an email, and forgets it on sign-out.
/// {@endtemplate}
class AppBloc extends Bloc<AppEvent, AppState> {
  /// {@macro app_bloc}
  AppBloc({
    required this._authRepository,
    AppUser? initialUser,
    this._analytics = const NoAnalytics(),
  }) : super(
         AppState(
           status: initialUser != null
               ? AppStatus.authenticated
               : AppStatus.unauthenticated,
           user: initialUser,
         ),
       ) {
    on<AppUserChanged>(_onUserChanged);
    on<AppLogoutRequested>(_onLogoutRequested);

    if (initialUser != null) unawaited(_identify(initialUser));

    _userSubscription = _authRepository.user.listen(
      (user) => add(AppUserChanged(user)),
    );
  }

  final AuthRepository _authRepository;
  final Analytics _analytics;
  StreamSubscription<AppUser?>? _userSubscription;

  Future<void> _identify(AppUser user) =>
      _analytics.identify(user.id);

  void _onUserChanged(AppUserChanged event, Emitter<AppState> emit) {
    final user = event.user;
    if (user != null && user.id != state.user?.id) {
      unawaited(_identify(user));
    } else if (user == null && state.user != null) {
      unawaited(_analytics.reset());
    }
    emit(
      state.copyWith(
        user: event.user,
        status: event.user != null
            ? AppStatus.authenticated
            : AppStatus.unauthenticated,
      ),
    );
  }

  Future<void> _onLogoutRequested(
    AppLogoutRequested event,
    Emitter<AppState> emit,
  ) async {
    await _authRepository.signOut();
  }

  @override
  Future<void> close() async {
    await _userSubscription?.cancel();
    return super.close();
  }
}

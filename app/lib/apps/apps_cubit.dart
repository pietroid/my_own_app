import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/client_runner.dart';
import 'package:my_own_app/apps/json_patch.dart';

/// {@template apps_state}
/// The person's apps, and whether one is being built.
/// {@endtemplate}
class AppsState extends Equatable {
  /// {@macro apps_state}
  const AppsState({
    this.apps = const [],
    this.creating = false,
    this.failed = false,
    this.error,
  });

  /// Newest first.
  final List<AppSummary> apps;

  /// Whether the assistant is building one.
  final bool creating;

  /// Whether the last build failed.
  final bool failed;

  /// The server's own words for it, when it gave any.
  final String? error;

  @override
  List<Object?> get props => [apps, creating, failed, error];
}

/// {@template apps_cubit}
/// The home's list of apps, and building a new one.
/// {@endtemplate}
class AppsCubit extends Cubit<AppsState> {
  /// {@macro apps_cubit}
  AppsCubit({required this._repository}) : super(const AppsState());

  final AppsRepository _repository;

  /// Loads the list. A failure leaves it as it was.
  Future<void> load() async {
    try {
      emit(AppsState(apps: await _repository.list()));
    } on DioException {
      // The list stays as it was; the next visit tries again.
    }
  }

  /// Builds an app from [prompt]; answers with it, or null when it failed.
  Future<AppSummary?> create(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || state.creating) return null;

    emit(AppsState(apps: state.apps, creating: true));
    try {
      final app = await _repository.create(text);
      final summary = AppSummary(id: app.id, name: app.name);
      emit(AppsState(apps: [summary, ...state.apps]));
      return summary;
    } on DioException catch (error) {
      emit(
        AppsState(
          apps: state.apps,
          failed: true,
          error: serverMessage(error),
        ),
      );
      return null;
    } on Object {
      // An answer this app cannot read (or any other failure) ends the
      // build like a refusal does: never a spinner that stays.
      emit(AppsState(apps: state.apps, failed: true));
      return null;
    }
  }
}

/// {@template app_run_state}
/// One app on screen: its screen, its data, and how the last tap went.
/// {@endtemplate}
class AppRunState extends Equatable {
  /// {@macro app_run_state}
  const AppRunState({this.app, this.loadFailed = false, this.error});

  /// The app, once loaded.
  final AppSnapshot? app;

  /// Whether it could not be opened.
  final bool loadFailed;

  /// The last tap's failure, in the person's words.
  final String? error;

  @override
  List<Object?> get props => [app, loadFailed, error];
}

/// {@template app_run_cubit}
/// Runs one app, every tap on the device first ([ClientRunner]), so the
/// screen changes at once.
///
/// A saved action (`on: "server"`) is then sent to the server, one at a
/// time and in order, which runs the same action on its own copy and keeps
/// the patch. When the server's patch is the one shown, nothing more
/// happens; when it differs, or the server refuses, the server's copy is
/// loaded again (and the refusal shown). A client action's patch only
/// changes the screen; the saved actions it `call`s work as above.
/// {@endtemplate}
class AppRunCubit extends Cubit<AppRunState> {
  /// {@macro app_run_cubit}
  AppRunCubit({
    required this._repository,
    required this._id,
    ClientRunner? runner,
  }) : _runner = runner ?? ClientRunner(),
       super(const AppRunState());

  final AppsRepository _repository;
  final String _id;
  final ClientRunner _runner;

  /// The saved actions on their way to the server, one after another.
  Future<void> _sending = Future.value();

  /// Loads the app as it is on the server.
  Future<void> load() async {
    try {
      final app = await _repository.get(_id);
      if (!isClosed) emit(AppRunState(app: app));
    } on DioException {
      if (!isClosed) emit(const AppRunState(loadFailed: true));
    }
  }

  /// What the person typed into a field: kept on the device until a button
  /// sends it.
  void edit(String path, String value) {
    final app = state.app;
    if (app == null) return;
    _emitData(
      applyPatch(app.data, [
        {'op': 'replace', 'path': path, 'value': value},
      ]),
    );
  }

  /// Runs [action] with [event] and applies what it changed.
  ///
  /// The returned future ends when the screen has changed, not when the
  /// server has kept it.
  Future<void> act(String action, Map<String, Object?> event) async {
    final def = state.app?.actions[action];
    if (def == null) return;
    try {
      if (def.saved) {
        await _saved(action, event);
        return;
      }
      final patch = await _run(def, event, call: _saved);
      _apply(patch);
    } on DioException catch (error) {
      _emitError(serverMessage(error) ?? '');
    } on ClientActionFailed {
      _emitError('');
    }
  }

  /// A saved action: shown at once, then sent to the server in order.
  /// Answers with the patch shown.
  ///
  /// When it cannot run here (an app older than the server's bytecode), it
  /// waits for the server and shows the server's patch instead.
  Future<List<dynamic>> _saved(
    String action,
    Map<String, Object?> event,
  ) async {
    final def = state.app?.actions[action];
    if (def == null || !def.saved) {
      throw const ClientActionFailed('called an action that is not saved');
    }
    List<dynamic>? shown;
    try {
      shown = await _run(def, event, call: _noCall);
      _apply(shown);
    } on ClientActionFailed {
      shown = null;
    }
    final sent = _sending.then((_) => _repository.act(_id, action, event));
    _sending = sent.then<void>((_) {}, onError: (_) {});

    if (shown == null) {
      final delta = await sent;
      _apply(delta);
      return delta;
    }
    final mine = shown;
    unawaited(
      sent.then(
        (delta) async {
          // The server read its own copy; if it got another answer, its
          // copy is the truth.
          if (jsonEncode(delta) != jsonEncode(mine)) await load();
        },
        onError: (Object error) async {
          await load();
          _emitError(error is DioException ? serverMessage(error) ?? '' : '');
        },
      ),
    );
    return mine;
  }

  Future<List<dynamic>> _run(
    AppAction def,
    Map<String, Object?> event, {
    required ServerCall call,
  }) {
    final data = state.app?.data ?? const {};
    return _runner.run(
      evc: def.evc,
      input: {for (final path in def.input) path: valueAt(data, path)},
      event: event,
      call: call,
    );
  }

  /// What a saved action gets as `call`: it is the one being called.
  static Future<List<dynamic>> _noCall(String _, Map<String, Object?> _) =>
      Future.error(const ClientActionFailed('a saved action calls none'));

  /// Shows [patch]; one this side cannot apply fails the action.
  void _apply(List<dynamic> patch) {
    final app = state.app;
    if (app == null) return;
    final Map<String, dynamic> next;
    try {
      next = applyPatch(app.data, patch);
    } on Object {
      throw const ClientActionFailed('bad patch');
    }
    _emitData(next);
  }

  void _emitError(String error) {
    if (!isClosed) emit(AppRunState(app: state.app, error: error));
  }

  void _emitData(Map<String, dynamic> data) {
    if (!isClosed) emit(AppRunState(app: state.app!.withData(data)));
  }
}

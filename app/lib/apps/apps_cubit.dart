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
/// Runs one app. A server action goes to the server, which runs it and
/// answers with a JSON Patch, applied here to the same data. A client action
/// runs on the device ([ClientRunner]); the server actions it calls are
/// applied as they answer, then its own patch, which is not kept.
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

  /// Loads the app as it is on the server.
  Future<void> load() async {
    try {
      final app = await _repository.get(_id);
      if (app.clientActions.isNotEmpty) _runner.warm();
      emit(AppRunState(app: app));
    } on DioException {
      emit(const AppRunState(loadFailed: true));
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
  Future<void> act(String action, Map<String, Object?> event) async {
    final app = state.app;
    if (app == null) return;
    final client = app.clientActions[action];
    try {
      if (client == null) {
        await _server(action, event);
        return;
      }
      final patch = await _runner.run(
        code: client.code,
        input: {
          for (final path in client.input) path: valueAt(app.data, path),
        },
        event: event,
        call: _server,
      );
      final now = state.app;
      if (now == null) return;
      try {
        _emitData(applyPatch(now.data, patch));
      } on Object {
        throw const ClientActionFailed('bad patch');
      }
    } on DioException catch (error) {
      _emitError(serverMessage(error) ?? '');
    } on ClientActionFailed {
      _emitError('');
    }
  }

  /// One server action: the server keeps its patch, and so does this side.
  Future<List<dynamic>> _server(
    String action,
    Map<String, Object?> event,
  ) async {
    // A client action calls only server ones.
    if (state.app?.clientActions.containsKey(action) ?? false) {
      throw const ClientActionFailed('a client action called a client one');
    }
    final delta = await _repository.act(_id, action, event);
    final app = state.app;
    if (app == null) return delta;
    try {
      _emitData(applyPatch(app.data, delta));
    } on Object {
      // A patch this side cannot apply: the server's copy is the truth.
      await load();
    }
    return delta;
  }

  void _emitError(String error) {
    emit(AppRunState(app: state.app, error: error));
  }

  void _emitData(Map<String, dynamic> data) {
    emit(AppRunState(app: state.app!.withData(data)));
  }

  @override
  Future<void> close() {
    _runner.close();
    return super.close();
  }
}

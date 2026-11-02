import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// {@template app_summary}
/// One app in the person's list.
/// {@endtemplate}
class AppSummary extends Equatable {
  /// {@macro app_summary}
  const AppSummary({required this.id, required this.name});

  /// The app's id.
  final String id;

  /// What it is called.
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// {@template app_action}
/// One of an app's actions, as the device runs it: whether it is saved,
/// what it reads, and its bytecode.
/// {@endtemplate}
class AppAction extends Equatable {
  /// {@macro app_action}
  const AppAction({required this.input, required this.evc, this.saved = true});

  /// From one entry of `actions` in `GET /apps/:id`.
  factory AppAction.fromJson(Map<String, dynamic> json) => AppAction(
    saved: json['on'] != 'client',
    input: [for (final path in json['input'] as List<dynamic>) '$path'],
    evc: json['evc'] as String,
  );

  /// Whether the server keeps what it changes (`on: "server"`); a client
  /// action only changes the screen.
  final bool saved;

  /// The JSON Pointers it reads.
  final List<String> input;

  /// Its Dart, `Future<List> run(Map input, Map event, Function call)`,
  /// compiled by the server into dart_eval bytecode, base64.
  final String evc;

  @override
  List<Object?> get props => [saved, input, evc];
}

/// {@template app_snapshot}
/// A built app as the server sends it: its screen, its data, and every
/// action, which the device runs itself.
/// {@endtemplate}
class AppSnapshot extends Equatable {
  /// {@macro app_snapshot}
  const AppSnapshot({
    required this.id,
    required this.name,
    required this.ui,
    required this.data,
    this.actions = const {},
    this.version = 1,
  });

  /// From `GET /apps/:id`.
  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
    id: json['id'] as String,
    name: json['name'] as String,
    ui: [
      for (final component in json['ui'] as List<dynamic>)
        component as Map<String, dynamic>,
    ],
    data: json['data'] as Map<String, dynamic>,
    actions: {
      for (final MapEntry(:key, :value)
          in (json['actions'] as Map<String, dynamic>? ?? const {}).entries)
        key: AppAction.fromJson(value as Map<String, dynamic>),
    },
    version: json['version'] as int? ?? 1,
  );

  /// The app's id.
  final String id;

  /// What it is called.
  final String name;

  /// The screen: A2UI components, the one with id `root` first to draw.
  final List<Map<String, dynamic>> ui;

  /// The app's whole state.
  final Map<String, dynamic> data;

  /// Its actions, by name.
  final Map<String, AppAction> actions;

  /// The version of the app this is (see [AppVersion]).
  final int version;

  /// This app with other [data].
  AppSnapshot withData(Map<String, dynamic> data) => AppSnapshot(
    id: id,
    name: name,
    ui: ui,
    data: data,
    actions: actions,
    version: version,
  );

  @override
  List<Object?> get props => [id, name, ui, data, actions, version];
}

/// {@template app_changes}
/// What one version changed against the one before it.
/// {@endtemplate}
class AppChanges extends Equatable {
  /// {@macro app_changes}
  const AppChanges({
    this.components = const [],
    this.removed = const [],
    this.actions = const [],
    this.removedActions = const [],
    this.renamed = false,
    this.restoredFrom,
  });

  /// From `changes` in a version.
  factory AppChanges.fromJson(Map<String, dynamic> json) {
    List<String> names(String key) => [
      for (final name in json[key] as List<dynamic>? ?? const []) '$name',
    ];
    return AppChanges(
      components: names('components'),
      removed: names('removed'),
      actions: names('actions'),
      removedActions: names('removedActions'),
      renamed: json['name'] == true,
      restoredFrom: json['restoredFrom'] as int?,
    );
  }

  /// Components added or changed, by id.
  final List<String> components;

  /// Components removed, by id.
  final List<String> removed;

  /// Actions added or changed, by name.
  final List<String> actions;

  /// Actions removed, by name.
  final List<String> removedActions;

  /// Whether the app's name changed.
  final bool renamed;

  /// When the version brought an earlier one back: that one's number.
  final int? restoredFrom;

  /// How many components it touched.
  int get componentCount => components.length + removed.length;

  /// How many actions it touched.
  int get actionCount => actions.length + removedActions.length;

  /// Whether it changed the app at all.
  bool get any => componentCount + actionCount > 0 || renamed;

  @override
  List<Object?> get props => [
    components,
    removed,
    actions,
    removedActions,
    renamed,
    restoredFrom,
  ];
}

/// {@template app_version}
/// One point of an app's history: what the person asked, what the model
/// answered, and what changed. The conversation about an app is its
/// versions, in order.
/// {@endtemplate}
class AppVersion extends Equatable {
  /// {@macro app_version}
  const AppVersion({
    required this.n,
    required this.prompt,
    required this.reply,
    this.changes = const AppChanges(),
  });

  /// From one entry of `GET /apps/:id/versions`.
  factory AppVersion.fromJson(Map<String, dynamic> json) => AppVersion(
    n: json['n'] as int,
    prompt: json['prompt'] as String? ?? '',
    reply: json['reply'] as String? ?? '',
    changes: AppChanges.fromJson(
      json['changes'] as Map<String, dynamic>? ?? const {},
    ),
  );

  /// Its number, from 1.
  final int n;

  /// What the person asked; empty when it brought an earlier version back.
  final String prompt;

  /// What the model answered; empty for the first build.
  final String reply;

  /// What it changed.
  final AppChanges changes;

  @override
  List<Object?> get props => [n, prompt, reply, changes];
}

/// {@template app_history}
/// An app's versions, oldest first, and the one it is at.
/// {@endtemplate}
class AppHistory extends Equatable {
  /// {@macro app_history}
  const AppHistory({required this.current, required this.versions});

  /// The version the app is at.
  final int current;

  /// Every version, oldest first.
  final List<AppVersion> versions;

  @override
  List<Object?> get props => [current, versions];
}

/// {@template app_edit}
/// What a change answers: the new version, and the app at it.
/// {@endtemplate}
class AppEdit extends Equatable {
  /// {@macro app_edit}
  const AppEdit({required this.version, required this.app});

  /// From `POST /apps/:id/messages` or `…/restore`.
  factory AppEdit.fromJson(Map<String, dynamic> json) => AppEdit(
    version: AppVersion.fromJson(json['version'] as Map<String, dynamic>),
    app: AppSnapshot.fromJson(json['app'] as Map<String, dynamic>),
  );

  /// The new point of history.
  final AppVersion version;

  /// The app at it.
  final AppSnapshot app;

  @override
  List<Object?> get props => [version, app];
}

/// {@template apps_repository}
/// Talks to the server's apps (`/api/apps`): the list, building one from a
/// description, and running a tap.
/// {@endtemplate}
class AppsRepository {
  /// {@macro apps_repository}
  const AppsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// The person's apps, newest first.
  Future<List<AppSummary>> list() async {
    final response = await _api.get<List<dynamic>>('/apps');
    return [
      for (final item in response.data ?? const <dynamic>[])
        AppSummary(
          id: (item as Map<String, dynamic>)['id'] as String,
          name: item['name'] as String,
        ),
    ];
  }

  /// The app [id], as it is now.
  Future<AppSnapshot> get(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/apps/$id');
    return AppSnapshot.fromJson(response.data!);
  }

  /// Has the assistant build an app from [prompt].
  Future<AppSnapshot> create(String prompt) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/apps',
      data: {'prompt': prompt},
    );
    return AppSnapshot.fromJson(response.data!);
  }

  /// The app's conversation: its versions.
  Future<AppHistory> history(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/apps/$id/versions');
    final json = response.data!;
    return AppHistory(
      current: json['current'] as int,
      versions: [
        for (final item in json['versions'] as List<dynamic>)
          AppVersion.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  /// The app [id] as it was at version [n].
  Future<AppSnapshot> version(String id, int n) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/apps/$id/versions/$n',
    );
    return AppSnapshot.fromJson(response.data!);
  }

  /// Asks the assistant to change the app; [focus] is the id of the
  /// component the person selected.
  Future<AppEdit> send(String id, String prompt, {String? focus}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/apps/$id/messages',
      data: {'prompt': prompt, 'focus': ?focus},
    );
    return AppEdit.fromJson(response.data!);
  }

  /// Brings version [n] back, as a new version.
  Future<AppEdit> restore(String id, int n) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/apps/$id/versions/$n/restore',
    );
    return AppEdit.fromJson(response.data!);
  }

  /// Runs [action] with [event]; answers with the JSON Patch it made (the
  /// `delta` of an AG-UI STATE_DELTA).
  Future<List<dynamic>> act(
    String id,
    String action,
    Map<String, Object?> event,
  ) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/apps/$id/actions/$action',
      data: {'event': event},
    );
    return response.data?['delta'] as List<dynamic>? ?? const [];
  }
}

/// The server's own words for a refusal, when it gave any.
String? serverMessage(DioException error) {
  final data = error.response?.data;
  final message = data is Map<String, dynamic> ? data['message'] : null;
  return message is String ? message : null;
}

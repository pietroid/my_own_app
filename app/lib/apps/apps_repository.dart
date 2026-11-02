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

  /// This app with other [data].
  AppSnapshot withData(Map<String, dynamic> data) => AppSnapshot(
    id: id,
    name: name,
    ui: ui,
    data: data,
    actions: actions,
  );

  @override
  List<Object?> get props => [id, name, ui, data, actions];
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

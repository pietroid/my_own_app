import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_own_app/apps/apps_repository.dart';

/// {@template studio_state}
/// Everything around a built app while it is being changed: its
/// conversation (one entry per version), the component picked on its
/// screen, and the earlier version being looked at, if any.
/// {@endtemplate}
class StudioState extends Equatable {
  /// {@macro studio_state}
  const StudioState({
    this.versions = const [],
    this.current = 0,
    this.historyFailed = false,
    this.pending,
    this.sendFailed = false,
    this.error,
    this.selecting = false,
    this.selectedId,
    this.focusId,
    this.viewing,
    this.viewed,
    this.viewFailed = false,
  });

  /// The conversation: every version, oldest first.
  final List<AppVersion> versions;

  /// The version the app is at.
  final int current;

  /// Whether the conversation could not be loaded.
  final bool historyFailed;

  /// What the person just asked, while the assistant works on it.
  final String? pending;

  /// Whether the last request failed.
  final bool sendFailed;

  /// The server's words for that failure, when it gave any.
  final String? error;

  /// Whether a tap on the screen picks a component instead of using it.
  final bool selecting;

  /// The component picked, by id.
  final String? selectedId;

  /// The component the next request is about, by id.
  final String? focusId;

  /// The earlier version on screen instead of the app as it is.
  final int? viewing;

  /// That version, once loaded.
  final AppSnapshot? viewed;

  /// Whether that version could not be loaded.
  final bool viewFailed;

  /// Whether a request is on its way.
  bool get sending => pending != null;

  StudioState _copy({
    List<AppVersion>? versions,
    int? current,
    bool? historyFailed,
    String? Function()? pending,
    bool? sendFailed,
    String? Function()? error,
    bool? selecting,
    String? Function()? selectedId,
    String? Function()? focusId,
    int? Function()? viewing,
    AppSnapshot? Function()? viewed,
    bool? viewFailed,
  }) => StudioState(
    versions: versions ?? this.versions,
    current: current ?? this.current,
    historyFailed: historyFailed ?? this.historyFailed,
    pending: pending != null ? pending() : this.pending,
    sendFailed: sendFailed ?? this.sendFailed,
    error: error != null ? error() : this.error,
    selecting: selecting ?? this.selecting,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    focusId: focusId != null ? focusId() : this.focusId,
    viewing: viewing != null ? viewing() : this.viewing,
    viewed: viewed != null ? viewed() : this.viewed,
    viewFailed: viewFailed ?? this.viewFailed,
  );

  @override
  List<Object?> get props => [
    versions,
    current,
    historyFailed,
    pending,
    sendFailed,
    error,
    selecting,
    selectedId,
    focusId,
    viewing,
    viewed,
    viewFailed,
  ];
}

/// {@template studio_cubit}
/// Changes a built app by talking about it: each request goes to the
/// assistant, which changes the app and answers; the change is a new
/// version, and the app on screen becomes it (`onApp`).
///
/// Any version can be looked at (read-only) and brought back, which is a
/// new version too. A component picked on the screen or in the tree can be
/// made the subject of the next request.
/// {@endtemplate}
class StudioCubit extends Cubit<StudioState> {
  /// {@macro studio_cubit}
  StudioCubit({
    required this._repository,
    required this._id,
    required this._onApp,
  }) : super(const StudioState());

  final AppsRepository _repository;
  final String _id;
  final void Function(AppSnapshot app) _onApp;

  /// Loads the conversation.
  Future<void> load() async {
    try {
      final history = await _repository.history(_id);
      if (isClosed) return;
      emit(
        state._copy(
          versions: history.versions,
          current: history.current,
          historyFailed: false,
        ),
      );
    } on DioException {
      if (!isClosed) emit(state._copy(historyFailed: true));
    }
  }

  /// Asks the assistant to change the app, about the focused component if
  /// there is one.
  Future<void> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || state.sending) return;
    emit(
      state._copy(
        pending: () => text,
        sendFailed: false,
        error: () => null,
      ),
    );
    try {
      final edit = await _repository.send(_id, text, focus: state.focusId);
      if (isClosed) return;
      _land(edit);
    } on DioException catch (error) {
      if (isClosed) return;
      emit(
        state._copy(
          pending: () => null,
          sendFailed: true,
          error: () => serverMessage(error),
        ),
      );
    }
  }

  /// Shows version [n] instead of the app as it is; the current one goes
  /// back to the app.
  Future<void> view(int n) async {
    if (n == state.current) return back();
    emit(
      state._copy(
        viewing: () => n,
        viewed: () => null,
        viewFailed: false,
        selectedId: () => null,
        focusId: () => null,
      ),
    );
    try {
      final app = await _repository.version(_id, n);
      if (isClosed || state.viewing != n) return;
      emit(state._copy(viewed: () => app));
    } on DioException {
      if (!isClosed && state.viewing == n) {
        emit(state._copy(viewFailed: true));
      }
    }
  }

  /// Back to the app as it is.
  void back() {
    emit(
      state._copy(
        viewing: () => null,
        viewed: () => null,
        viewFailed: false,
      ),
    );
  }

  /// Brings the version being looked at back, as a new version.
  Future<void> restore() async {
    final n = state.viewing;
    if (n == null || state.sending) return;
    emit(state._copy(pending: () => '', sendFailed: false, error: () => null));
    try {
      final edit = await _repository.restore(_id, n);
      if (isClosed) return;
      _land(edit);
    } on DioException catch (error) {
      if (isClosed) return;
      emit(
        state._copy(
          pending: () => null,
          sendFailed: true,
          error: () => serverMessage(error),
        ),
      );
    }
  }

  /// Turns picking components on or off.
  void toggleSelecting() {
    final on = !state.selecting;
    emit(
      state._copy(
        selecting: on,
        selectedId: on ? null : () => null,
      ),
    );
  }

  /// Picks the component [id], or none. Picking one (from the tree, say)
  /// turns picking on, so the screen shows it.
  void select(String? id) {
    emit(
      state._copy(selectedId: () => id, selecting: id != null ? true : null),
    );
  }

  /// Makes [id] the subject of the next request, or nothing.
  void focus(String? id) {
    emit(state._copy(focusId: () => id));
  }

  void _land(AppEdit edit) {
    _onApp(edit.app);
    final ids = {for (final c in edit.app.ui) c['id']};
    emit(
      state._copy(
        versions: [...state.versions, edit.version],
        current: edit.version.n,
        pending: () => null,
        viewing: () => null,
        viewed: () => null,
        viewFailed: false,
        // A component the change removed is no longer there to pick.
        selectedId: ids.contains(state.selectedId) ? null : () => null,
        focusId: () => null,
      ),
    );
  }
}

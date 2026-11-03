import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/apps/app_renderer.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';

/// {@template app_run_page}
/// One of the person's apps, open in their My Own App Editor.
///
/// The editor is itself an app (`server/src/apps/editor/editor.ts`), drawn
/// by [AppRenderer] and run by the same runner: its `start` action opens
/// the app [id] in it, and a Surface runs that app beside the conversation
/// that changes it. Opening the editor's own id edits the editor.
///
/// When the editor cannot open (the person broke theirs), the app runs on
/// its own, with a way to bring the editor back.
/// {@endtemplate}
class AppRunPage extends StatefulWidget {
  /// {@macro app_run_page}
  const AppRunPage({required this.id, super.key});

  /// The app to open.
  final String id;

  @override
  State<AppRunPage> createState() => _AppRunPageState();
}

class _AppRunPageState extends State<AppRunPage> {
  /// Bumped to open the editor again, after it was brought back.
  var _attempt = 0;

  AppRunCubit _editor(BuildContext context) {
    final repository = context.read<AppsRepository>();
    final cubit = AppRunCubit(
      repository: repository,
      id: '',
      source: repository.editor,
      start: {'id': widget.id},
    );
    unawaited(cubit.load());
    return cubit;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(_attempt),
      create: _editor,
      child: BlocBuilder<AppRunCubit, AppRunState>(
        buildWhen: (previous, current) =>
            previous.loadFailed != current.loadFailed,
        builder: (context, state) => state.loadFailed
            ? _Plain(
                id: widget.id,
                onEditorBack: () => setState(() => _attempt++),
              )
            : const _AppScreen(),
      ),
    );
  }
}

/// The app [id] on its own, while the editor does not open.
class _Plain extends StatelessWidget {
  const _Plain({required this.id, required this.onEditorBack});

  final String id;
  final VoidCallback onEditorBack;

  Future<void> _reset(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.appsLoadFailed;
    try {
      await context.read<AppsRepository>().resetEditor();
      onEditorBack();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) {
        final cubit = AppRunCubit(
          repository: context.read<AppsRepository>(),
          id: id,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _AppScreen(
        banner: Builder(
          builder: (context) => ColoredBox(
            color: AppColors.fill,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Row(
                spacing: AppSpacing.s3,
                children: [
                  Expanded(
                    child: Text(
                      l10n.appsEditorFailed,
                      style: AppTypography.label,
                    ),
                  ),
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    onPressed: () => unawaited(_reset(context)),
                    text: l10n.appsEditorReset,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app in the nearest [AppRunCubit], drawn by [AppRenderer].
class _AppScreen extends StatelessWidget {
  const _AppScreen({this.banner});

  /// Over the screen: why this is not the editor, when it is not.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AppRunCubit>();
    final state = context.watch<AppRunCubit>().state;
    final app = state.app;
    final fills = app != null && AppRenderer.fillsScreen(app.ui);
    final renderer = app == null
        ? null
        : AppRenderer(
            ui: app.ui,
            data: app.data,
            pending: state.pending,
            onEdit: cubit.edit,
            onAction: (action, event) => unawaited(cubit.act(action, event)),
          );

    return BlocListener<AppRunCubit, AppRunState>(
      listenWhen: (previous, current) =>
          current.error != null && previous.error != current.error,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.error!.isEmpty ? l10n.appsActionFailed : state.error!,
          ),
        ),
      ),
      child: Scaffold(
        // A screen made with a Screen brings its own top bar, back arrow
        // included.
        appBar: fills ? null : AppBar(title: Text(app?.name ?? '')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?banner,
            Expanded(
              child: app == null
                  ? state.loadFailed
                        ? AppEmptyState(
                            title: l10n.appsLoadFailed,
                            action: AppButton(
                              onPressed: () => unawaited(cubit.load()),
                              text: l10n.appsRetry,
                            ),
                          )
                        : const Center(child: AppTypingIndicator())
                  : fills
                  ? renderer!
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      children: [renderer!],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/apps/app_renderer.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';

/// {@template app_run_page}
/// One app the assistant built, running: its screen drawn from its stored
/// components, each tap run by the app's own action, on the server or, for a
/// client action, on the device. On a wide window it runs inside a phone.
/// {@endtemplate}
class AppRunPage extends StatelessWidget {
  /// {@macro app_run_page}
  const AppRunPage({required this.id, super.key});

  /// The app's id.
  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = AppRunCubit(
          repository: context.read<AppsRepository>(),
          id: id,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _AppRunView(),
    );
  }
}

class _AppRunView extends StatelessWidget {
  const _AppRunView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a phone the app is the screen. Wider, it runs inside a drawn
        // phone, so it looks the way it will in a hand.
        if (constraints.maxWidth < AppSpacing.phoneFrameBreakpoint) {
          return const _AppScreen(framed: false);
        }
        return Scaffold(
          appBar: AppBar(),
          body: const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s6,
              0,
              AppSpacing.s6,
              AppSpacing.s8,
            ),
            child: Center(
              child: AppPhoneFrame(child: _AppScreen(framed: true)),
            ),
          ),
        );
      },
    );
  }
}

/// The built app's own screen: its name, and what it draws.
class _AppScreen extends StatelessWidget {
  const _AppScreen({required this.framed});

  /// Inside a drawn phone, where the way back is the page's, not the app's.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AppRunCubit>();
    final state = context.watch<AppRunCubit>().state;
    final app = state.app;

    // Its own messenger, so a failed tap is told inside the phone.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => BlocListener<AppRunCubit, AppRunState>(
          listenWhen: (previous, current) =>
              current.error != null && previous.error != current.error,
          listener: (context, state) =>
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.error!.isEmpty ? l10n.appsActionFailed : state.error!,
                  ),
                ),
              ),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: !framed,
              title: Text(app?.name ?? ''),
            ),
            body: app != null
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.maxContentWidth,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.s6),
                        children: [
                          AppRenderer(
                            ui: app.ui,
                            data: app.data,
                            onEdit: cubit.edit,
                            onAction: (action, event) =>
                                unawaited(cubit.act(action, event)),
                          ),
                        ],
                      ),
                    ),
                  )
                : state.loadFailed
                ? AppEmptyState(
                    title: l10n.appsLoadFailed,
                    action: AppButton(
                      onPressed: () => unawaited(cubit.load()),
                      text: l10n.appsRetry,
                    ),
                  )
                : const Center(child: AppTypingIndicator()),
          ),
        ),
      ),
    );
  }
}

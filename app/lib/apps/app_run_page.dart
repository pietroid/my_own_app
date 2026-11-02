import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/apps/app_renderer.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/studio_chat.dart';
import 'package:my_own_app/apps/studio_cubit.dart';
import 'package:my_own_app/apps/studio_inspector.dart';

/// {@template app_run_page}
/// One app the assistant built, running, and being changed.
///
/// Its screen is drawn from its stored components, each tap run by the
/// app's own action. Beside it, the conversation that changes it: each
/// request makes a new version, and any version can be looked at and
/// brought back.
///
/// - From [AppSpacing.studioBreakpoint] up, the studio: the conversation,
///   the app inside a phone, and the inspector (the component tree, and
///   the picked component's menu).
/// - From [AppSpacing.phoneFrameBreakpoint], the conversation and the phone.
/// - On a phone, the app is the screen; the conversation opens as a sheet.
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
      child: BlocProvider(
        create: (context) {
          final cubit = StudioCubit(
            repository: context.read<AppsRepository>(),
            id: id,
            onApp: context.read<AppRunCubit>().replace,
          );
          unawaited(cubit.load());
          return cubit;
        },
        child: const _AppRunView(),
      ),
    );
  }
}

class _AppRunView extends StatelessWidget {
  const _AppRunView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // On a phone the app is the screen. Wider, it runs inside a drawn
        // phone, so it looks the way it will in a hand.
        if (width < AppSpacing.phoneFrameBreakpoint) {
          return const _AppScreen(framed: false);
        }
        final inspecting = width >= AppSpacing.studioBreakpoint;
        return _Studio(inspecting: inspecting);
      },
    );
  }
}

/// The conversation, the phone, and (when [inspecting]) the inspector.
class _Studio extends StatelessWidget {
  const _Studio({required this.inspecting});

  final bool inspecting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final studio = context.watch<StudioCubit>();
    final state = studio.state;
    final app = context.select<AppRunCubit, AppSnapshot?>(
      (cubit) => cubit.state.app,
    );
    final shown = state.viewing != null ? state.viewed : app;

    return Scaffold(
      appBar: AppBar(
        title: Text(app?.name ?? ''),
        actions: [
          if (inspecting)
            IconButton(
              tooltip: state.selecting
                  ? l10n.studioSelectDone
                  : l10n.studioSelect,
              isSelected: state.selecting,
              onPressed: state.viewing != null ? null : studio.toggleSelecting,
              icon: AppIcon(
                iconData: AppIcons.select,
                color: state.selecting ? AppColors.accent : null,
              ),
            ),
          const SizedBox(width: AppSpacing.s2),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: AppSpacing.studioChatWidth,
            child: StudioChat(),
          ),
          const VerticalDivider(width: AppSpacing.hairline),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s6,
                AppSpacing.s4,
                AppSpacing.s6,
                AppSpacing.s8,
              ),
              child: Column(
                spacing: AppSpacing.s4,
                children: [
                  if (state.viewing case final n?) _ViewingBar(n: n),
                  const Expanded(
                    child: Center(
                      child: AppPhoneFrame(child: _AppScreen(framed: true)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (inspecting) ...[
            const VerticalDivider(width: AppSpacing.hairline),
            SizedBox(
              width: AppSpacing.studioInspectorWidth,
              child: StudioInspector(app: shown),
            ),
          ],
        ],
      ),
    );
  }
}

/// Over the phone while an earlier version is on it: which one, the way
/// back, and bringing it back.
class _ViewingBar extends StatelessWidget {
  const _ViewingBar({required this.n});

  final int n;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final studio = context.read<StudioCubit>();
    final sending = context.select<StudioCubit, bool>(
      (cubit) => cubit.state.sending,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s3,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accent),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSpacing.cardRadius),
        ),
      ),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          const AppIcon(iconData: AppIcons.version, color: AppColors.accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.studioViewing(n), style: AppTypography.labelStrong),
                Text(l10n.studioViewingBody, style: AppTypography.caption),
              ],
            ),
          ),
          AppButton(
            variant: AppButtonVariant.tertiary,
            onPressed: studio.back,
            text: l10n.studioBackToCurrent,
          ),
          AppButton(
            icon: const AppIcon(
              iconData: AppIcons.restore,
              size: AppSpacing.iconSmall,
              color: AppColors.onAccent,
            ),
            onPressed: sending ? null : () => unawaited(studio.restore()),
            text: l10n.studioRestore,
          ),
        ],
      ),
    );
  }
}

/// The built app's own screen: its name, and what it draws. While an
/// earlier version is looked at, that version, which taps do not change.
class _AppScreen extends StatelessWidget {
  const _AppScreen({required this.framed});

  /// Inside a drawn phone, where the way back is the page's, not the app's.
  final bool framed;

  Future<void> _openChat(BuildContext context) {
    final studio = context.read<StudioCubit>();
    final run = context.read<AppRunCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: studio),
          BlocProvider.value(value: run),
        ],
        child: const FractionallySizedBox(
          heightFactor: 0.9,
          child: StudioChat(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AppRunCubit>();
    final state = context.watch<AppRunCubit>().state;
    final studio = context.watch<StudioCubit>();
    final viewing = studio.state.viewing != null;
    final app = viewing ? studio.state.viewed : state.app;

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
              actions: [
                if (!framed) ...[
                  IconButton(
                    tooltip: l10n.studioOpenChat,
                    onPressed: () => unawaited(_openChat(context)),
                    icon: const AppIcon(iconData: AppIcons.assistant),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                ],
              ],
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
                          if (viewing)
                            AppRenderer(
                              ui: app.ui,
                              data: app.data,
                              onEdit: (_, _) {},
                              onAction: (_, _) {},
                            )
                          else
                            AppRenderer(
                              ui: app.ui,
                              data: app.data,
                              onEdit: cubit.edit,
                              onAction: (action, event) =>
                                  unawaited(cubit.act(action, event)),
                              onSelect: studio.state.selecting
                                  ? studio.select
                                  : null,
                              selectedId: studio.state.selectedId,
                            ),
                        ],
                      ),
                    ),
                  )
                : viewing && studio.state.viewFailed
                ? AppEmptyState(title: l10n.studioViewFailed)
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

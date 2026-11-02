import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/app/app.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';

/// {@template home_page}
/// The signed-in home: the apps the person had built, and a field to
/// describe the next one.
///
/// The greeting says who is signed in; the icons beside it open the
/// assistant and sign out.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = AppsCubit(repository: context.read<AppsRepository>());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final app = await context.read<AppsCubit>().create(text);
    if (app == null || !mounted) return;
    _controller.clear();
    unawaited(context.push('/apps/${app.id}'));
  }

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );
    final l10n = context.l10n;
    final state = context.watch<AppsCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          firstName == null
              ? l10n.homeGreetingAnonymous
              : l10n.homeGreeting(firstName),
        ),
        actions: [
          IconButton(
            tooltip: l10n.homeAssistant,
            icon: const AppIcon(iconData: AppIcons.assistant),
            onPressed: () => context.push('/assistente'),
          ),
          IconButton(
            tooltip: l10n.homeSignOut,
            icon: const AppIcon(iconData: AppIcons.signOut),
            onPressed: () =>
                context.read<AppBloc>().add(const AppLogoutRequested()),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Column(
              children: [
                Expanded(
                  child: state.apps.isEmpty
                      ? AppEmptyState(
                          title: l10n.homeEmptyTitle,
                          body: l10n.homeEmptyBody,
                        )
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          children: [
                            for (final app in state.apps)
                              ListTile(
                                title: Text(
                                  app.name,
                                  style: AppTypography.bodyStrong,
                                ),
                                trailing: const AppIcon(
                                  iconData: AppIcons.open,
                                ),
                                onTap: () => context.push('/apps/${app.id}'),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.s3,
                    children: [
                      if (state.creating)
                        Row(
                          spacing: AppSpacing.s3,
                          children: [
                            const AppTypingIndicator(),
                            Text(l10n.appsCreating, style: AppTypography.label),
                          ],
                        ),
                      if (state.failed)
                        Text(
                          state.error ?? l10n.appsCreateFailed,
                          style: AppTypography.label.copyWith(
                            color: AppColors.negative,
                          ),
                        ),
                      TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !state.creating,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => unawaited(_create()),
                        style: AppTypography.body,
                        decoration: InputDecoration(
                          hintText: l10n.appsCreateHint,
                        ),
                      ),
                      AppButton(
                        expand: true,
                        onPressed: state.creating
                            ? null
                            : () => unawaited(_create()),
                        text: l10n.appsCreate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

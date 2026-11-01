import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/app/app.dart';

/// {@template home_page}
/// The signed-in home: blank, waiting for the app to be built on it.
///
/// The greeting says who is signed in, the icon beside it signs out, and the
/// one button opens the assistant.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          firstName == null
              ? l10n.homeGreetingAnonymous
              : l10n.homeGreeting(firstName),
        ),
        actions: [
          IconButton(
            tooltip: l10n.homeSignOut,
            icon: const AppIcon(iconData: AppIcons.signOut),
            onPressed: () =>
                context.read<AppBloc>().add(const AppLogoutRequested()),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
      ),
      body: AppEmptyState(
        title: l10n.homeEmptyTitle,
        body: l10n.homeEmptyBody,
        action: AppButton.icon(
          onPressed: () => context.push('/assistente'),
          icon: const AppIcon(
            iconData: AppIcons.assistant,
            color: AppColors.onAccent,
          ),
          text: l10n.assistantOpen,
        ),
      ),
    );
  }
}

import 'package:app_ui/app_ui.dart';
import 'package:auth/src/auth_bloc/auth_bloc.dart';
import 'package:auth/src/data/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template auth_screen}
/// The screen someone signs in on.
///
/// It owns the sign-in and reports how it went. What it draws around the
/// sign-in is up to [child], which places an [AuthSignInButton] wherever it
/// wants one. Without a [child] it is the logo, the name and a full-width
/// button.
/// {@endtemplate}
class AuthScreen extends StatelessWidget {
  /// {@macro auth_screen}
  const AuthScreen({
    required this.authRepository,
    this.onAuthenticated,
    this.child,
    super.key,
  });

  /// Repository used for authentication operations.
  final AuthRepository authRepository;

  /// Called when the user has successfully signed in.
  final VoidCallback? onAuthenticated;

  /// What the screen shows. It must hold an [AuthSignInButton].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(
        authRepository: authRepository,
      ),
      child: _AuthScreenView(
        onAuthenticated: onAuthenticated,
        child: child ?? const _DefaultAuthBody(),
      ),
    );
  }
}

class _AuthScreenView extends StatelessWidget {
  const _AuthScreenView({required this.child, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          onAuthenticated?.call();
        }
        if (state.status == AuthStatus.failure) {
          _showError(
            context,
            state.errorMessage ?? context.l10n.authSignInFailed,
          );
        }
      },
      child: Scaffold(body: child),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DefaultAuthBody extends StatelessWidget {
  const _DefaultAuthBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(AppBrand.markAsset, package: 'app_ui', height: 120),
            const SizedBox(height: AppSpacing.s6),
            Text(
              context.l10n.appName,
              textAlign: TextAlign.center,
              style: AppTypography.headline,
            ),
            const SizedBox(height: AppSpacing.s12),
            const AuthSignInButton(expand: true),
          ],
        ),
      ),
    );
  }
}

/// {@template auth_sign_in_button}
/// Starts the Google sign-in, and spins while it runs.
///
/// It reads the [AuthBloc] an [AuthScreen] provides, so it only works below
/// one.
/// {@endtemplate}
class AuthSignInButton extends StatelessWidget {
  /// {@macro auth_sign_in_button}
  const AuthSignInButton({
    this.expand = false,
    this.compact = false,
    this.label,
    super.key,
  });

  /// Whether the button stretches to the width of its parent.
  final bool expand;

  /// A quiet text button with no mark, for a screen that is about something
  /// else and only lets someone in on the side.
  final bool compact;

  /// The word on the button, for a screen written in another language.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.status == AuthStatus.loading,
    );

    if (loading) {
      return const SizedBox.square(
        dimension: AppSpacing.tapTarget,
        child: Center(
          child: SizedBox.square(
            dimension: AppSpacing.s5,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    void signIn() =>
        context.read<AuthBloc>().add(const AuthGoogleSignInRequested());

    if (compact) {
      return AppButton.text(
        onPressed: signIn,
        text: label ?? context.l10n.authSignIn,
        expand: expand,
      );
    }

    return AppButton.icon(
      onPressed: signIn,
      icon: const AppIcon(iconData: AppIcons.google, color: AppColors.onAccent),
      text: label ?? context.l10n.authSignInWithGoogle,
      expand: expand,
    );
  }
}

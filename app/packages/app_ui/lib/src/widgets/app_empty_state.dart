import 'package:app_ui/app_ui.dart';

/// {@template app_empty_state}
/// What a screen shows when it has nothing yet: a title and a line under it,
/// centred, with an optional action below.
/// {@endtemplate}
class AppEmptyState extends StatelessWidget {
  /// {@macro app_empty_state}
  const AppEmptyState({
    required this.title,
    this.body,
    this.action,
    super.key,
  });

  /// The one line that says what is going on.
  final String title;

  /// What to do about it, if anything.
  final String? body;

  /// A button, when there is one thing to do.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.title,
              ),
              if (body != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: AppTypography.label,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.s6),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

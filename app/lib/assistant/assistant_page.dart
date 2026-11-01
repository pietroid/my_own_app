import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/assistant/assistant_cubit.dart';
import 'package:my_own_app/assistant/assistant_repository.dart';

/// {@template assistant_page}
/// A conversation with the assistant: the messages, and a field to write
/// the next one.
/// {@endtemplate}
class AssistantPage extends StatelessWidget {
  /// {@macro assistant_page}
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AssistantCubit(repository: context.read<AssistantRepository>()),
      child: const AssistantView(),
    );
  }
}

/// {@template assistant_view}
/// The page's body, below its [AssistantCubit].
/// {@endtemplate}
class AssistantView extends StatefulWidget {
  /// {@macro assistant_view}
  const AssistantView({super.key});

  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    unawaited(context.read<AssistantCubit>().send(text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AssistantCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistantTitle)),
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
                  child: state.messages.isEmpty
                      ? AppEmptyState(title: l10n.assistantEmpty)
                      : ListView(
                          reverse: true,
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          children: [
                            if (state.waiting) const _Typing(),
                            if (state.failed)
                              _Failure(state.error ?? l10n.assistantFailed),
                            for (final message in state.messages.reversed)
                              _Bubble(message),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s2,
                    AppSpacing.s2,
                    AppSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: l10n.assistantHint,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.assistantSend,
                        onPressed: state.waiting ? null : _send,
                        icon: const AppIcon(
                          iconData: AppIcons.send,
                          color: AppColors.accent,
                        ),
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

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == AssistantRole.user;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        constraints: const BoxConstraints(maxWidth: 420),
        // The person's words on the accent; the assistant's on a panel.
        decoration: BoxDecoration(
          color: mine ? AppColors.accentSoft : AppColors.surface,
          border: mine ? null : Border.all(color: AppColors.line),
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
        child: SelectableText(message.content, style: AppTypography.body),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.s3),
        child: AppTypingIndicator(),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.negative),
      ),
    );
  }
}

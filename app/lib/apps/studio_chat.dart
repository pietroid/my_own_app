import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';
import 'package:my_own_app/apps/studio_cubit.dart';
import 'package:my_own_app/apps/studio_inspector.dart';

/// {@template studio_chat}
/// The conversation about a built app: each request, the assistant's
/// answer, and under it the version that answer made, which opens that
/// version on the phone. The field at the bottom asks for the next change,
/// about the picked component when one was made its subject.
/// {@endtemplate}
class StudioChat extends StatefulWidget {
  /// {@macro studio_chat}
  const StudioChat({super.key});

  @override
  State<StudioChat> createState() => _StudioChatState();
}

class _StudioChatState extends State<StudioChat> {
  final _controller = TextEditingController();
  final _field = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _field.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    unawaited(context.read<StudioCubit>().send(text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final studio = context.watch<StudioCubit>();
    final state = studio.state;
    final ui = context.select<AppRunCubit, List<Map<String, dynamic>>>(
      (cubit) => cubit.state.app?.ui ?? const [],
    );
    final focused = state.focusId == null
        ? null
        : ui.where((c) => c['id'] == state.focusId).firstOrNull;

    return BlocListener<StudioCubit, StudioState>(
      // "Pedir mudança" in the inspector brings the person here.
      listenWhen: (previous, current) =>
          current.focusId != null && previous.focusId != current.focusId,
      listener: (context, _) => _field.requestFocus(),
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s4,
                AppSpacing.s4,
                AppSpacing.s2,
              ),
              child: Text(l10n.studioChatTitle, style: AppTypography.title),
            ),
            Expanded(
              child: state.historyFailed
                  ? AppEmptyState(
                      title: l10n.studioHistoryFailed,
                      action: AppButton(
                        onPressed: () => unawaited(studio.load()),
                        text: l10n.appsRetry,
                      ),
                    )
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      children: [
                        if (state.sendFailed)
                          _Failure(state.error ?? l10n.studioSendFailed),
                        if (state.sending) const _Working(),
                        if (state.pending case final pending?
                            when pending.isNotEmpty)
                          _Bubble(pending, mine: true),
                        for (final version in state.versions.reversed)
                          _Turn(version: version, state: state),
                      ],
                    ),
            ),
            const Divider(height: AppSpacing.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s3,
                AppSpacing.s2,
                AppSpacing.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.s2,
                children: [
                  if (focused != null)
                    _FocusChip(
                      component: focused,
                      onClear: () => studio.focus(null),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _field,
                          minLines: 1,
                          maxLines: 5,
                          enabled: !state.sending,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: focused != null
                                ? l10n.studioChatHintFocused
                                : l10n.studioChatHint,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.studioSend,
                        onPressed: state.sending ? null : _send,
                        icon: const AppIcon(
                          iconData: AppIcons.send,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One version as a turn of the conversation: what was asked, what was
/// answered, and the version it made.
class _Turn extends StatelessWidget {
  const _Turn({required this.version, required this.state});

  final AppVersion version;
  final StudioState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final restored = version.changes.restoredFrom;
    final reply = version.reply.isNotEmpty
        ? version.reply
        : restored != null
        ? l10n.studioRestored(restored)
        : version.n == 1
        ? l10n.studioFirstReply
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s2,
        children: [
          if (version.prompt.isNotEmpty) _Bubble(version.prompt, mine: true),
          if (reply.isNotEmpty) _Bubble(reply, mine: false),
          if (version.changes.any || version.n == 1 || restored != null)
            _VersionChip(
              version: version,
              current: version.n == state.current,
              viewing: version.n == state.viewing,
            )
          else
            Text(l10n.studioNoChanges, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// A version, under the answer that made it: opens it on the phone.
class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.version,
    required this.current,
    required this.viewing,
  });

  final AppVersion version;
  final bool current;
  final bool viewing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final changes = version.changes;
    final what = [
      if (changes.componentCount > 0)
        l10n.studioComponents(changes.componentCount),
      if (changes.actionCount > 0) l10n.studioActions(changes.actionCount),
    ].join(' · ');
    final on =
        viewing ||
        (current &&
            context.select<StudioCubit, bool>(
              (cubit) => cubit.state.viewing == null,
            ));

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: on ? AppColors.accentSoft : AppColors.fill,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: on ? AppColors.accent : AppColors.line),
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
        child: InkWell(
          onTap: () => unawaited(context.read<StudioCubit>().view(version.n)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.s2,
              children: [
                const AppIcon(
                  iconData: AppIcons.version,
                  size: AppSpacing.iconSmall,
                ),
                Text(
                  l10n.studioVersion(version.n),
                  style: AppTypography.labelStrong,
                ),
                if (current)
                  Text(
                    l10n.studioCurrent,
                    style: AppTypography.label.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                if (what.isNotEmpty)
                  Flexible(
                    child: Text(
                      what,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
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

/// The component the next request is about, over the field.
class _FocusChip extends StatelessWidget {
  const _FocusChip({required this.component, required this.onClear});

  final Map<String, dynamic> component;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = component['component'] as String?;
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.s3),
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.chipRadius)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s2,
        children: [
          AppIcon(iconData: componentIcon(type), size: AppSpacing.iconSmall),
          Flexible(
            child: Text(
              l10n.studioFocus(
                '${componentName(l10n, type)} · ${component['id']}',
              ),
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label,
            ),
          ),
          IconButton(
            tooltip: l10n.studioClearFocus,
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const AppIcon(
              iconData: AppIcons.close,
              size: AppSpacing.iconSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, {required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        // The person's words on the accent; the assistant's on a panel.
        decoration: BoxDecoration(
          color: mine ? AppColors.accentSoft : AppColors.fill,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
        child: SelectableText(text, style: AppTypography.body),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          const AppTypingIndicator(),
          Text(context.l10n.studioSending, style: AppTypography.label),
        ],
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

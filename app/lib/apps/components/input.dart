part of '../app_renderer.dart';

/// TextField, CheckBox, Switch, ChoicePicker, Slider, DateTimeInput and
/// Button: what the person touches. What they type or pick is kept on the
/// device ([_Render.edit]) until an action sends it from the event.
extension on _Render {
  Widget field(Map<String, dynamic> c, _Scope scope) {
    final path = scope.resolve(_Render.pathOf(c['value']));
    final variant = c['variant'];
    final title = string(c['title'], scope);
    final field = _Field(
      key: ValueKey('field:$path'),
      label: string(c['label'], scope),
      value: string(c['value'], scope),
      long: variant == 'longText',
      number: variant == 'number',
      obscured: variant == 'obscured',
      search: variant == 'search',
      icon:
          AppIcons.named[string(c['icon'], scope)] ??
          (variant == 'search' ? AppIcons.named['search'] : null),
      onChanged: (text) => edit(c['value'], scope, text),
      onSubmitted: hasAction(c) && variant != 'longText'
          ? () => fire(c, scope)
          : null,
    );
    if (title.isEmpty) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s1,
      children: [
        Text(title, style: AppTypography.labelStrong),
        field,
      ],
    );
  }

  Widget check(
    Map<String, dynamic> c,
    _Scope scope, {
    required bool switchStyle,
  }) {
    final on = value(c['value'], scope) == true;
    final title = Text(string(c['label'], scope), style: AppTypography.body);
    void toggle(Object? _) => change(c, scope, !on);
    return switchStyle
        ? SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: title,
            value: on,
            onChanged: toggle,
          )
        : CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: title,
            value: on,
            onChanged: toggle,
          );
  }

  Widget choice(Map<String, dynamic> c, _Scope scope) {
    final options = [
      for (final option in (value(c['options'], scope) as List?) ?? const [])
        if (option is Map)
          (
            label: '${option['label'] ?? option['value']}',
            value: option['value'],
          )
        else
          (label: '$option', value: option),
    ];
    final chosen = [...?(value(c['value'], scope) as List?)];
    final single = c['variant'] != 'multipleSelection';
    final label = string(c['label'], scope);
    void pick(Object? option) {
      final has = chosen.contains(option);
      final next = single
          ? [option]
          : has
          ? [...chosen.where((v) => v != option)]
          : [...chosen, option];
      change(c, scope, next);
    }

    if (value(c['style'], scope) == 'segmented') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s1 / 2),
        decoration: const BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              _Segment(
                label: option.label,
                chosen: chosen.contains(option.value),
                onTap: () => pick(option.value),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s2,
      children: [
        if (label.isNotEmpty) Text(label, style: AppTypography.label),
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final option in options)
              _Chip(
                label: option.label,
                chosen: chosen.contains(option.value),
                onTap: () => pick(option.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget slider(Map<String, dynamic> c, _Scope scope) {
    final min = (value(c['min'], scope) as num?)?.toDouble() ?? 0;
    final max = (value(c['max'], scope) as num?)?.toDouble() ?? 100;
    final now = (value(c['value'], scope) as num?)?.toDouble() ?? min;
    final label = string(c['label'], scope);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty) Text(label, style: AppTypography.label),
        Slider(
          min: min,
          max: max < min ? min : max,
          value: now.clamp(min, max < min ? min : max),
          // The thumb follows the finger on the device; the action, if
          // any, runs once it is let go.
          onChanged: (v) => edit(c['value'], scope, v),
          onChangeEnd: hasAction(c)
              ? (v) => fire(c, scope, {'value': v})
              : null,
        ),
      ],
    );
  }

  Widget date(Map<String, dynamic> c, _Scope scope) {
    final current = DateTime.tryParse(string(c['value'], scope));
    final withDate = c['enableDate'] != false;
    final withTime = c['enableTime'] == true;
    final label = string(c['label'], scope);
    return Builder(
      builder: (context) {
        final localizations = MaterialLocalizations.of(context);
        final shown = current == null
            ? label
            : [
                if (withDate) localizations.formatShortDate(current),
                if (withTime)
                  localizations.formatTimeOfDay(
                    TimeOfDay.fromDateTime(current),
                  ),
              ].join(' ');

        Future<void> pick() async {
          final base = current ?? DateTime.now();
          var day = DateTime(base.year, base.month, base.day);
          var time = TimeOfDay.fromDateTime(base);
          if (withDate) {
            final picked = await showDatePicker(
              context: context,
              initialDate: day,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (picked == null || !context.mounted) return;
            day = picked;
          }
          if (withTime) {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked == null) return;
            time = picked;
          }
          final at = DateTime(
            day.year,
            day.month,
            day.day,
            withTime ? time.hour : 0,
            withTime ? time.minute : 0,
          );
          change(c, scope, at.toIso8601String());
        }

        return OutlinedButton.icon(
          onPressed: () => unawaited(pick()),
          icon: AppIcon(
            iconData: withDate
                ? AppIcons.named['calendar']!
                : AppIcons.named['clock']!,
            size: AppSpacing.iconSmall,
          ),
          label: Text(shown, style: AppTypography.body),
        );
      },
    );
  }

  Widget button(Map<String, dynamic> c, _Scope scope) {
    // While picking, a button keeps its enabled look (the picker takes its
    // taps before it does).
    final onPressed = hasAction(c)
        ? () => fire(c, scope)
        : picking && (c['action'] as Map?)?['event'] != null
        ? () {}
        : null;
    final label = string(c['label'], scope);
    final icon = AppIcons.named[string(c['icon'], scope)];
    final kind = value(c['variant'], scope);
    final variant = switch (kind) {
      'primary' || 'danger' => AppButtonVariant.primary,
      'borderless' => AppButtonVariant.tertiary,
      _ => AppButtonVariant.secondary,
    };
    final color = kind == 'danger' ? AppColors.negative : AppColors.accent;
    final expand = c['width'] == 'fill';
    if (label.isEmpty && icon != null) {
      // An icon alone: filled when it is the main thing (send), plain
      // otherwise (close, more).
      final filled = variant == AppButtonVariant.primary;
      return IconButton(
        onPressed: onPressed,
        style: filled
            ? IconButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: AppColors.fillStrong,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppSpacing.chipRadius),
                  ),
                ),
              )
            : null,
        icon: AppIcon(
          iconData: icon,
          size: AppSpacing.navIcon,
          color: filled ? AppColors.onAccent : AppColors.ink2,
        ),
      );
    }
    return icon == null
        ? AppButton(
            variant: variant,
            color: color,
            expand: expand,
            text: label,
            onPressed: onPressed,
          )
        : AppButton.icon(
            variant: variant,
            color: color,
            expand: expand,
            icon: AppIcon(iconData: icon, size: AppSpacing.iconSmall),
            text: label,
            onPressed: onPressed,
          );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.long,
    required this.number,
    required this.obscured,
    required this.search,
    required this.icon,
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final String label;
  final String value;
  final bool long;
  final bool number;
  final bool obscured;
  final bool search;
  final AppIconData? icon;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Field oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An action may change the field's value (clearing it after "add").
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submit = widget.onSubmitted;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: submit == null ? null : (_) => submit(),
      style: AppTypography.body,
      obscureText: widget.obscured,
      minLines: widget.long ? 3 : 1,
      maxLines: widget.long ? 8 : 1,
      keyboardType: widget.long
          ? TextInputType.multiline
          : widget.number
          ? TextInputType.number
          : TextInputType.text,
      textInputAction: submit == null ? null : TextInputAction.send,
      decoration: InputDecoration(
        hintText: widget.label,
        prefixIcon: widget.icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                child: AppIcon(
                  iconData: widget.icon!,
                  size: AppSpacing.iconSmall,
                  color: AppColors.ink3,
                ),
              ),
        prefixIconConstraints: const BoxConstraints(),
        border: widget.search
            ? const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppSpacing.pillRadius),
                ),
                borderSide: BorderSide.none,
              )
            : null,
      ),
    );
  }
}

/// One option of a segmented control: raised when it is the chosen one.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppSpacing.buttonRadius));
    return Material(
      color: chosen ? AppColors.fillStrong : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s1,
          ),
          child: Text(
            label,
            style: AppTypography.labelStrong.copyWith(
              color: chosen ? AppColors.ink : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

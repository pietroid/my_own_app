part of '../app_renderer.dart';

/// TextField, CheckBox, Switch, ChoicePicker, Slider, DateTimeInput and
/// Button: what the person touches. What they type or pick is kept on the
/// device ([_Render.edit]) until an action sends it from the event.
extension on _Render {
  Widget field(Map<String, dynamic> c, _Scope scope) {
    final path = scope.resolve(_Render.pathOf(c['value']));
    final variant = c['variant'];
    return _Field(
      key: ValueKey('field:$path'),
      label: string(c['label'], scope),
      value: string(c['value'], scope),
      long: variant == 'longText',
      number: variant == 'number',
      obscured: variant == 'obscured',
      onChanged: (text) => edit(c['value'], scope, text),
      onSubmitted: hasAction(c) && variant != 'longText'
          ? () => fire(c, scope)
          : null,
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
                onTap: () {
                  final has = chosen.contains(option.value);
                  final next = single
                      ? [option.value]
                      : has
                      ? [...chosen.where((v) => v != option.value)]
                      : [...chosen, option.value];
                  change(c, scope, next);
                },
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
    final onPressed = hasAction(c) ? () => fire(c, scope) : null;
    final label = string(c['label'], scope);
    final icon = AppIcons.named[string(c['icon'], scope)];
    final variant = switch (c['variant']) {
      'primary' => AppButtonVariant.primary,
      'borderless' => AppButtonVariant.tertiary,
      _ => AppButtonVariant.secondary,
    };
    if (label.isEmpty && icon != null) {
      return IconButton(
        onPressed: onPressed,
        icon: AppIcon(
          iconData: icon,
          color: variant == AppButtonVariant.primary
              ? AppColors.accent
              : AppColors.ink2,
        ),
      );
    }
    return icon == null
        ? AppButton(variant: variant, text: label, onPressed: onPressed)
        : AppButton.icon(
            variant: variant,
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
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final String label;
  final String value;
  final bool long;
  final bool number;
  final bool obscured;
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
      decoration: InputDecoration(hintText: widget.label),
    );
  }
}

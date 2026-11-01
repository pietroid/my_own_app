import 'dart:async';

import 'package:app_ui/app_ui.dart';

/// {@template app_typing_indicator}
/// Three small blocks that light up in turn, in [AppColors.accent] over
/// [AppColors.ink3]: something is being put together. Shown while the
/// assistant writes its answer.
/// {@endtemplate}
class AppTypingIndicator extends StatefulWidget {
  /// {@macro app_typing_indicator}
  const AppTypingIndicator({super.key});

  @override
  State<AppTypingIndicator> createState() => _AppTypingIndicatorState();
}

class _AppTypingIndicatorState extends State<AppTypingIndicator>
    with SingleTickerProviderStateMixin {
  static const _blocks = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Still, on the first block, when the person asked for less motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final lit = (_controller.value * _blocks).floor() % _blocks;
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s1,
          children: [
            for (var i = 0; i < _blocks; i++)
              SizedBox.square(
                dimension: AppSpacing.typingBlock,
                child: ColoredBox(
                  color: i == lit ? AppColors.accent : AppColors.ink3,
                ),
              ),
          ],
        );
      },
    );
  }
}

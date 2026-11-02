import 'dart:async';

import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template app_phone_frame}
/// A phone drawn around [child], at a phone's size, scaled down to fit.
///
/// The child is laid out at [screen] with the insets of a phone's status bar
/// and home indicator, whatever box it is put in, so a built app looks the
/// way it will in a hand. The whole phone then shrinks to the space it is
/// given (never grows past its size), and still takes taps.
///
/// The measures below are a phone's, not the app's spacing: they draw the
/// device and nothing else.
/// {@endtemplate}
class AppPhoneFrame extends StatelessWidget {
  /// {@macro app_phone_frame}
  const AppPhoneFrame({required this.child, super.key});

  /// The screen.
  final Widget child;

  /// The logical size of the screen inside the frame.
  static const screen = Size(390, 844);

  /// What the status bar and the home indicator take from the screen.
  static const _insets = EdgeInsets.only(top: 54, bottom: 34);

  static const _bezel = 12.0;
  static const _outerRadius = 56.0;
  static const double _screenRadius = _outerRadius - _bezel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: screen.width + _bezel * 2,
        height: screen.height + _bezel * 2,
        padding: const EdgeInsets.all(_bezel),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_outerRadius),
          border: Border.all(color: AppColors.fillStrong, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_screenRadius),
          child: MediaQuery(
            data: media.copyWith(
              size: screen,
              padding: _insets,
              viewPadding: _insets,
              viewInsets: EdgeInsets.zero,
            ),
            child: ColoredBox(
              color: AppColors.bg,
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: _StatusBar()),
                  ),
                  const Positioned(
                    bottom: AppSpacing.s2,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: _HomeIndicator()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The clock and the island, drawn once rather than faked per screen.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 124,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.device,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Align(alignment: Alignment.centerLeft, child: _Clock()),
          ),
        ],
      ),
    );
  }
}

/// The time now, to the minute.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final next = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _now.hour,
    ).add(Duration(minutes: _now.minute + 1));
    _timer = Timer(next.difference(_now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_now.hour.toString().padLeft(2, '0')}:'
      '${_now.minute.toString().padLeft(2, '0')}',
      style: AppTypography.labelStrong,
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 134,
        height: 5,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ),
    );
  }
}

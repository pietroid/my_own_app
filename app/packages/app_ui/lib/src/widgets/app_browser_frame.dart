import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template app_browser_frame}
/// A browser window drawn around [child], at a laptop's size, scaled down to
/// fit: what `AppPhoneFrame` is for a phone app, for a web one.
///
/// The child is laid out at [screen] whatever box it is put in, so a web
/// app is laid out wide even inside a narrow column; the whole window then
/// shrinks to the space it is given (never grows past its size), and still
/// takes taps. [address] is shown in its address bar.
///
/// The measures below are a browser's, not the app's spacing: they draw the
/// window and nothing else.
/// {@endtemplate}
class AppBrowserFrame extends StatelessWidget {
  /// {@macro app_browser_frame}
  const AppBrowserFrame({required this.child, this.address = '', super.key});

  /// The page.
  final Widget child;

  /// What the address bar says.
  final String address;

  /// The logical size of the page inside the window.
  static const screen = Size(1280, 800);

  static const _barHeight = 44.0;
  static const _radius = 12.0;
  static const _dot = 12.0;
  static const _addressWidth = 480.0;
  static const _border = 1.5;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        // The border is drawn inside the box: room for it on each side.
        width: screen.width + _border * 2,
        height: screen.height + _barHeight + _border * 2,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: AppColors.fillStrong, width: _border),
        ),
        child: Column(
          children: [
            Container(
              height: _barHeight,
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Row(
                spacing: AppSpacing.s2,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: _dot,
                      height: _dot,
                      decoration: const BoxDecoration(
                        color: AppColors.fillStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: _addressWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3,
                          vertical: AppSpacing.s1,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppSpacing.pillRadius),
                          ),
                        ),
                        child: Text(
                          address,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                      ),
                    ),
                  ),
                  // As wide as the dots, so the address sits in the middle.
                  const SizedBox(width: _dot * 3 + AppSpacing.s2 * 2),
                ],
              ),
            ),
            SizedBox.fromSize(
              size: screen,
              child: MediaQuery(
                data: media.copyWith(
                  size: screen,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

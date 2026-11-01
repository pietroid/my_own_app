import 'package:app_ui/src/theme/app_brand.dart';
import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's theme.
///
/// Every component theme below pulls from [AppColors], [AppSpacing], and
/// [AppTypography], so a screen never has to restate a token.
abstract final class AppTheme {
  /// The theme this build ships.
  static ThemeData get current {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          // Light today, which is the default; the brand decides.
          // ignore: avoid_redundant_argument_values
          brightness: AppBrand.brightness,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: AppColors.onAccent,
          surface: AppColors.bg,
          onSurface: AppColors.ink,
          surfaceContainer: AppColors.surface,
          surfaceContainerHighest: AppColors.fill,
          onSurfaceVariant: AppColors.ink2,
          outline: AppColors.line,
          outlineVariant: AppColors.line,
          error: AppColors.negative,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: AppBrand.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: AppTypography.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
        systemOverlayStyle: overlayStyle,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.ink2,
        size: AppSpacing.iconSize,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.label.copyWith(color: AppColors.bg),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
    );
  }

  /// The status and navigation bars over [AppColors.bg].
  static SystemUiOverlayStyle get overlayStyle =>
      AppBrand.brightness == Brightness.dark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        );
}

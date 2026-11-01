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
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
        systemOverlayStyle: overlayStyle,
        // A hairline under the bar instead of a shadow.
        shape: const Border(
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.fillStrong,
        circularTrackColor: Colors.transparent,
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
        backgroundColor: AppColors.fillStrong,
        contentTextStyle: AppTypography.label.copyWith(color: AppColors.ink),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        // A hairline edge, which turns accent while the field is being
        // written in.
        border: _fieldBorder(AppColors.line),
        enabledBorder: _fieldBorder(AppColors.line),
        disabledBorder: _fieldBorder(AppColors.line),
        focusedBorder: _fieldBorder(AppColors.accent),
        errorBorder: _fieldBorder(AppColors.negative),
        focusedErrorBorder: _fieldBorder(AppColors.negative),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderSide: BorderSide(color: color),
    borderRadius: const BorderRadius.all(
      Radius.circular(AppSpacing.chipRadius),
    ),
  );

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

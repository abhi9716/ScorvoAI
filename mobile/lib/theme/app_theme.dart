import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ScorvoAI design system — dark + indigo accent.
class AppColors {
  // Surfaces
  static const bg = Color(0xff0a0a14);
  static const bgElevated = Color(0xff111120);
  static const surface = Color(0xff16162a);
  static const surfaceHigh = Color(0xff1d1d36);
  static const surfaceLine = Color(0xff262640);

  // Indigo accent system
  static const indigo = Color(0xff6366f1);
  static const indigoBright = Color(0xff818cf8);
  static const indigoDark = Color(0xff4f46e5);
  static const violet = Color(0xff8b5cf6);

  // Semantic
  static const success = Color(0xff10b981);
  static const warning = Color(0xfff59e0b);
  static const danger = Color(0xffef4444);
  static const info = Color(0xff06b6d4);

  // Text
  static const textPrimary = Color(0xfff5f5fa);
  static const textSecondary = Color(0xffa9a9c2);
  static const textTertiary = Color(0xff6c6c89);
  static const textOnAccent = Color(0xffffffff);

  // Accent gradients
  static const heroGradient = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const dimGradient = LinearGradient(
    colors: [Color(0xff1a1a30), Color(0xff222238)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Difficulty colors
  static const easy = Color(0xff10b981);
  static const medium = Color(0xfff59e0b);
  static const hard = Color(0xffef4444);
  static const mixed = Color(0xff8b5cf6);

  static Color scoreColor(double avg) {
    if (avg >= 75) return success;
    if (avg >= 60) return indigoBright;
    if (avg >= 40) return warning;
    return danger;
  }
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppText {
  static const display = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5);
  static const h1 = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3);
  static const h2 = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2);
  static const h3 = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const body = TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5);
  static const bodyDim = TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5);
  static const caption = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const captionDim = TextStyle(fontSize: 11, color: AppColors.textTertiary);
  static const label = TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600);
  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textOnAccent);
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
      ];
}

class AppDecor {
  static BoxDecoration card({Color? color, double radius = AppRadius.lg, BoxBorder? border}) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.surfaceLine, width: 0.5),
      );

  static BoxDecoration hero({double radius = AppRadius.xl}) => BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.glow(AppColors.indigo),
      );

  static BoxDecoration chip(Color color, {bool filled = true}) => BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.indigo,
        secondary: AppColors.violet,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: AppColors.textOnAccent,
        onSecondary: AppColors.textOnAccent,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textOnAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: AppText.h2,
      ),
      textTheme: TextTheme(
        displayLarge: AppText.display,
        headlineLarge: AppText.h1,
        titleLarge: AppText.h2,
        titleMedium: AppText.h3,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        labelLarge: AppText.label,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      dividerTheme: const DividerThemeData(color: AppColors.surfaceLine, thickness: 0.5, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigo,
          foregroundColor: AppColors.textOnAccent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: AppText.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceLine),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.indigoBright),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.surfaceLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.surfaceLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: AppText.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.indigo,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
      ),
      splashColor: AppColors.indigo.withValues(alpha: 0.08),
      highlightColor: AppColors.indigo.withValues(alpha: 0.04),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ScorvoAI design system — supports both dark and light modes.
/// All AppColors.X tokens are theme-aware getters; calling code does not
/// need to pass BuildContext. Toggle via [AppColors.setDark].

// ── Dark palette — deep midnight w/ subtle indigo tint ─────────────────
class _Dark {
  static const bg = Color(0xff0b0b18);            // deep midnight (warm-tinted)
  static const bgElevated = Color(0xff13132a);    // app-bar / nav-bar
  static const surface = Color(0xff1a1a36);       // cards
  static const surfaceHigh = Color(0xff242449);   // raised surfaces
  static const surfaceLine = Color(0xff2f2f58);   // borders + dividers

  static const textPrimary = Color(0xfff6f6fb);   // near-white, slight cool
  static const textSecondary = Color(0xffb4b4cf); // softer secondary
  static const textTertiary = Color(0xff7a7a99);  // for captions/metadata
  static const textOnAccent = Color(0xffffffff);
}

// ── Light palette — cool warm-white w/ indigo accents ──────────────────
class _Light {
  static const bg = Color(0xfff7f8fd);            // cool off-white
  static const bgElevated = Color(0xffffffff);    // app-bar / nav-bar
  static const surface = Color(0xffffffff);       // cards
  static const surfaceHigh = Color(0xfff0f1f8);   // raised surfaces (slight indigo)
  static const surfaceLine = Color(0xffdfe1ec);   // borders, subtly indigo

  static const textPrimary = Color(0xff14142b);   // near-black, slight cool
  static const textSecondary = Color(0xff52527a); // mid-tone, indigo-leaning
  static const textTertiary = Color(0xff8c8caa);  // captions
  static const textOnAccent = Color(0xffffffff);
}

// ── Accent colors (same in both modes) ──────────────────────────────────
class AppColors {
  // ── Theme mode state ───────────────────────────────────────────────────
  static bool _isDark = true;
  static bool get isDark => _isDark;
  static void setDark(bool dark) => _isDark = dark;

  // ── Surfaces (theme-aware) ─────────────────────────────────────────────
  static Color get bg => _isDark ? _Dark.bg : _Light.bg;
  static Color get bgElevated => _isDark ? _Dark.bgElevated : _Light.bgElevated;
  static Color get surface => _isDark ? _Dark.surface : _Light.surface;
  static Color get surfaceHigh => _isDark ? _Dark.surfaceHigh : _Light.surfaceHigh;
  static Color get surfaceLine => _isDark ? _Dark.surfaceLine : _Light.surfaceLine;

  // ── Text (theme-aware) ─────────────────────────────────────────────────
  static Color get textPrimary => _isDark ? _Dark.textPrimary : _Light.textPrimary;
  static Color get textSecondary => _isDark ? _Dark.textSecondary : _Light.textSecondary;
  static Color get textTertiary => _isDark ? _Dark.textTertiary : _Light.textTertiary;
  static Color get textOnAccent => _isDark ? _Dark.textOnAccent : _Light.textOnAccent;

  // ── Accents (constant across themes) ───────────────────────────────────
  static const indigo = Color(0xff6366f1);
  static const indigoBright = Color(0xff818cf8);
  static const indigoDark = Color(0xff4f46e5);
  static const violet = Color(0xff8b5cf6);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const success = Color(0xff10b981);
  static const warning = Color(0xfff59e0b);
  static const danger = Color(0xffef4444);
  static const info = Color(0xff06b6d4);

  // ── Difficulty ─────────────────────────────────────────────────────────
  static const easy = Color(0xff10b981);
  static const medium = Color(0xfff59e0b);
  static const hard = Color(0xffef4444);
  static const mixed = Color(0xff8b5cf6);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const heroGradient = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
  static TextStyle get display => TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5);
  static TextStyle get h1 => TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3);
  static TextStyle get h2 => TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2);
  static TextStyle get h3 => TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get body => TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5);
  static TextStyle get bodyDim => TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5);
  static TextStyle get caption => TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static TextStyle get captionDim => TextStyle(fontSize: 11, color: AppColors.textTertiary);
  static TextStyle get label => TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600);
  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white);
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(color: Colors.black.withValues(alpha: AppColors.isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 4)),
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
  static ThemeData _build({required bool dark}) {
    final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final bg = dark ? _Dark.bg : _Light.bg;
    final bgElevated = dark ? _Dark.bgElevated : _Light.bgElevated;
    final surface = dark ? _Dark.surface : _Light.surface;
    final surfaceHigh = dark ? _Dark.surfaceHigh : _Light.surfaceHigh;
    final surfaceLine = dark ? _Dark.surfaceLine : _Light.surfaceLine;
    final textPrimary = dark ? _Dark.textPrimary : _Light.textPrimary;
    final textSecondary = dark ? _Dark.textSecondary : _Light.textSecondary;
    final textTertiary = dark ? _Dark.textTertiary : _Light.textTertiary;

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: AppColors.indigo,
        onPrimary: Colors.white,
        secondary: AppColors.violet,
        onSecondary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      dividerTheme: DividerThemeData(color: surfaceLine, thickness: 0.5, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: AppText.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: surfaceLine),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.indigoBright),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textTertiary),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: surfaceLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: surfaceLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.indigo,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
      ),
      cardTheme: CardThemeData(color: surface),
      canvasColor: bg,
      splashColor: AppColors.indigo.withValues(alpha: 0.08),
      highlightColor: AppColors.indigo.withValues(alpha: 0.04),
    );
  }

  static ThemeData get dark => _build(dark: true);
  static ThemeData get light => _build(dark: false);
}

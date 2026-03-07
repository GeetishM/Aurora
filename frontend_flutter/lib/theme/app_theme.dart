import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AURORA COLORS
// ─────────────────────────────────────────────────────────────────────────────

class AuroraColors {
  // ── Dark theme surfaces ───────────────────────────────────────────────────
  static const Color background     = Color(0xFF070B14); // original deep navy
  static const Color surface        = Color(0xFF0D1526);
  static const Color surfaceVariant = Color(0xFF131E32);
  static const Color divider        = Color(0xFF1C2A40);

  // ── Light theme surfaces ──────────────────────────────────────────────────
  // Soft white with a faint mint tint — like early morning aurora
  static const Color backgroundLight     = Color(0xFFF4FFFE); // near-white, hint of teal
  static const Color surfaceLight        = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE6FBF6); // soft mint card
  static const Color dividerLight        = Color(0xFFB8EBE0); // light teal divider

  // ── Sidebar (Light) — slightly deeper mint so it contrasts the main bg ───
  static const Color sidebarLight        = Color(0xFFEAFAF6);

  // ── Accents (shared) ──────────────────────────────────────────────────────
  static const Color teal         = Color(0xFF00E5C4); // original aurora teal
  static const Color tealDark     = Color(0xFF00B89E); // deeper teal for light mode
  static const Color purple       = Color(0xFF7C4DFF); // original aurora purple
  static const Color purpleDeep   = Color(0xFF5B30D6); // richer purple for light mode
  static const Color cyan         = Color(0xFF00B4D8);
  static const Color green        = Color(0xFF00F5A0);

  // ── Brand palette ─────────────────────────────────────────────────────────
  static const Color geckoGreen   = Color(0xFF8BFF3A); // kept for buttons/gradients
  static const Color easterGreen  = Color(0xFF7FFFD4);
  static const Color cosmicPurple = Color(0xFF7C3AED);
  static const Color techNavy     = Color(0xFF0F2B5B);

  // ── Dark text ─────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFE4EBF5);
  static const Color textSecondary = Color(0xFF8A9BB5);
  static const Color textHint      = Color(0xFF4A5C76);

  // ── Light text ────────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF0A1F1B); // deep teal-black
  static const Color textSecondaryLight = Color(0xFF3A6B60); // muted teal-grey
  static const Color textHintLight      = Color(0xFF7AADA3); // soft teal hint

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// User bubble — teal → purple (works on both themes)
  static const LinearGradient userBubble = LinearGradient(
    colors: [Color(0xFF00C9B1), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Aurora glow — teal → cyan → purple (original, for dark theme)
  static const LinearGradient auroraGlowDark = LinearGradient(
    colors: [Color(0xFF00E5C4), Color(0xFF00B4D8), Color(0xFF7C4DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Aurora glow light — deeper teal → purple (for light theme)
  static const LinearGradient auroraGlowLight = LinearGradient(
    colors: [Color(0xFF009E89), Color(0xFF0079A8), Color(0xFF5B30D6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Context-aware helpers ─────────────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      _isDark(context) ? background : backgroundLight;

  static Color surf(BuildContext context) =>
      _isDark(context) ? surface : surfaceLight;

  static Color surfVar(BuildContext context) =>
      _isDark(context) ? surfaceVariant : surfaceVariantLight;

  static Color div(BuildContext context) =>
      _isDark(context) ? divider : dividerLight;

  static Color sidebar(BuildContext context) =>
      _isDark(context) ? surface : sidebarLight;

  static Color txtPrimary(BuildContext context) =>
      _isDark(context) ? textPrimary : textPrimaryLight;

  static Color txtSecondary(BuildContext context) =>
      _isDark(context) ? textSecondary : textSecondaryLight;

  static Color txtHint(BuildContext context) =>
      _isDark(context) ? textHint : textHintLight;

  static Color accent(BuildContext context) =>
      _isDark(context) ? teal : tealDark;

  static LinearGradient auroraGlow(BuildContext context) =>
      _isDark(context) ? auroraGlowDark : auroraGlowLight;
}

// ─────────────────────────────────────────────────────────────────────────────
// APP THEME
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  // ── DARK ──────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuroraColors.background,

      colorScheme: const ColorScheme.dark(
        background:   AuroraColors.background,
        surface:      AuroraColors.surface,
        primary:      AuroraColors.teal,
        secondary:    AuroraColors.purple,
        tertiary:     AuroraColors.cyan,
        onBackground: AuroraColors.textPrimary,
        onSurface:    AuroraColors.textPrimary,
        onPrimary:    Color(0xFF070B14),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AuroraColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AuroraColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: AuroraColors.textSecondary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AuroraColors.surface,
        scrimColor: Color(0x99000000),
      ),

      dividerTheme: const DividerThemeData(
        color: AuroraColors.divider, thickness: 1, space: 1,
      ),

      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AuroraColors.textPrimary,   fontSize: 15, height: 1.55),
        bodyMedium:  TextStyle(color: AuroraColors.textPrimary,   fontSize: 14, height: 1.5),
        bodySmall:   TextStyle(color: AuroraColors.textSecondary, fontSize: 12),
        titleMedium: TextStyle(color: AuroraColors.textPrimary,   fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall:  TextStyle(color: AuroraColors.textSecondary, fontSize: 13),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuroraColors.surfaceVariant,
        hintStyle: const TextStyle(color: AuroraColors.textHint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AuroraColors.divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AuroraColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AuroraColors.teal, width: 1.5),
        ),
      ),

      iconTheme: const IconThemeData(color: AuroraColors.textSecondary),
    );
  }

  // ── LIGHT ─────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AuroraColors.backgroundLight,

      colorScheme: const ColorScheme.light(
        background:   AuroraColors.backgroundLight,
        surface:      AuroraColors.surfaceLight,
        primary:      AuroraColors.tealDark,
        secondary:    AuroraColors.purpleDeep,
        tertiary:     AuroraColors.teal,
        onBackground: AuroraColors.textPrimaryLight,
        onSurface:    AuroraColors.textPrimaryLight,
        onPrimary:    Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AuroraColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AuroraColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: AuroraColors.textSecondaryLight),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AuroraColors.sidebarLight,
        scrimColor: Color(0x33000000),
      ),

      dividerTheme: const DividerThemeData(
        color: AuroraColors.dividerLight, thickness: 1, space: 1,
      ),

      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AuroraColors.textPrimaryLight,   fontSize: 15, height: 1.55),
        bodyMedium:  TextStyle(color: AuroraColors.textPrimaryLight,   fontSize: 14, height: 1.5),
        bodySmall:   TextStyle(color: AuroraColors.textSecondaryLight, fontSize: 12),
        titleMedium: TextStyle(color: AuroraColors.textPrimaryLight,   fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall:  TextStyle(color: AuroraColors.textSecondaryLight, fontSize: 13),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuroraColors.surfaceVariantLight,
        hintStyle: const TextStyle(color: AuroraColors.textHintLight, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AuroraColors.dividerLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AuroraColors.dividerLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: AuroraColors.tealDark, width: 1.5),
        ),
      ),

      iconTheme: const IconThemeData(color: AuroraColors.textSecondaryLight),
    );
  }
}
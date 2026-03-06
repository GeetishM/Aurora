import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuroraColors {
  // ── Core Backgrounds (Dark) ───────────────────────────────────────────────
  static const Color background     = Color(0xFF070B14);
  static const Color surface        = Color(0xFF0D1526);
  static const Color surfaceVariant = Color(0xFF131E32);
  static const Color divider        = Color(0xFF1C2A40);

  // ── Core Backgrounds (Light) ──────────────────────────────────────────────
  static const Color backgroundLight     = Color(0xFFF0F4FF);
  static const Color surfaceLight        = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE8EEFF);
  static const Color dividerLight        = Color(0xFFD0D8F0);

  // ── Brand Palette ─────────────────────────────────────────────────────────
  /// Gecko Green — vivid electric lime
  static const Color geckoGreen   = Color(0xFF8BFF3A);

  /// Easter Green — soft pastel mint-green
  static const Color easterGreen  = Color(0xFF7FFFD4); // aquamarine-style

  /// Cosmic Purple — deep vibrant violet
  static const Color cosmicPurple = Color(0xFF7C3AED);

  /// Tech Navy Blue — rich dark navy with a tech feel
  static const Color techNavy     = Color(0xFF0F2B5B);

  // ── Legacy accents (kept for existing widgets) ────────────────────────────
  static const Color teal    = Color(0xFF00E5C4);
  static const Color purple  = Color(0xFF7C4DFF);
  static const Color cyan    = Color(0xFF00B4D8);
  static const Color green   = Color(0xFF00F5A0);

  // ── Text (Dark theme) ─────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFE4EBF5);
  static const Color textSecondary = Color(0xFF8A9BB5);
  static const Color textHint      = Color(0xFF4A5C76);

  // ── Text (Light theme) ────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF0A1628);
  static const Color textSecondaryLight = Color(0xFF3D5275);
  static const Color textHintLight      = Color(0xFF8A9BB5);

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// User bubble gradient — Gecko Green → Cosmic Purple
  static const LinearGradient userBubble = LinearGradient(
    colors: [geckoGreen, cosmicPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Aurora glow — Easter Green → teal → Cosmic Purple
  static const LinearGradient auroraGlow = LinearGradient(
    colors: [easterGreen, teal, cosmicPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Tech gradient — techNavy → Cosmic Purple (used in light theme accents)
  static const LinearGradient techGradient = LinearGradient(
    colors: [techNavy, cosmicPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  // ── DARK THEME ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuroraColors.background,

      colorScheme: const ColorScheme.dark(
        background:   AuroraColors.background,
        surface:      AuroraColors.surface,
        primary:      AuroraColors.geckoGreen,
        secondary:    AuroraColors.cosmicPurple,
        tertiary:     AuroraColors.easterGreen,
        onBackground: AuroraColors.textPrimary,
        onSurface:    AuroraColors.textPrimary,
        onPrimary:    AuroraColors.techNavy,
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
        color: AuroraColors.divider,
        thickness: 1,
        space: 1,
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
          borderSide: const BorderSide(color: AuroraColors.geckoGreen, width: 1.2),
        ),
      ),

      iconTheme: const IconThemeData(color: AuroraColors.textSecondary),
    );
  }

  // ── LIGHT THEME ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AuroraColors.backgroundLight,

      colorScheme: const ColorScheme.light(
        background:   AuroraColors.backgroundLight,
        surface:      AuroraColors.surfaceLight,
        primary:      AuroraColors.cosmicPurple,
        secondary:    AuroraColors.geckoGreen,
        tertiary:     AuroraColors.easterGreen,
        onBackground: AuroraColors.textPrimaryLight,
        onSurface:    AuroraColors.textPrimaryLight,
        onPrimary:    Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AuroraColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AuroraColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: AuroraColors.textSecondaryLight),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AuroraColors.surfaceLight,
        scrimColor: Color(0x44000000),
      ),

      dividerTheme: const DividerThemeData(
        color: AuroraColors.dividerLight,
        thickness: 1,
        space: 1,
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
          borderSide: const BorderSide(color: AuroraColors.cosmicPurple, width: 1.2),
        ),
      ),

      iconTheme: const IconThemeData(color: AuroraColors.textSecondaryLight),
    );
  }
}
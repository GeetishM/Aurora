import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuroraColors {
  // ── Backgrounds ──────────────────────────────────────
  static const Color background     = Color(0xFF070B14);
  static const Color surface        = Color(0xFF0D1526);
  static const Color surfaceVariant = Color(0xFF131E32);
  static const Color divider        = Color(0xFF1C2A40);

  // ── Aurora Accents ────────────────────────────────────
  static const Color teal           = Color(0xFF00E5C4);
  static const Color purple         = Color(0xFF7C4DFF);
  static const Color cyan           = Color(0xFF00B4D8);
  static const Color green          = Color(0xFF00F5A0);

  // ── Text ─────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFE4EBF5);
  static const Color textSecondary  = Color(0xFF8A9BB5);
  static const Color textHint       = Color(0xFF4A5C76);

  // ── Gradients ─────────────────────────────────────────
  static const LinearGradient userBubble = LinearGradient(
    colors: [Color(0xFF00C9B1), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ✅ Fixed: was 'aurораGlow' with a Cyrillic 'о' — now fully Latin
  static const LinearGradient auroraGlow = LinearGradient(
    colors: [Color(0xFF00E5C4), Color(0xFF00B4D8), Color(0xFF7C4DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuroraColors.background,

      colorScheme: const ColorScheme.dark(
        background: AuroraColors.background,
        surface:    AuroraColors.surface,
        primary:    AuroraColors.teal,
        secondary:  AuroraColors.purple,
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
          borderSide: const BorderSide(color: AuroraColors.teal, width: 1.2),
        ),
      ),

      iconTheme: const IconThemeData(color: AuroraColors.textSecondary),
    );
  }
}
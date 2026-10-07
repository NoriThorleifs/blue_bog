import 'package:flutter/material.dart';

/// Colours with a meaning on the map and in the HUD.
abstract final class Palette {
  static const space = Color(0xFF05070D);
  static const panel = Color(0xE6101622);
  static const gateway = Color(0xFF4DE1FF);
  static const deadGateway = Color(0xFFB3475A);
  static const sublight = Color(0xFFFFB547);
  static const hell = Color(0xFFFF4D3D);
  static const codeGreen = Color(0xFF5CFF8A);
  static const news = Color(0xFF9FB7FF);
  static const muted = Color(0xFF8A93A6);
}

final ThemeData appTheme = () {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.gateway,
    brightness: Brightness.dark,
    surface: const Color(0xFF0B101A),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.space,
    textTheme: Typography.whiteMountainView.copyWith(
      displaySmall: const TextStyle(
        fontWeight: FontWeight.w300,
        letterSpacing: 10,
      ),
      titleLarge: const TextStyle(letterSpacing: 1.5),
      bodyMedium: const TextStyle(height: 1.45),
    ),
    cardTheme: CardThemeData(
      color: Palette.panel,
      elevation: 12,
      shadowColor: Palette.gateway.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Palette.gateway.withValues(alpha: 0.25)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}();

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const seedColor = Colors.cyanAccent;

final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ),
  textTheme: _textTheme,
);

final ThemeData darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ),
  textTheme: _textTheme,
);

final TextTheme _textTheme = TextTheme(
  displayLarge: GoogleFonts.orbitron(fontSize: 57, fontWeight: FontWeight.bold),
  titleLarge: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.w500),
  bodyMedium: GoogleFonts.orbitron(fontSize: 14),
);

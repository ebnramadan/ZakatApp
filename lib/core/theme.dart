import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: kPrimaryGreen,
      brightness: Brightness.light,
      primary: kPrimaryGreen,
      secondary: kGold,
      surface: kSurface,
    );
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
              bodyLarge: TextStyle(fontSize: 16, height: 1.6),
              bodyMedium: TextStyle(fontSize: 15, height: 1.55),
              bodySmall: TextStyle(fontSize: 13, height: 1.5),
              titleMedium: TextStyle(fontSize: 17),
              titleLarge: TextStyle(fontSize: 22),
              headlineMedium: TextStyle(fontSize: 28))
          .apply(
              bodyColor: const Color(0xFF20352D),
              displayColor: const Color(0xFF163D2A)),
      colorScheme: base,
      scaffoldBackgroundColor: kSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kGold,
        foregroundColor: Colors.black87,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryGreen,
          side: const BorderSide(color: kPrimaryGreen),
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimaryGreen, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: kPrimaryGreen.withOpacity(0.15),
        side: const BorderSide(color: kPrimaryGreen),
        labelStyle: const TextStyle(color: kPrimaryGreen, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: kPrimaryGreen,
        unselectedItemColor: Colors.grey,
        elevation: 8,
      ),
    );
  }
}

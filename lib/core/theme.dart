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
      fontFamily: 'Inter',
      fontFamilyFallback: const ['NotoSansArabic'],
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
              bodyLarge: TextStyle(fontSize: 16, height: 1.6),
              bodyMedium: TextStyle(fontSize: 16, height: 1.5),
              bodySmall: TextStyle(fontSize: 13, height: 1.5),
              titleMedium: TextStyle(fontSize: 17),
              titleLarge: TextStyle(fontSize: 22),
              headlineMedium: TextStyle(fontSize: 28))
          .apply(
              bodyColor: const Color(0xFF172C27),
              displayColor: const Color(0xFF172C27)),
      colorScheme: base,
      scaffoldBackgroundColor: kSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: kSurface,
        foregroundColor: Color(0xFF172C27),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF172C27),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      navigationBarTheme: NavigationBarThemeData(
          height: 80,
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: const Color(0xFFDDEEE6),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? kPrimaryGreen
                  : const Color(0xFF52655F)))),
      navigationRailTheme: const NavigationRailThemeData(
          indicatorColor: Color(0xFFDDEEE6),
          selectedIconTheme: IconThemeData(color: kPrimaryGreen),
          selectedLabelTextStyle:
              TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w700),
          unselectedLabelTextStyle: TextStyle(color: Color(0xFF52655F))),
      dividerTheme: const DividerThemeData(
          color: Color(0xFFDDE5E1), thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF172C27),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryGreen,
          side: const BorderSide(color: kPrimaryGreen),
          minimumSize: const Size(0, 52),
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
          borderSide: const BorderSide(color: Color(0xFF869B91)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF869B91)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFDDE5E1))),
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

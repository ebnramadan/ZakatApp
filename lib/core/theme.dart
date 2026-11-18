import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData get light => forLanguage('en');

  static final Map<String, ThemeData> _themes = {};
  static ThemeData forLanguage(String language) => _themes.putIfAbsent(
      language == 'ar' ? 'ar' : 'en', () => _build(language == 'ar'));

  static ThemeData _build(bool arabic) {
    final family = arabic ? 'Tajawal' : 'Inter';
    final fallback = [arabic ? 'Inter' : 'Tajawal'];
    final base = ColorScheme.fromSeed(
      seedColor: kPrimaryGreen,
      brightness: Brightness.light,
      primary: kPrimaryGreen,
      secondary: kGold,
      surface: kSurface,
    );
    return ThemeData(
      useMaterial3: true,
      // Web canvas route compositing can leave a black frame on iOS PWA back navigation.
      // Keep browser navigation immediate while retaining native platform transitions.
      pageTransitionsTheme: kIsWeb
          ? const PageTransitionsTheme(builders: {
              TargetPlatform.android: _BrowserPageTransition(),
              TargetPlatform.iOS: _BrowserPageTransition(),
              TargetPlatform.macOS: _BrowserPageTransition(),
              TargetPlatform.windows: _BrowserPageTransition(),
              TargetPlatform.linux: _BrowserPageTransition(),
              TargetPlatform.fuchsia: _BrowserPageTransition(),
            })
          : const PageTransitionsTheme(),
      fontFamily: family,
      fontFamilyFallback: fallback,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
              bodyLarge: const TextStyle(fontSize: 16, height: 1.4),
              bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
              bodySmall: const TextStyle(fontSize: 12, height: 1.35),
              titleMedium: const TextStyle(
                  fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
              titleLarge: const TextStyle(
                  fontSize: 18, height: 1.4, fontWeight: FontWeight.w700),
              headlineMedium: TextStyle(
                  fontSize: 25,
                  height: arabic ? 1.4 : 1.18,
                  fontWeight: FontWeight.w700))
          .apply(
              bodyColor: const Color(0xFF172C27),
              displayColor: const Color(0xFF172C27)),
      colorScheme: base,
      scaffoldBackgroundColor: kSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: kSurface,
        foregroundColor: const Color(0xFF172C27),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallback,
          height: 1.4,
          color: const Color(0xFF172C27),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: TextStyle(
                  fontFamily: family,
                  fontFamilyFallback: fallback,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600))),
      navigationBarTheme: NavigationBarThemeData(
          height: 64,
          backgroundColor: const Color(0xFFFFFCF7),
          elevation: 0,
          indicatorColor: const Color(0xFFDDEEE6),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: family,
              fontFamilyFallback: fallback,
              height: 1.4,
              fontSize: 10,
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
      listTileTheme: ListTileThemeData(
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            height: 1.4,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF172C27)),
        subtitleTextStyle: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontSize: 12,
            height: 1.35,
            color: const Color(0xFF63716B)),
        iconColor: const Color(0xFF52655F),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
          showDragHandle: true, backgroundColor: Color(0xFFFFFCF7)),
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
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
              fontFamily: family,
              fontFamilyFallback: fallback,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryGreen,
          side: const BorderSide(color: kPrimaryGreen),
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
              fontFamily: family,
              fontFamilyFallback: fallback,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFCF7),
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
        color: const Color(0xFFFFFCF7),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDDE5E1))),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFFCF7),
        selectedColor: kPrimaryGreen.withOpacity(0.15),
        side: const BorderSide(color: kPrimaryGreen),
        labelStyle: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            color: kPrimaryGreen,
            fontSize: 13,
            height: 1.5),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFCF7),
        selectedItemColor: kPrimaryGreen,
        unselectedItemColor: Colors.grey,
        elevation: 8,
      ),
    );
  }
}

class _BrowserPageTransition extends PageTransitionsBuilder {
  const _BrowserPageTransition();
  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      child;
}

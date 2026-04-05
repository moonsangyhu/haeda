import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Color Palette ──
  static const Color primary = Color(0xFFF48FB1);
  static const Color primaryDark = Color(0xFFEC407A);
  static const Color accent = Color(0xFFCE93D8);
  static const Color background = Color(0xFFFFF0F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF5D4037);
  static const Color textSecondary = Color(0xFF8D6E63);
  static const Color outline = Color(0xFFE0BFC7);
  static const Color error = Color(0xFFE57373);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFFCE4EC),
          onPrimaryContainer: Color(0xFF5D4037),
          secondary: accent,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFF3E5F5),
          onSecondaryContainer: Color(0xFF5D4037),
          tertiary: Color(0xFFFFCC80),
          onTertiary: Color(0xFF5D4037),
          tertiaryContainer: Color(0xFFFFF3E0),
          onTertiaryContainer: Color(0xFF5D4037),
          error: error,
          onError: Colors.white,
          errorContainer: Color(0xFFFFCDD2),
          onErrorContainer: Color(0xFF5D4037),
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          surfaceContainerHighest: Color(0xFFFCE4EC),
          outline: outline,
          outlineVariant: Color(0xFFF8E0E6),
          shadow: Color(0x14F48FB1),
        ),
        scaffoldBackgroundColor: background,

        // ── AppBar ──
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),

        // ── Cards ──
        cardTheme: CardThemeData(
          color: surface,
          elevation: 2,
          shadowColor: const Color(0x1AF48FB1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),

        // ── Filled Button ──
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Elevated Button ──
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            elevation: 2,
            shadowColor: const Color(0x1AF48FB1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Outlined Button ──
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Text Button ──
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Navigation Bar ──
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: const Color(0x4DF48FB1),
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          shadowColor: const Color(0x14F48FB1),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryDark,
              );
            }
            return const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            );
          }),
        ),

        // ── Chip ──
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFFCE4EC),
          labelStyle: const TextStyle(
            fontFamily: 'Pretendard',
            color: textPrimary,
            fontSize: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide.none,
        ),

        // ── Input Decoration ──
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: error, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        // ── Dialog ──
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: surface,
        ),

        // ── SnackBar ──
        snackBarTheme: SnackBarThemeData(
          backgroundColor: textPrimary,
          contentTextStyle: const TextStyle(
            fontFamily: 'Pretendard',
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF176B4D);
  static const Color primaryDark = Color(0xFF0E4D37);

  /// A near-black green for the app's richest surfaces, such as the
  /// card at the top of the dashboard.
  static const Color ink = Color(0xFF0A241C);

  /// A muted brass, used sparingly to pick out one thing on a dark
  /// surface. Never as a background for a whole card.
  static const Color accent = Color(0xFFCDAA63);
  static const Color secondary = accent;

  /// The same brass, darker, for an icon or a thin line on a light
  /// surface.
  static const Color accentDeep = Color(0xFFA5803A);

  static const Color background = Color(0xFFF3F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEEF3EF);

  /// The fill of the app's hero cards.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, Color(0xFF12503B)],
  );

  /// The soft shadow under a hero card.
  static const List<BoxShadow> heroShadow = [
    BoxShadow(color: Color(0x380A241C), blurRadius: 28, offset: Offset(0, 14)),
  ];

  static const Color textPrimary = Color(0xFF111C17);
  static const Color textSecondary = Color(0xFF66716B);

  static const Color success = Color(0xFF218653);
  static const Color warning = Color(0xFFE08A17);
  static const Color danger = Color(0xFFD64545);

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFD8F2E5),
          onPrimaryContainer: primaryDark,
          secondary: secondary,
          surface: surface,
          error: danger,
          onError: Colors.white,
        );

    // Cards sit on a soft shadow, without an outline.
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD8E0DB)),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontFamily: 'Manrope',
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.45),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x260A241C),
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: Color(0xFF98A19C)),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB7C4BC),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: Color(0xFFB8C9BF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: primary,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5EAE7),
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontFamily: 'Manrope',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontFamily: 'Manrope',
          fontSize: 15,
          height: 1.45,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Color(0xFFD8F2E5),
        elevation: 0,
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand / Accent ──────────────────────────────────────────────────────
  static const Color primaryColor    = Color(0xFF6366F1); // Indigo 500
  static const Color primaryLight    = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark     = Color(0xFF4338CA); // Indigo 700
  static const Color accentColor     = Color(0xFF0EA5E9); // Sky 500
  static const Color successColor    = Color(0xFF10B981); // Emerald 500
  static const Color dangerColor     = Color(0xFFF43F5E); // Rose 500
  static const Color warningColor    = Color(0xFFF59E0B); // Amber 500
  static const Color infoColor       = Color(0xFF06B6D4); // Cyan 500

  // ── Dark palette (matches the screenshot exactly) ────────────────────────
  /// Page background – same deep navy as the area behind the sidebar
  static const Color backgroundDark  = Color(0xFF0D1117);
  /// Card / panel surface – slightly lighter than background
  static const Color surfaceDark     = Color(0xFF161B22);
  /// Sidebar background
  static const Color sidebarColor    = Color(0xFF0F172A);
  /// Selected nav-item background
  static const Color sidebarItemColor = Color(0xFF1E293B);
  /// Input field fill
  static const Color inputFillDark   = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9); // Slate 100
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  /// Subtle border colour
  static const Color borderDark      = Color(0xFF1E293B);

  // ── Light palette (kept for reference / future toggle) ───────────────────
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor    = Colors.white;
  static const Color textPrimary     = Color(0xFF0F172A);
  static const Color textSecondary   = Color(0xFF64748B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: dangerColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 12,
        shadowColor: primaryColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: primaryColor.withValues(alpha: 0.5),
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9), // Slate 100
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dangerColor, width: 1.5),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: textPrimary,
          fontSize: 14,
        ),
        dataTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 12,
        focusElevation: 16,
        hoverElevation: 16,
        highlightElevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall:  TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary),
        headlineMedium:TextStyle(color: textPrimary),
        headlineSmall: TextStyle(color: textPrimary),
        titleLarge:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium:   TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall:    TextStyle(color: textSecondary),
        bodyLarge:     TextStyle(color: textPrimary),
        bodyMedium:    TextStyle(color: textPrimary),
        bodySmall:     TextStyle(color: textSecondary),
        labelLarge:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        labelMedium:   TextStyle(color: textSecondary),
        labelSmall:    TextStyle(color: textSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryDark,
        onPrimaryContainer: primaryLight,
        secondary: accentColor,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF0C4A6E),
        onSecondaryContainer: Color(0xFFBAE6FD),
        error: dangerColor,
        onError: Colors.white,
        errorContainer: Color(0xFF4C0519),
        onErrorContainer: Color(0xFFFDA4AF),
        surface: surfaceDark,
        onSurface: textPrimaryDark,
        onSurfaceVariant: textSecondaryDark,
        outline: borderDark,
        outlineVariant: Color(0xFF0F172A),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFFF1F5F9),
        onInverseSurface: Color(0xFF0F172A),
        inversePrimary: primaryDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderDark, width: 1),
        ),
        color: surfaceDark,
        surfaceTintColor: surfaceDark,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(120, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(120, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: borderDark, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillDark,
        hintStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondaryDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerColor, width: 2),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: textSecondaryDark,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        dataTextStyle: const TextStyle(
          color: textPrimaryDark,
          fontSize: 14,
        ),
        headingRowColor: WidgetStatePropertyAll(Color(0xFF0F172A)),
        dataRowColor: WidgetStatePropertyAll(Colors.transparent),
        dividerThickness: 1,
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderDark),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFillDark,
        side: const BorderSide(color: borderDark),
        labelStyle: const TextStyle(color: textPrimaryDark, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceDark,
        contentTextStyle: const TextStyle(color: textPrimaryDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDark),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle:
            const TextStyle(color: textSecondaryDark, fontSize: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDark),
        ),
        textStyle: const TextStyle(color: textPrimaryDark, fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondaryDark,
        textColor: textPrimaryDark,
      ),
      iconTheme: const IconThemeData(color: textSecondaryDark),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(color: textPrimaryDark),
        displayMedium: TextStyle(color: textPrimaryDark),
        displaySmall:  TextStyle(color: textPrimaryDark),
        headlineLarge: TextStyle(color: textPrimaryDark),
        headlineMedium:TextStyle(color: textPrimaryDark),
        headlineSmall: TextStyle(color: textPrimaryDark),
        titleLarge:    TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        titleMedium:   TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w500),
        titleSmall:    TextStyle(color: textSecondaryDark),
        bodyLarge:     TextStyle(color: textPrimaryDark),
        bodyMedium:    TextStyle(color: textPrimaryDark),
        bodySmall:     TextStyle(color: textSecondaryDark),
        labelLarge:    TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600),
        labelMedium:   TextStyle(color: textSecondaryDark),
        labelSmall:    TextStyle(color: textSecondaryDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryDark,
        selectedLabelStyle: TextStyle(
          color: primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          color: textSecondaryDark,
          fontSize: 11,
        ),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: sidebarColor,
        scrimColor: Colors.black54,
      ),
    );
  }
}

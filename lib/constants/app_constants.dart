import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConstants {
  // Modern Professional Palette (Blue/Emerald)
  // Light theme
  static const Color primaryColor = Color(0xFF10B981); // Blue 600
  static const Color secondaryColor = Color(0xFF60A5FA); // Blue 400
  static const Color accentColor = Color(0xFF10B981); // Emerald 500
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceColor = Color(0xFFFFFFFF); // White
  static const Color errorColor = Color(0xFFEF4444); // Red 500
  static const Color successColor = Color(0xFF16A34A); // Green 600
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color textPrimaryColor = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryColor = Color(0xFF475569); // Slate 600
  static const Color partialDeliveryColor = Color.fromARGB(255, 65, 66, 59);
  static const Color Completed = Colors.greenAccent;
  static const Color PendingDisp = Color.fromARGB(255, 130, 102, 151);
  static const Color darkBackgroundColor = Color(0xFF0B1220); // Deep navy
  static const Color darkSurfaceColor = Color(0xFF111827); // Gray 900
  static const Color darkTextPrimaryColor = Color(0xFFF3F4F6); // Gray 100
  static const Color darkTextSecondaryColor = Color(0xFF9CA3AF); // Gray 400
  static const Color deliveredColor = Color(
    0xFF388E3C,
  ); // Green shade for delivered
  static const Color commonColor = Color(
    0xFF607D8B,
  ); // Blue Grey for common use

  // App Version
  static const String appVersion = '1.0.1+2';

  // API Configuration
  static const String baseUrl = 'https://soloshine-backend-l3rf.onrender.com';
  static const String loginEndpoint = '/auth/login';
  static const String loginUrl = '$baseUrl$loginEndpoint';
  // Web push (FCM) VAPID public key
  static const String webVapidKey =
      'BCgdsTYFX0WQ02XxVKAcIexvvy-HyJeqbVIqRETb1ZWGqOQjXp_LVYk1e698JREZI9ddrO0ZNArgTSDsXDi4dKs';

  // Additional API endpoints for future use
  static const String usersEndpoint = '/user';
  static const String ordersEndpoint = '/order';
  static const String profileEndpoint = '/profile';
  static const String categoriesEndpoint = '/category';
  static const String dashboardEndpoint = '/dashboard';
  static const String dashboardGraphEndpoint = '/dashboard/graph';
  static const String storageStatsEndpoint = '/dashboard/storage';
  static const String storageCleanupEndpoint = '/order/cleanup/completed';

  // Text Styles
  static TextStyle get headingLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static TextStyle get headingMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static TextStyle get headingSmall => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimaryColor,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondaryColor,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondaryColor,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  // Alias for backward compatibility
  static Color get textSecondary => textSecondaryColor;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];

  // ThemeData (Light)
  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      error: errorColor,
      onError: Colors.white,
      background: backgroundColor,
      onBackground: textPrimaryColor,
      surface: surfaceColor,
      onSurface: textPrimaryColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    useMaterial3: true,
    fontFamily: 'Inter',
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: textPrimaryColor,
      displayColor: textPrimaryColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: surfaceColor,
  );

  // ThemeData (Dark)
  static ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      error: errorColor,
      onError: Colors.white,
      background: darkBackgroundColor,
      onBackground: darkTextPrimaryColor,
      surface: darkSurfaceColor,
      onSurface: darkTextPrimaryColor,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    useMaterial3: true,
    fontFamily: 'Inter',
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: darkTextPrimaryColor,
      displayColor: darkTextPrimaryColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: darkSurfaceColor,
  );
}

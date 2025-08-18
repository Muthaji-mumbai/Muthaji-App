import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConstants {
  // App Colors - Light Green & White theme
  // Soft, fresh, and airy palette.
  static const Color primaryColor = Color(0xFF8BC34A); // Light green
  static const Color secondaryColor = Color(0xFFC5E1A5); // Pale green
  static const Color accentColor = Color(0xFFAED581); // Mid light green
  static const Color backgroundColor = Color(0xFFFFFFFF); // White
  static const Color surfaceColor = Color(0xFFF4FAF1); // Very light green tint
  static const Color errorColor = Color(0xFFE53935); // Red
  static const Color successColor = Color(0xFF43A047); // Green (readable)
  static const Color warningColor = Color(0xFFFFA000); // Amber
  static const Color textPrimaryColor = Color(0xFF2E7D32); // Dark green for contrast
  static const Color textSecondaryColor = Color(0xFF6D6D6D); // Muted gray

  // API Configuration
  static const String baseUrl = 'https://soloshine-backend.onrender.com';
  static const String loginEndpoint = '/auth/login';
  static const String loginUrl = '$baseUrl$loginEndpoint';

  // Additional API endpoints for future use
  static const String usersEndpoint = '/user';
  static const String ordersEndpoint = '/order';
  static const String profileEndpoint = '/profile';

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
}

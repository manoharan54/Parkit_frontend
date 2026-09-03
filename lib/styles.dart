import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized app colors for consistency.
class AppColors {
  // Primary palette
  static const Color background = Color(0xFFF5F7F6);
  static const Color primary = Color(0xFF1E7767);
  static const Color onPrimary = Colors.white;
  static const Color ink = Color(0xFF13252C);
  static const Color accent = Color(0xFF9DD9C6);
  static const Color cardBackground = Color(0xFF13252C);
  
  // Secondary palette
  static const Color secondaryText = Color(0xFF667671);
  static const Color borderLight = Color(0xFFE2E9E5);
  static const Color indicatorBg = Color(0xFFD9F1E7);
  static const Color darkGreen = Color(0xFF344740);
  
  // Surface & divider
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);
  
  // Status colors
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFEF5350);
}

/// Global spacing values to maintain consistent visual rhythm.
class AppSpacing {
  // Horizontal
  static const double horizontal = 24.0;
  static const double horizontalSmall = 12.0;
  
  // Vertical
  static const double vertical = 16.0;
  static const double verticalSmall = 8.0;
  
  // Consistent increments
  static const double extraSmall = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 20.0;
  static const double extraLarge = 28.0;
  static const double xxLarge = 32.0;
  
  // Corner radius
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  
  // Button dimensions
  static const double buttonHeight = 54.0;
  static const double iconButtonSize = 48.0;
}

/// Typography definitions following the design specification.
class AppText {
  // Font families – Product Sans preferred, Aptos fallback, Roboto last.
  static const String primaryFont = 'Aptos';
  static const List<String> fallbackFonts = ['Roboto'];

  // ============ Heading Styles ============
  
  // Screen/Page title – primary heading, bold, large, highly legible.
  static final TextStyle screenTitle = GoogleFonts.roboto(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.ink,
  );

  // Large welcome heading – for login/signup screens
  static final TextStyle welcTitle = GoogleFonts.roboto(
    fontSize: 31,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  // Section title – semi‑bold, medium size.
  static final TextStyle sectionTitle = GoogleFonts.roboto(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  // Subsection/card title – bold, medium size
  static final TextStyle cardTitle = GoogleFonts.roboto(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  // ============ Body Styles ============
  
  // Body text – medium weight, standard size.
  static final TextStyle body = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  // Subtitle/helper text – secondary color
  static final TextStyle subtitle = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
  );

  // Caption/small text – for descriptions, helper text
  static final TextStyle caption = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
  );

  // ============ Interactive Styles ============
  
  // Button text – semi‑bold, readable.
  static final TextStyle button = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Form field label – bold, small
  static final TextStyle formLabel = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  // Labels – medium weight, standard size.
  static final TextStyle label = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.darkGreen,
  );

  // ============ Specialized Styles ============
  
  // Parking slot numbers – bold, extra large.
  static final TextStyle slotNumber = GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // Countdown timer – extra bold for maximum readability.
  static final TextStyle countdown = GoogleFonts.roboto(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  // Metric value – large, bold, white on dark background
  static final TextStyle metricValue = GoogleFonts.roboto(
    fontSize: 25,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  // Metric label – small, secondary
  static final TextStyle metricLabel = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.white60,
  );

  // Uppercase label – all caps, tight letter spacing
  static final TextStyle uppercaseLabel = GoogleFonts.roboto(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    letterSpacing: 1.3,
  );
}

/// Reusable primary button matching the design.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.onPressed, required this.label, this.isLoading = false, super.key});
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: AppText.button),
      ),
    );
  }
}

/// Reusable outlined icon button used on the QR scanner screen.
class OutlinedIconButton extends StatelessWidget {
  const OutlinedIconButton({required this.icon, required this.label, this.onPressed, super.key});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: AppText.body),
      ),
    );
  }
}

/// Responsive design helpers for tablet and web layouts.
class AppResponsive {
  // Breakpoints (in logical pixels)
  static const double mobileBreakpoint = 480;
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1024;

  /// Checks if the device is in mobile/phone size.
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  /// Checks if the device is in tablet size.
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  /// Checks if the device is in desktop size.
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Gets the maximum width for content based on device size.
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isDesktop(context)) {
      return 1200;
    } else if (isTablet(context)) {
      return 700;
    }
    return width - (AppSpacing.horizontal * 2);
  }

  /// Gets adaptive horizontal padding based on device size.
  static double getHorizontalPadding(BuildContext context) {
    if (isDesktop(context)) return AppSpacing.xxLarge;
    if (isTablet(context)) return AppSpacing.large;
    return AppSpacing.horizontal;
  }

  /// Gets adaptive font size based on device size.
  static double adaptivefontSize(double baseFontSize, BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    return baseFontSize * textScaler.scale(1.0);
  }

  /// Creates a responsive grid layout helper.
  static int getGridCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }

  /// Gets adaptive spacing based on device size.
  static double getAdaptiveSpacing(
    BuildContext context, {
    double mobile = 12.0,
    double tablet = 16.0,
    double desktop = 20.0,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }
}

import 'package:flutter/material.dart';

/// ICARE Layout & Spacing Constants
/// Enforces Responsive Breakpoints and Institutional Rhythm
class IcareSpacing {
  IcareSpacing._();

  // Spacing Scale
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Border Radii
  static const double radiusPill = 999.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;

  static final BorderRadius roundedSm = BorderRadius.circular(radiusSm);
  static final BorderRadius roundedMd = BorderRadius.circular(radiusMd);
  static final BorderRadius roundedLg = BorderRadius.circular(radiusLg);
  static final BorderRadius roundedPill = BorderRadius.circular(radiusPill);

  // Responsive Breakpoints
  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 900.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointMobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointMobile && width < breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointTablet;

  // Responsive Insets
  static EdgeInsets screenPadding(BuildContext context) {
    final mobile = isMobile(context);
    return EdgeInsets.symmetric(
      horizontal: mobile ? 12.0 : 20.0,
      vertical: mobile ? 12.0 : 18.0,
    );
  }

  static EdgeInsets cardPadding(BuildContext context) {
    final mobile = isMobile(context);
    return EdgeInsets.all(mobile ? 12.0 : 16.0);
  }
}

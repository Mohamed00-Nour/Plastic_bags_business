import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

enum ScreenType { mobile, tablet, desktop }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < AppConstants.mobileBreakpoint) return ScreenType.mobile;
    if (width < AppConstants.desktopBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  static bool isMobile(BuildContext context) =>
      getScreenType(context) == ScreenType.mobile;

  static bool isTablet(BuildContext context) =>
      getScreenType(context) == ScreenType.tablet;

  static bool isDesktop(BuildContext context) =>
      getScreenType(context) == ScreenType.desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return desktop;
        }
        if (constraints.maxWidth >= AppConstants.mobileBreakpoint) {
          return tablet ?? desktop;
        }
        return mobile;
      },
    );
  }
}

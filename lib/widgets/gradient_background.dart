import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable gradient background widget for game pages
/// Provides a consistent radial gradient background across all game pages
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  /// The standard game page gradient for light theme
  static const RadialGradient lightGameGradient = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.5,
    colors: [
      Color(0xFFE2E8F0),
      Color(0xFFF8FAFC),
      Color(0xFFDBEAFE),
      Color(0xFFFCE7F3),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// The standard game page gradient for dark theme
  static const RadialGradient darkGameGradient = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.5,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
      Color(0xFF1E293B),
      Color(0xFF334155),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// The background color used with the gradient (light theme)
  static const Color lightBackgroundColor = Color(0xFFF8FAFC);

  /// The background color used with the gradient (dark theme)
  static const Color darkBackgroundColor = Color(0xFF0F172A);

  /// Get background color based on theme
  static Color getBackgroundColor(BuildContext context) {
    return AppTheme.backgroundColor(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? darkGameGradient : lightGameGradient,
      ),
      child: child,
    );
  }
}

/// A Scaffold wrapper with gradient background
/// Use this for pages that need the gradient background
class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor ?? GradientBackground.getBackgroundColor(context),
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: GradientBackground(child: body),
    );
  }
}

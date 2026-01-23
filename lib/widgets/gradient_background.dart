import 'package:flutter/material.dart';

/// Reusable gradient background widget for game pages
/// Provides a consistent radial gradient background across all game pages
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  /// The standard game page gradient
  static const RadialGradient gameGradient = RadialGradient(
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

  /// The background color used with the gradient
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: gameGradient,
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
      backgroundColor: backgroundColor ?? GradientBackground.backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: GradientBackground(
        child: body,
      ),
    );
  }
}

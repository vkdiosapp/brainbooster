import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// Reusable animated gradient background widget for the entire app
/// This widget manages its own animation controller and can be used
/// as a base background for any page. Changes here will affect the whole app.
class AnimatedGradientBackground extends StatefulWidget {
  /// Optional child widget to display on top of the gradient
  final Widget? child;

  const AnimatedGradientBackground({super.key, this.child});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize gradient animation controller (15s like HTML)
    // Use repeat(reverse: true) with easeInOut to match HTML's "ease-in-out infinite alternate"
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    // Create curved animation matching HTML's ease-in-out
    _gradientAnimation = CurvedAnimation(
      parent: _gradientController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection
          .ltr, // Explicit text direction to avoid Directionality error
      child: Stack(
        children: [
          // Animated mesh gradient background (matching HTML)
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _gradientAnimation,
                builder: (context, child) {
                  // Match HTML exactly: backgroundPosition animates from 0% 50% to 100% 50%
                  // HTML uses background-size: 400% 400% with ease-in-out infinite alternate
                  // The CurvedAnimation with easeInOut + reverse ensures smooth transitions
                  final offset =
                      _gradientAnimation.value; // 0.0 to 1.0 and back smoothly

                  // HTML animates backgroundPosition horizontally from 0% to 100%
                  // With 400% background-size, we simulate this by panning the gradient
                  // The easeInOut curve ensures smooth acceleration/deceleration at endpoints
                  // This prevents any visible jump when the animation reverses
                  final beginX =
                      -2.0 + (offset * 4.0); // Smooth pan from -2 to 2
                  final beginY = -1.0; // Keep vertical at center (50% in HTML)
                  final endX = 2.0 - (offset * 4.0);
                  final endY = 1.0;

                  return IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          // Create larger gradient area (4x) and animate position
                          begin: Alignment(beginX, beginY),
                          end: Alignment(endX, endY),
                          colors: const [
                            Color(0xFFF093FB), // #f093fb - Light pink
                            Color(0xFFF5576C), // #f5576C - Pink
                            Color(0xFF4FACFE), // #4facfe - Light blue
                            Color(0xFF00F2FE), // #00f2fe - Cyan
                            Color(0xFFA8EDEA), // #a8edea - Light teal
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                          transform: GradientRotation(
                            math.pi / 4,
                          ), // 45deg like HTML
                          tileMode: TileMode.clamp,
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                        child: Container(
                          color: Colors.white.withOpacity(
                            0.4,
                          ), // Match HTML opacity 0.4
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Child content on top of gradient
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

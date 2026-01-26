import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A reusable game container widget with consistent styling
/// that matches the game mode card design.
class GameContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool useBackdropFilter;

  const GameContainer({
    super.key,
    required this.child,
    this.onTap,
    this.useBackdropFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: useBackdropFilter
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: child,
            )
          : child,
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

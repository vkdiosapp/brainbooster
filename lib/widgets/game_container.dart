import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    final isDark = AppTheme.isDark(context);
    const accentColor = Color(0xFF8B5CF6); // id 22 tile accent
    const lightBackgroundColor = Color(0xFFEDE9FE); // id 22 tile bg
    final backgroundColor = isDark
        ? Color.alphaBlend(
            accentColor.withOpacity(0.12),
            AppTheme.cardColor(context),
          )
        : lightBackgroundColor;
    final borderColor = isDark
        ? AppTheme.borderColor(context)
        : Colors.white.withOpacity(0.5);
    final shadowColor = AppTheme.shadowColor(opacity: isDark ? 0.3 : 0.05);

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: child,
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
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

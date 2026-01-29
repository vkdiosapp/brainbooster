import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DifficultySelector extends StatelessWidget {
  final bool isAdvanced;
  final ValueChanged<bool> onChanged;
  final EdgeInsetsGeometry? outerPadding;
  final EdgeInsetsGeometry contentPadding;
  final bool useBackdropFilter;
  final bool showContainer;
  final double borderRadius;
  final String normalLabel;
  final String advancedLabel;
  final double gap;

  const DifficultySelector({
    super.key,
    required this.isAdvanced,
    required this.onChanged,
    this.outerPadding,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    this.useBackdropFilter = true,
    this.showContainer = true,
    this.borderRadius = 16,
    this.normalLabel = 'Normal',
    this.advancedLabel = 'Advanced',
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final containerColor =
        AppTheme.cardColor(context).withOpacity(isDark ? 0.6 : 0.7);
    final borderColor =
        AppTheme.borderColor(context).withOpacity(isDark ? 0.6 : 0.4);
    final shadowColor = AppTheme.shadowColor(opacity: isDark ? 0.25 : 0.05);
    final selectedBackground = AppTheme.textPrimary(context);
    final selectedTextColor = AppTheme.cardColor(context);
    final unselectedBackground =
        AppTheme.cardColor(context).withOpacity(isDark ? 0.75 : 1);
    final unselectedTextColor = AppTheme.textSecondary(context);

    final optionsRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOption(
          context,
          label: normalLabel,
          selected: !isAdvanced,
          backgroundColor: selectedBackground,
          selectedTextColor: selectedTextColor,
          unselectedBackground: unselectedBackground,
          unselectedTextColor: unselectedTextColor,
          borderColor: borderColor,
          onTap: () => onChanged(false),
        ),
        SizedBox(width: gap),
        _buildOption(
          context,
          label: advancedLabel,
          selected: isAdvanced,
          backgroundColor: selectedBackground,
          selectedTextColor: selectedTextColor,
          unselectedBackground: unselectedBackground,
          unselectedTextColor: unselectedTextColor,
          borderColor: borderColor,
          onTap: () => onChanged(true),
        ),
      ],
    );

    if (!showContainer) {
      if (outerPadding == null) {
        return optionsRow;
      }
      return Padding(
        padding: outerPadding!,
        child: optionsRow,
      );
    }

    final inner = Container(
      padding: contentPadding,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: optionsRow,
    );

    final child = useBackdropFilter
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: inner,
            ),
          )
        : inner;

    final decorated = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (outerPadding == null) {
      return decorated;
    }

    return Padding(
      padding: outerPadding!,
      child: decorated,
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color backgroundColor,
    required Color selectedTextColor,
    required Color unselectedBackground,
    required Color unselectedTextColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    final shadowColor = AppTheme.shadowColor(opacity: isDark ? 0.2 : 0.05);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? backgroundColor : unselectedBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}

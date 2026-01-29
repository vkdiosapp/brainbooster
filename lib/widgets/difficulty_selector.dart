import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DifficultySelector extends StatelessWidget {
  final bool isAdvanced;
  final ValueChanged<bool> onChanged;
  final EdgeInsetsGeometry? outerPadding;
  final EdgeInsetsGeometry contentPadding;
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
    this.showContainer = true,
    this.borderRadius = 16,
    this.normalLabel = 'Normal',
    this.advancedLabel = 'Advanced',
    this.gap = 16,
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
    final selectedBackground = AppTheme.textPrimary(context);
    final selectedTextColor = AppTheme.cardColor(context);
    final unselectedBackground = Colors.white;
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
      return Padding(padding: outerPadding!, child: optionsRow);
    }

    final inner = Container(
      padding: contentPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: optionsRow,
    );
    if (outerPadding == null) {
      return inner;
    }

    return Padding(padding: outerPadding!, child: inner);
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

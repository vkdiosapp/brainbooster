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
  final bool showDifficultyOptions;
  final bool? reverseEnabled;
  final ValueChanged<bool>? onReverseChanged;
  final String reverseLabel;
  final bool? notSequenceEnabled;
  final ValueChanged<bool>? onNotSequenceChanged;
  final String notSequenceLabel;
  final double optionsSpacing;
  final int? aimCount;
  final int aimMin;
  final int aimMax;
  final ValueChanged<int>? onAimCountChanged;
  final double aimSpacing;

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
    this.showDifficultyOptions = true,
    this.reverseEnabled,
    this.onReverseChanged,
    this.reverseLabel = 'Reverse',
    this.notSequenceEnabled,
    this.onNotSequenceChanged,
    this.notSequenceLabel = 'Not Sequence',
    this.optionsSpacing = 24,
    this.aimCount,
    this.aimMin = 1,
    this.aimMax = 10,
    this.onAimCountChanged,
    this.aimSpacing = 24,
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
    final selectedBackground = Color(0xFF0F172A);
    final selectedTextColor = Colors.white;
    final unselectedBackground = Colors.white;
    final unselectedTextColor = Color(0xFF64748B);

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
      final columnChildren = _buildContentChildren(context, optionsRow);
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: columnChildren,
      );
      if (outerPadding == null) {
        return content;
      }
      return Padding(padding: outerPadding!, child: content);
    }

    final showExtraOptions =
        reverseEnabled != null && onReverseChanged != null ||
        notSequenceEnabled != null && onNotSequenceChanged != null;

    final showAimControls = aimCount != null && onAimCountChanged != null;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildContentChildren(
          context,
          optionsRow,
          showExtraOptions: showExtraOptions,
          showAimControls: showAimControls,
        ),
      ),
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

  Widget _buildOptionToggle(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = AppTheme.isDark(context);
    final textColor = isDark
        ? AppTheme.textPrimary(context)
        : const Color(0xFF475569);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (newValue) => onChanged(newValue ?? false),
          activeColor: const Color(0xFF475569),
          checkColor: Colors.white,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContentChildren(
    BuildContext context,
    Widget optionsRow, {
    bool showExtraOptions = false,
    bool showAimControls = false,
  }) {
    final children = <Widget>[];

    if (showDifficultyOptions) {
      children.add(optionsRow);
    }

    if (showExtraOptions) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reverseEnabled != null && onReverseChanged != null)
              _buildOptionToggle(
                context,
                label: reverseLabel,
                value: reverseEnabled!,
                onChanged: onReverseChanged!,
              ),
            if (reverseEnabled != null &&
                onReverseChanged != null &&
                notSequenceEnabled != null &&
                onNotSequenceChanged != null)
              SizedBox(width: optionsSpacing),
            if (notSequenceEnabled != null && onNotSequenceChanged != null)
              _buildOptionToggle(
                context,
                label: notSequenceLabel,
                value: notSequenceEnabled!,
                onChanged: onNotSequenceChanged!,
              ),
          ],
        ),
      );
    }

    if (showAimControls) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(_buildAimCountControl(context));
    }

    return children;
  }

  Widget _buildAimCountControl(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final enabledColor = const Color(0xFF475569);
    final disabledColor = Colors.grey.withOpacity(0.3);
    final textColor = isDark
        ? AppTheme.textPrimary(context)
        : const Color(0xFF475569);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (aimCount != null &&
                onAimCountChanged != null &&
                aimCount! > aimMin) {
              onAimCountChanged!(aimCount! - 1);
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (aimCount != null && aimCount! > aimMin)
                  ? enabledColor
                  : disabledColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor(context),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(opacity: isDark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.remove, color: Colors.white, size: 24),
          ),
        ),
        SizedBox(width: aimSpacing),
        Text(
          '${aimCount ?? aimMin} Aim${aimCount == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        SizedBox(width: aimSpacing),
        GestureDetector(
          onTap: () {
            if (aimCount != null &&
                onAimCountChanged != null &&
                aimCount! < aimMax) {
              onAimCountChanged!(aimCount! + 1);
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (aimCount != null && aimCount! < aimMax)
                  ? enabledColor
                  : disabledColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor(context),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(opacity: isDark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }
}

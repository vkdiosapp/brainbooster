import 'package:flutter/material.dart';

/// A reusable category header widget that displays "CATEGORY: CATEGORY NAME"
class CategoryHeader extends StatelessWidget {
  final String categoryName;

  const CategoryHeader({
    super.key,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'CATEGORY: ${categoryName.toUpperCase()}',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Color(0xFF94A3B8),
        letterSpacing: 2.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}

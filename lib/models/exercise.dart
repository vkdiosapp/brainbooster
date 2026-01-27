import 'package:flutter/material.dart';

class Exercise {
  final int id;
  final int categoryId;
  final String name;
  final String desc;
  final String? imageUrl;
  final IconData icon;
  final bool isPro;
  final bool isRecommended;
  final int timeRequired; // in milliseconds
  final int penaltyTime; // in milliseconds

  Exercise({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.desc,
    this.imageUrl,
    required this.icon,
    this.isPro = false,
    this.isRecommended = false,
    this.timeRequired = 350, // default 350ms
    this.penaltyTime = 1000, // default 1000ms
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      categoryId: json['categoryId'] as int,
      name: json['name'] as String,
      desc: json['desc'] as String,
      imageUrl: json['imageUrl'] as String?,
      icon: _getIconFromId(json['id'] as int),
      isPro: json['isPro'] as bool? ?? false,
      isRecommended: json['isRecommended'] as bool? ?? false,
      timeRequired: json['timeRequired'] as int? ?? 350,
      penaltyTime: json['penaltyTime'] as int? ?? 1000,
    );
  }

  static IconData _getIconFromId(int id) {
    switch (id) {
      case 1:
        return Icons.palette; // Color Change
      case 2:
        return Icons.push_pin; // Find Number
      case 3:
        return Icons.sports_baseball; // Catch The Ball
      case 4:
        return Icons.color_lens; // Find Color
      case 5:
        return Icons.sports_baseball; // Catch Color
      case 6:
        return Icons.functions; // Quick Math
      case 7:
        return Icons.shape_line; // Figure Change
      case 8:
        return Icons.volume_up; // Sound
      case 9:
        return Icons.vibration; // Sensation
      case 10:
        return Icons.format_list_numbered; // Sequence Rush
      case 11:
        return Icons.sports_baseball; // Ball Rush
      case 12:
        return Icons.sports_baseball; // Ball Track
      case 13:
        return Icons.visibility; // Visual Memory
      case 14:
        return Icons.swipe; // Swipe
      case 15:
        return Icons.grid_view; // Excess Cells
      case 16:
        return Icons.my_location; // Aim
      case 17:
        return Icons.memory; // Memorize
      case 18:
        return Icons.remove_red_eye; // Peripheral Vision
      case 19:
        return Icons.straighten; // Longest Line
      default:
        return Icons.fitness_center;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'desc': desc,
      'imageUrl': imageUrl,
      'isPro': isPro,
      'isRecommended': isRecommended,
      'timeRequired': timeRequired,
      'penaltyTime': penaltyTime,
    };
  }
}

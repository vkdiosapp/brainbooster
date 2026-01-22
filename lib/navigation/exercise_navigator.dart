import 'package:flutter/material.dart';
import '../pages/color_change_page.dart';
import '../pages/find_number_page.dart';

class ExerciseNavigator {
  /// Navigate to the appropriate exercise page based on exercise ID
  static void navigateToExercise(BuildContext context, int exerciseId) {
    switch (exerciseId) {
      case 1:
        // Color Change game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ColorChangePage(),
          ),
        );
        break;
      case 2:
        // Find Number game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FindNumberPage(),
          ),
        );
        break;
      // Add more cases for other exercises as they are implemented
      // case 3:
      //   Navigator.of(context).push(
      //     MaterialPageRoute(
      //       builder: (context) => const CatchTheBallPage(),
      //     ),
      //   );
      //   break;
      default:
        // If exercise not found, do nothing or show a message
        break;
    }
  }
}

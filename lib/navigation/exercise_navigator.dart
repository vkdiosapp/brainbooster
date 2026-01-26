import 'package:flutter/material.dart';
import '../pages/color_change_page.dart';
import '../pages/find_number_page.dart';
import '../pages/find_color_page.dart';
import '../pages/catch_ball_page.dart';
import '../pages/catch_color_page.dart';
import '../pages/quick_math_page.dart';
import '../pages/figure_change_page.dart';
import '../pages/sound_game_page.dart';
import '../pages/sensation_game_page.dart';
import '../pages/sequence_rush_page.dart';
import '../pages/ball_rush_page.dart';
import '../pages/ball_track_page.dart';
import '../data/exercise_data.dart';

class ExerciseNavigator {
  /// Navigate to the appropriate exercise page based on exercise ID
  static void navigateToExercise(BuildContext context, int exerciseId) {
    // Get the exercise and its category
    final exercises = ExerciseData.getExercises();
    final exercise = exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => exercises.first,
    );
    
    final categories = ExerciseData.getCategories();
    final category = categories.firstWhere(
      (c) => c.id == exercise.categoryId,
      orElse: () => categories.first,
    );

    switch (exerciseId) {
      case 1:
        // Color Change game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ColorChangePage(categoryName: category.name),
          ),
        );
        break;
      case 2:
        // Find Number game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FindNumberPage(categoryName: category.name),
          ),
        );
        break;
      case 3:
        // Catch The Ball game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CatchBallPage(categoryName: category.name),
          ),
        );
        break;
      case 4:
        // Find Color game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FindColorPage(categoryName: category.name),
          ),
        );
        break;
      case 5:
        // Catch Color game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CatchColorPage(categoryName: category.name),
          ),
        );
        break;
      case 6:
        // Quick Math game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuickMathPage(categoryName: category.name),
          ),
        );
        break;
      case 7:
        // Figure Change game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FigureChangePage(categoryName: category.name),
          ),
        );
        break;
      case 8:
        // Sound game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SoundGamePage(categoryName: category.name),
          ),
        );
        break;
      case 9:
        // Sensation game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SensationGamePage(categoryName: category.name),
          ),
        );
        break;
      case 10:
        // Sequence Rush game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SequenceRushPage(categoryName: category.name),
          ),
        );
        break;
      case 11:
        // Ball Rush game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BallRushPage(categoryName: category.name),
          ),
        );
        break;
      case 12:
        // Ball Track game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BallTrackPage(categoryName: category.name),
          ),
        );
        break;
      // Add more cases for other exercises as they are implemented
      default:
        // If exercise not found, do nothing or show a message
        break;
    }
  }
}

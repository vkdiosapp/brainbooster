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
import '../pages/visual_memory_page.dart';
import '../pages/swipe_game_page.dart';
import '../pages/excess_cells_page.dart';
import '../pages/aim_game_page.dart';
import '../pages/dots_count_page.dart';
import '../pages/memorize_game_page.dart';
import '../pages/peripheral_vision_page.dart';
import '../pages/longest_line_page.dart';
import '../pages/click_limit_page.dart';
import '../pages/f1_race_page.dart';
import '../pages/spatial_imagination_page.dart';
import '../pages/same_number_page.dart';
import '../pages/same_shape_page.dart';
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
            builder: (context) => ColorChangePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 2:
        // Find Number game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FindNumberPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 3:
        // Catch The Ball game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CatchBallPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 4:
        // Find Color game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FindColorPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 5:
        // Catch Color game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CatchColorPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 6:
        // Quick Math game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuickMathPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 7:
        // Figure Change game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FigureChangePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 8:
        // Sound game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SoundGamePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 9:
        // Sensation game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SensationGamePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 10:
        // Sequence Rush game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SequenceRushPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 11:
        // Ball Rush game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BallRushPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 12:
        // Ball Track game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BallTrackPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 13:
        // Visual Memory game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VisualMemoryPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 14:
        // Swipe game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SwipeGamePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 15:
        // Excess Cells game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ExcessCellsPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 16:
        // Aim game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AimGamePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 17:
        // Memorize game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MemorizeGamePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 18:
        // Peripheral Vision game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PeripheralVisionPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 19:
        // Longest Line game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LongestLinePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 20:
        // F1 Race game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => F1RacePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 21:
        // Spatial Imagination game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SpatialImaginationPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 22:
        // Click Limit game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ClickLimitPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 23:
        // Same Number game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SameNumberPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 24:
        // Dots Count game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DotsCountPage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
          ),
        );
        break;
      case 25:
        // Same Shape game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SameShapePage(
              categoryName: category.name,
              exerciseName: exercise.name,
            ),
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

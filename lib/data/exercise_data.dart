import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/exercise.dart';

class ExerciseData {
  static List<Category> getCategories() {
    return [
      Category(id: 1, name: 'Reaction'),
      Category(id: 2, name: 'Memory'),
      Category(id: 3, name: 'Math'),
      Category(id: 4, name: 'Visual'),
      Category(id: 5, name: 'Logic'),
    ];
  }

  static List<Exercise> getExercises() {
    return [
      Exercise(
        id: 1,
        categoryId: 1,
        name: 'Color Change',
        desc:
            'Boost your reaction speed by identifying rapid color shifts in real-time.',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBTFo1CdlHTfS7aak4OC9WXyP0Ix_KDkptveGyCzBnXpFvtRFAuSetyV03Ki_GSDyOw57a3oL3nFEPsPI_k_uf-YTr6SzhGAO73K9qKuPIcywoxxJLLrf4gEZCTuzacydth9CgUEBRA_YnbDFKH0o31jTQ8wJGaPQd9FmJCk3JuCSRR9t0dGOcKAlF66dp7j0_haPNkq9O8Nvi33yufSzg0_3tjpLDYFsmeTV0c6O59ebU43KdF62f1q140dCiQ-VBXF8OYhiDpPZhm',
        icon: Icons.palette,
        isRecommended: true,
        timeRequired: 350,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 2,
        categoryId: 2,
        name: 'Find Number',
        desc: 'Identify numerical patterns quickly',
        icon: Icons.push_pin,
        timeRequired: 400,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 3,
        categoryId: 1,
        name: 'Catch The Ball',
        desc: 'Reaction on moving objects',
        icon: Icons.sports_baseball,
        timeRequired: 300,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 4,
        categoryId: 4,
        name: 'Find Color',
        desc: 'Advanced visual differentiation',
        icon: Icons.color_lens,
        timeRequired: 450,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 5,
        categoryId: 4,
        name: 'Catch Color',
        desc: 'Tap the correct colored tile as fast as you can.',
        icon: Icons.sports_baseball,
        timeRequired: 450,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 6,
        categoryId: 3,
        name: 'Quick Math',
        desc: 'Solve math problems rapidly',
        icon: Icons.functions,
        timeRequired: 600,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 7,
        categoryId: 4,
        name: 'Figure Change',
        desc: 'Tap when both figures match',
        icon: Icons.shape_line,
        timeRequired: 400,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 8,
        categoryId: 1,
        name: 'Sound',
        desc: 'Tap when you hear the sound',
        icon: Icons.volume_up,
        timeRequired: 350,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 9,
        categoryId: 1,
        name: 'Sensation',
        desc: 'Tap when you feel the vibration',
        icon: Icons.vibration,
        timeRequired: 350,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 10,
        categoryId: 2,
        name: 'Sequence Rush',
        desc: 'Tap numbers in sequence as fast as you can',
        icon: Icons.format_list_numbered,
        timeRequired: 5000,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 11,
        categoryId: 1,
        name: 'Ball Rush',
        desc: 'Catch all 10 balls as they move around',
        icon: Icons.sports_baseball,
        timeRequired: 3000,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 12,
        categoryId: 2,
        name: 'Ball Track',
        desc: 'Memorize the red ball and tap it after they stop',
        icon: Icons.sports_baseball,
        timeRequired: 4000,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 13,
        categoryId: 2,
        name: 'Visual Memory',
        desc: 'Memorize the red dots and tap them after they disappear',
        icon: Icons.visibility,
        timeRequired: 3000,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 14,
        categoryId: 1,
        name: 'Swipe',
        desc: 'Swipe in the correct direction as fast as you can',
        icon: Icons.swipe,
        timeRequired: 400,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 15,
        categoryId: 4,
        name: 'Excess Cells',
        desc:
            'Find and tap the two triangles pointing in a different direction',
        icon: Icons.grid_view,
        timeRequired: 500,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 16,
        categoryId: 4,
        name: 'Aim',
        desc: 'Tap all the aim targets as fast as you can',
        icon: Icons.my_location,
        timeRequired: 1000,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 17,
        categoryId: 2,
        name: 'Memorize',
        desc: 'Memorize emoji pairs and match them after they disappear',
        icon: Icons.memory,
        timeRequired: 5000,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 18,
        categoryId: 4,
        name: 'Peripheral Vision',
        desc:
            'Memorize numbers in your peripheral vision and tap the higher number',
        icon: Icons.remove_red_eye,
        timeRequired: 400,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 19,
        categoryId: 4,
        name: 'Longest Line',
        desc: 'Tap the longest line among 5 lines starting from random sides',
        icon: Icons.straighten,
        timeRequired: 400,
        penaltyTime: 1000,
      ),
      Exercise(
        id: 20,
        categoryId: 1,
        name: 'F1 Race',
        desc:
            'React to changing traffic lights with the correct pedal as fast as you can.',
        icon: Icons.sports_motorsports,
        timeRequired: 400,
        penaltyTime: 1050,
      ),
    ];
  }

  static List<Exercise> getRandomExercises(int count) {
    final exercises = getExercises();
    exercises.shuffle();
    return exercises.take(count).toList();
  }

  static List<Exercise> getExercisesByCategory(int categoryId) {
    return getExercises().where((e) => e.categoryId == categoryId).toList();
  }
}

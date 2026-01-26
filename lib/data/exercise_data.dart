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
        isRecommended: true,
        timeRequired: 350,
      ),
      Exercise(
        id: 2,
        categoryId: 2,
        name: 'Find Number',
        desc: 'Identify numerical patterns quickly',
        timeRequired: 400,
      ),
      Exercise(
        id: 3,
        categoryId: 1,
        name: 'Catch The Ball',
        desc: 'Reaction on moving objects',
        timeRequired: 300,
      ),
      Exercise(
        id: 4,
        categoryId: 4,
        name: 'Find Color',
        desc: 'Advanced visual differentiation',
        timeRequired: 450,
      ),
      Exercise(
        id: 5,
        categoryId: 4,
        name: 'Catch Color',
        desc: 'Tap the correct colored tile as fast as you can.',
        timeRequired: 450,
      ),
      Exercise(
        id: 6,
        categoryId: 3,
        name: 'Quick Math',
        desc: 'Solve math problems rapidly',
        timeRequired: 600,
      ),
      Exercise(
        id: 7,
        categoryId: 4,
        name: 'Figure Change',
        desc: 'Tap when both figures match',
        timeRequired: 400,
      ),
      Exercise(
        id: 8,
        categoryId: 1,
        name: 'Sound',
        desc: 'Tap when you hear the sound',
        timeRequired: 350,
      ),
      Exercise(
        id: 9,
        categoryId: 1,
        name: 'Sensation',
        desc: 'Tap when you feel the vibration',
        timeRequired: 350,
      ),
      Exercise(
        id: 10,
        categoryId: 2,
        name: 'Sequence Rush',
        desc: 'Tap numbers in sequence as fast as you can',
        timeRequired: 5000,
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

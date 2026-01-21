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
        desc: 'Boost your reaction speed by identifying rapid color shifts in real-time.',
        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBTFo1CdlHTfS7aak4OC9WXyP0Ix_KDkptveGyCzBnXpFvtRFAuSetyV03Ki_GSDyOw57a3oL3nFEPsPI_k_uf-YTr6SzhGAO73K9qKuPIcywoxxJLLrf4gEZCTuzacydth9CgUEBRA_YnbDFKH0o31jTQ8wJGaPQd9FmJCk3JuCSRR9t0dGOcKAlF66dp7j0_haPNkq9O8Nvi33yufSzg0_3tjpLDYFsmeTV0c6O59ebU43KdF62f1q140dCiQ-VBXF8OYhiDpPZhm',
        isRecommended: true,
      ),
      Exercise(
        id: 2,
        categoryId: 2,
        name: 'Find Number',
        desc: 'Identify numerical patterns quickly',
      ),
      Exercise(
        id: 3,
        categoryId: 1,
        name: 'Catch The Ball',
        desc: 'Reaction on moving objects',
      ),
      Exercise(
        id: 4,
        categoryId: 4,
        name: 'Find Color',
        desc: 'Advanced visual differentiation',
        isPro: true,
      ),
      Exercise(
        id: 5,
        categoryId: 4,
        name: 'Schulte Table',
        desc: 'Expand your peripheral vision',
      ),
      Exercise(
        id: 6,
        categoryId: 3,
        name: 'Quick Math',
        desc: 'Solve math problems rapidly',
      ),
      Exercise(
        id: 7,
        categoryId: 2,
        name: 'Memory Sequence',
        desc: 'Remember and recall patterns',
      ),
      Exercise(
        id: 8,
        categoryId: 5,
        name: 'Logic Puzzle',
        desc: 'Solve complex logical problems',
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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_exercises';
  
  // Notifier for favorites changes - updates when favorites are added/removed
  static final ValueNotifier<Set<int>> favoritesNotifier = ValueNotifier<Set<int>>(<int>{});
  
  // Initialize favorites notifier
  static Future<void> initialize() async {
    final favorites = await getFavoriteExerciseIds();
    favoritesNotifier.value = favorites;
  }

  // Get all favorite exercise IDs
  static Future<Set<int>> getFavoriteExerciseIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey);
      if (favoritesJson == null) return <int>{};
      return favoritesJson.map((id) => int.parse(id)).toSet();
    } catch (e) {
      print('Error loading favorites: $e');
      return <int>{};
    }
  }

  // Check if an exercise is favorited
  static Future<bool> isFavorite(int exerciseId) async {
    final favorites = await getFavoriteExerciseIds();
    return favorites.contains(exerciseId);
  }

  // Add exercise to favorites
  static Future<void> addFavorite(int exerciseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavoriteExerciseIds();
      favorites.add(exerciseId);
      final favoritesList = favorites.map((id) => id.toString()).toList();
      await prefs.setStringList(_favoritesKey, favoritesList);
      // Update notifier to trigger UI updates
      favoritesNotifier.value = Set<int>.from(favorites);
    } catch (e) {
      print('Error adding favorite: $e');
    }
  }

  // Remove exercise from favorites
  static Future<void> removeFavorite(int exerciseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavoriteExerciseIds();
      favorites.remove(exerciseId);
      final favoritesList = favorites.map((id) => id.toString()).toList();
      await prefs.setStringList(_favoritesKey, favoritesList);
      // Update notifier to trigger UI updates
      favoritesNotifier.value = Set<int>.from(favorites);
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  // Toggle favorite status
  static Future<bool> toggleFavorite(int exerciseId) async {
    final isFav = await isFavorite(exerciseId);
    if (isFav) {
      await removeFavorite(exerciseId);
      return false;
    } else {
      await addFavorite(exerciseId);
      return true;
    }
  }
}

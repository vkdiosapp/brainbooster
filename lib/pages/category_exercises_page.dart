import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/exercise.dart';
import '../data/exercise_data.dart';
import '../navigation/exercise_navigator.dart';
import '../widgets/gradient_background.dart';
import '../services/favorites_service.dart';

class CategoryExercisesPage extends StatefulWidget {
  final Category category;

  const CategoryExercisesPage({super.key, required this.category});

  @override
  State<CategoryExercisesPage> createState() => _CategoryExercisesPageState();
}

class _CategoryExercisesPageState extends State<CategoryExercisesPage> {
  List<Exercise> _exercises = [];
  List<Exercise> _filteredExercises = [];
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: All, 1: Favourite
  Set<int> _favoriteExerciseIds = {};
  Map<int, bool> _favoriteStatusCache = {};

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _loadFavorites();
    _searchController.addListener(_filterExercises);
    // Listen to favorites changes
    FavoritesService.favoritesNotifier.addListener(_onFavoritesChanged);
  }

  void _onFavoritesChanged() {
    setState(() {
      _favoriteExerciseIds = FavoritesService.favoritesNotifier.value;
      // Update cache
      for (final exercise in _exercises) {
        _favoriteStatusCache[exercise.id] = _favoriteExerciseIds.contains(exercise.id);
      }
    });
    _filterExercises();
  }

  Future<void> _loadFavorites() async {
    // Initialize notifier if not already initialized
    if (FavoritesService.favoritesNotifier.value.isEmpty) {
      await FavoritesService.initialize();
    }
    setState(() {
      _favoriteExerciseIds = FavoritesService.favoritesNotifier.value;
      // Update cache
      for (final exercise in _exercises) {
        _favoriteStatusCache[exercise.id] = _favoriteExerciseIds.contains(exercise.id);
      }
    });
    _filterExercises();
  }

  void _loadExercises() {
    setState(() {
      _exercises = ExerciseData.getExercisesByCategory(widget.category.id);
      _filteredExercises = _exercises;
    });
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<Exercise> baseList = _exercises;

      // Filter by tab (All or Favourite)
      if (_selectedTab == 1) {
        // Favourite tab - only show favorites
        baseList = _exercises
            .where((exercise) => _favoriteExerciseIds.contains(exercise.id))
            .toList();
      }

      // Filter by search query
      if (query.isEmpty) {
        _filteredExercises = baseList;
      } else {
        _filteredExercises = baseList
            .where(
              (exercise) =>
                  exercise.name.toLowerCase().contains(query) ||
                  exercise.desc.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    FavoritesService.favoritesNotifier.removeListener(_onFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GradientBackground.backgroundColor,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.category.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tab selector (All / Favourite)
              _buildTabSelector(),
              const SizedBox(height: 16),
              // Exercise list
              Expanded(
                child: _filteredExercises.isEmpty
                    ? Center(
                        child: Text(
                          'No exercises found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filteredExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _filteredExercises[index];
                          return _buildExerciseTile(exercise, exercise.id);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTile(Exercise exercise, int number) {
    final tileData = _getTileDataForExercise(exercise, number);

    return GestureDetector(
      onTap: () {
        ExerciseNavigator.navigateToExercise(context, exercise.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: tileData['backgroundColor'] as Color,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  tileData['icon'] as IconData,
                  color: tileData['iconColor'] as Color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${number.toString()}. ${exercise.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tileData['textColor'] as Color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.desc.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: (tileData['textColor'] as Color).withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Action icons
              Row(
                children: [
                  if (exercise.isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (tileData['iconColor'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.ad_units,
                        size: 16,
                        color: tileData['iconColor'] as Color,
                      ),
                    )
                  else ...[
                    Icon(
                      Icons.help_outline,
                      color: (tileData['iconColor'] as Color).withOpacity(0.6),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        // Prevent navigation when tapping star
                        await FavoritesService.toggleFavorite(exercise.id);
                        // No need to call _loadFavorites() - notifier will update automatically
                      },
                      child: Icon(
                        _favoriteStatusCache[exercise.id] == true
                            ? Icons.star
                            : Icons.star_outline,
                        color: _favoriteStatusCache[exercise.id] == true
                            ? Colors.yellow[700]
                            : (tileData['iconColor'] as Color).withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getTileDataForExercise(Exercise exercise, int number) {
    // Pastel colors from HTML
    final pastelColors = [
      {
        'bg': const Color(0xFFE0F2FE), // blue
        'iconColor': const Color(0xFF0EA5E9), // sky-600
        'textColor': const Color(0xFF0C4A6E), // sky-900
        'icon': Icons.palette,
      },
      {
        'bg': const Color(0xFFFCE7F3), // pink
        'iconColor': const Color(0xFFEC4899), // pink-600
        'textColor': const Color(0xFF831843), // pink-900
        'icon': Icons.push_pin,
      },
      {
        'bg': const Color(0xFFDCFCE7), // green
        'iconColor': const Color(0xFF16A34A), // emerald-600
        'textColor': const Color(0xFF064E3B), // emerald-900
        'icon': Icons.sports_baseball,
      },
      {
        'bg': const Color(0xFFEDE9FE), // lavender/violet
        'iconColor': const Color(0xFF8B5CF6), // violet-600
        'textColor': const Color(0xFF4C1D95), // violet-900
        'icon': Icons.style,
      },
      {
        'bg': const Color(0xFFF5F3FF), // indigo
        'iconColor': const Color(0xFF6366F1), // indigo-600
        'textColor': const Color(0xFF312E81), // indigo-900
        'icon': Icons.functions,
      },
      {
        'bg': const Color(0xFFF0FDF4), // teal
        'iconColor': const Color(0xFF14B8A6), // teal-600
        'textColor': const Color(0xFF134E4A), // teal-900
        'icon': Icons.grid_4x4,
      },
      {
        'bg': const Color(0xFFFEF3C7), // amber
        'iconColor': const Color(0xFFF59E0B), // amber-600
        'textColor': const Color(0xFF78350F), // amber-900
        'icon': Icons.visibility,
      },
      {
        'bg': const Color(0xFFCFFAFE), // cyan
        'iconColor': const Color(0xFF06B6D4), // cyan-600
        'textColor': const Color(0xFF164E63), // cyan-900
        'icon': Icons.color_lens,
      },
      {
        'bg': const Color(0xFFFFE4E6), // rose
        'iconColor': const Color(0xFFF43F5E), // rose-600
        'textColor': const Color(0xFF881337), // rose-900
        'icon': Icons.psychology,
      },
    ];

    final colorIndex = (number - 1) % pastelColors.length;
    final baseColor = pastelColors[colorIndex];
    final icon = exercise.icon;

    return {
      'backgroundColor': baseColor['bg'] as Color,
      'iconColor': baseColor['iconColor'] as Color,
      'textColor': baseColor['textColor'] as Color,
      'icon': icon,
    };
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = 0;
              });
              _filterExercises();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: _selectedTab == 0
                        ? const Color(0xFF475569)
                        : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Text(
                'All',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = 1;
              });
              _filterExercises();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: _selectedTab == 1
                        ? const Color(0xFF475569)
                        : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Text(
                'Favourite',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

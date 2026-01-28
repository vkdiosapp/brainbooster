import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/exercise.dart';
import '../data/exercise_data.dart';
import 'pages/category_exercises_page.dart';
import 'pages/login_page.dart';
import 'pages/settings_page.dart';
import 'pages/analytics_page.dart';
import 'navigation/exercise_navigator.dart';
import 'widgets/gradient_background.dart';
import '../services/favorites_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _bannerController = PageController();
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _randomExercises = [];
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  List<Category> _categories = [];
  int _currentBannerIndex = 0;
  bool _isSearching = false;
  bool _showSearchField = false;
  Timer? _bannerTimer;
  int _selectedTab = 0; // 0: Home, 1: Discover, 2: Stats, 3: Profile
  int _exerciseTab = 0; // 0: All, 1: Favourite
  Set<int> _favoriteExerciseIds = {};
  Map<int, bool> _favoriteStatusCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterExercises);
    // Listen to favorites changes
    FavoritesService.favoritesNotifier.addListener(_onFavoritesChanged);
  }

  void _onFavoritesChanged() {
    setState(() {
      _favoriteExerciseIds = FavoritesService.favoritesNotifier.value;
      // Update cache
      for (final exercise in _allExercises) {
        _favoriteStatusCache[exercise.id] = _favoriteExerciseIds.contains(
          exercise.id,
        );
      }
    });
    _filterExercises();
  }

  void _loadData() {
    setState(() {
      _categories = ExerciseData.getCategories();
      _allExercises = ExerciseData.getExercises();
      _randomExercises = ExerciseData.getRandomExercises(3);
      _filteredExercises = _allExercises;
    });
    _loadFavorites();
    // Start auto-scroll after data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBannerAutoScroll();
    });
  }

  Future<void> _loadFavorites() async {
    // Initialize notifier if not already initialized
    if (FavoritesService.favoritesNotifier.value.isEmpty) {
      await FavoritesService.initialize();
    }
    setState(() {
      _favoriteExerciseIds = FavoritesService.favoritesNotifier.value;
      // Update cache
      for (final exercise in _allExercises) {
        _favoriteStatusCache[exercise.id] = _favoriteExerciseIds.contains(
          exercise.id,
        );
      }
    });
    _filterExercises();
  }

  void _startBannerAutoScroll() {
    // Cancel existing timer if any
    _bannerTimer?.cancel();

    // Auto-scroll banner every 5 seconds
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted &&
          _randomExercises.isNotEmpty &&
          !_isSearching &&
          !_showSearchField &&
          _bannerController.hasClients) {
        final nextIndex = (_currentBannerIndex + 1) % _randomExercises.length;
        _bannerController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<Exercise> baseList = _allExercises;

      // Filter by tab (All or Favourite) - only if not searching
      if (query.isEmpty && _exerciseTab == 1) {
        // Favourite tab - only show favorites
        baseList = _allExercises
            .where((exercise) => _favoriteExerciseIds.contains(exercise.id))
            .toList();
      }

      // Filter by search query
      if (query.isEmpty) {
        _filteredExercises = baseList;
        _isSearching = false;
      } else {
        _filteredExercises = baseList
            .where(
              (exercise) =>
                  exercise.name.toLowerCase().contains(query) ||
                  exercise.desc.toLowerCase().contains(query),
            )
            .toList();
        _isSearching = true;
      }
    });
  }

  @override
  void dispose() {
    FavoritesService.favoritesNotifier.removeListener(_onFavoritesChanged);
    _stopBannerAutoScroll();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: GradientBackground.backgroundColor,
        extendBody: true,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTab == 3
                                ? 'Edit Profile'
                                : _selectedTab == 2
                                ? 'Game Analytics'
                                : 'Exercises',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            _selectedTab == 3
                                ? 'Update your personal information'
                                : _selectedTab == 2
                                ? 'Performance Analysis'
                                : 'Train your brain today',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showSearchField ? Icons.close : Icons.search,
                            ),
                            onPressed: () {
                              setState(() {
                                _showSearchField = !_showSearchField;
                                if (!_showSearchField) {
                                  _searchController.clear();
                                  _isSearching = false;
                                  _filteredExercises = _allExercises;
                                  // Restart auto-scroll when search is closed
                                  _startBannerAutoScroll();
                                } else {
                                  // Stop auto-scroll when search is opened
                                  _stopBannerAutoScroll();
                                  // Focus on search field when shown
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(FocusNode());
                                    },
                                  );
                                }
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              shape: const CircleBorder(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Search field (appears below header when search button is tapped)
                if (_showSearchField && _selectedTab == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search exercises...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  child: _selectedTab == 3
                      ? const LoginPage(isEditMode: true)
                      : _selectedTab == 2
                      ? _buildStatsView()
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Banner section
                              if (!_isSearching && !_showSearchField) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.5,
                                    child: PageView.builder(
                                      controller: _bannerController,
                                      onPageChanged: (index) {
                                        setState(() {
                                          _currentBannerIndex = index;
                                        });
                                      },
                                      itemCount: _randomExercises.length,
                                      itemBuilder: (context, index) {
                                        final exercise =
                                            _randomExercises[index];
                                        return _buildBannerCard(exercise);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Banner indicators
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _randomExercises.length,
                                    (index) => Container(
                                      width: index == _currentBannerIndex
                                          ? 24
                                          : 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: index == _currentBannerIndex
                                            ? const Color(0xFF6366F1)
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Categories section
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Categories',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Categories horizontal list
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    itemCount: _categories.length,
                                    itemBuilder: (context, index) {
                                      final category = _categories[index];
                                      return _buildCategoryButton(
                                        category,
                                        index,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                              // All Exercises section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _isSearching
                                          ? 'Search Results'
                                          : 'All Exercises',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Tab selector (All / Favourite) - only show when not searching
                              if (!_isSearching) _buildExerciseTabSelector(),
                              if (!_isSearching) const SizedBox(height: 16),
                              // Exercise list
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredExercises.length,
                                  itemBuilder: (context, index) {
                                    final exercise = _filteredExercises[index];
                                    return _buildExerciseTile(
                                      exercise,
                                      exercise.id,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Bottom Navigation
        bottomNavigationBar: _buildPillNavigationBar(),
      ),
    );
  }

  Widget _buildBannerCard(Exercise exercise) {
    return GestureDetector(
      onTap: () {
        ExerciseNavigator.navigateToExercise(context, exercise.id);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Background - use same background for all banners (Color Change style)
              Positioned.fill(
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBTFo1CdlHTfS7aak4OC9WXyP0Ix_KDkptveGyCzBnXpFvtRFAuSetyV03Ki_GSDyOw57a3oL3nFEPsPI_k_uf-YTr6SzhGAO73K9qKuPIcywoxxJLLrf4gEZCTuzacydth9CgUEBRA_YnbDFKH0o31jTQ8wJGaPQd9FmJCk3JuCSRR9t0dGOcKAlF66dp7j0_haPNkq9O8Nvi33yufSzg0_3tjpLDYFsmeTV0c6O59ebU43KdF62f1q140dCiQ-VBXF8OYhiDpPZhm',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1),
                            const Color(0xFF818CF8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // Recommended badge
              if (exercise.isRecommended)
                Positioned(
                  top: 24,
                  left: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'RECOMMENDED FOR YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              // Content
              Positioned(
                bottom: 32,
                left: 32,
                right: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.desc,
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            ExerciseNavigator.navigateToExercise(
                              context,
                              exercise.id,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Start Now',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final gameId = _getGameIdFromExerciseId(
                                  exercise.id,
                                );
                                if (gameId != null) {
                                  final gameName = _getGameNameFromGameId(
                                    gameId,
                                  );
                                  if (gameName != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => AnalyticsPage(
                                          gameId: gameId,
                                          gameName: gameName,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.bar_chart,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                await FavoritesService.toggleFavorite(
                                  exercise.id,
                                );
                                // No need to call _loadFavorites() - notifier will update automatically
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: Icon(
                                  _favoriteStatusCache[exercise.id] == true
                                      ? Icons.star
                                      : Icons.star_outline,
                                  color:
                                      _favoriteStatusCache[exercise.id] == true
                                      ? Colors.yellow[300]
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(Category category, int index) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFE11D48), // Rose
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF0EA5E9), // Sky
    ];
    final icons = [
      Icons.bolt,
      Icons.psychology,
      Icons.calculate,
      Icons.visibility,
      Icons.grid_on,
    ];

    final color = colors[index % colors.length];
    final icon = icons[index % icons.length];

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CategoryExercisesPage(category: category),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String? _getGameIdFromExerciseId(int exerciseId) {
    // Map exercise IDs to game IDs
    // IMPORTANT: When adding a new game with analytics, add it here
    // All games that save sessions should be included here
    switch (exerciseId) {
      case 1:
        return 'color_change';
      case 2:
        return 'find_number';
      case 3:
        return 'catch_ball';
      case 4:
        return 'find_color';
      case 5:
        return 'catch_color';
      case 6:
        return 'quick_math';
      case 7:
        return 'figure_change';
      case 8:
        return 'sound';
      case 9:
        return 'sensation';
      case 10:
        return 'sequence_rush';
      case 11:
        return 'ball_rush';
      case 12:
        return 'ball_track';
      case 13:
        return 'visual_memory';
      case 14:
        return 'swipe';
      case 15:
        return 'excess_cells';
      case 16:
        return 'aim';
      case 17:
        return 'memorize';
      case 18:
        return 'peripheral_vision';
      case 19:
        return 'longest_line';
      case 20:
        return 'f1_race';
      case 21:
        return 'spatial_imagination';
      case 22:
        return 'click_limit';
      case 23:
        return 'same_number';
      case 24:
        return 'dots_count';
      case 25:
        return 'same_shape';
      default:
        return null; // Games without analytics yet
    }
  }

  /// Get game name from game ID
  /// This ensures consistency between gameId and gameName
  String? _getGameNameFromGameId(String gameId) {
    // Map game IDs to game names
    // IMPORTANT: When adding a new game with analytics, add it here
    switch (gameId) {
      case 'color_change':
        return 'Color Change';
      case 'find_number':
        return 'Find Number';
      case 'catch_ball':
        return 'Catch The Ball';
      case 'find_color':
        return 'Find Color';
      case 'catch_color':
        return 'Catch Color';
      case 'quick_math':
        return 'Quick Math';
      case 'figure_change':
        return 'Figure Change';
      case 'sound':
        return 'Sound';
      case 'sensation':
        return 'Sensation';
      case 'sequence_rush':
        return 'Sequence Rush';
      case 'ball_rush':
        return 'Ball Rush';
      case 'ball_track':
        return 'Ball Track';
      case 'visual_memory':
        return 'Visual Memory';
      case 'swipe':
        return 'Swipe';
      case 'excess_cells':
        return 'Excess Cells';
      case 'aim':
        return 'Aim';
      case 'memorize':
        return 'Memorize';
      case 'peripheral_vision':
        return 'Peripheral Vision';
      case 'longest_line':
        return 'Longest Line';
      case 'f1_race':
        return 'F1 Race';
      case 'spatial_imagination':
        return 'Spatial Imagination';
      case 'click_limit':
        return 'Click Limit';
      case 'same_number':
        return 'Same Number';
      case 'dots_count':
        return 'Dots Count';
      case 'same_shape':
        return 'Same Shape';
      default:
        return null;
    }
  }

  /// Get all games that have analytics support
  /// This automatically builds the list from exercises that have gameIds
  List<Map<String, String>> _getGamesWithAnalytics() {
    final games = <Map<String, String>>[];

    // Get all exercises and check which ones have analytics
    for (final exercise in _allExercises) {
      final gameId = _getGameIdFromExerciseId(exercise.id);
      if (gameId != null) {
        final gameName = _getGameNameFromGameId(gameId);
        if (gameName != null) {
          games.add({'id': gameId, 'name': gameName});
        }
      }
    }

    return games;
  }

  Widget _buildExerciseTile(Exercise exercise, int number) {
    final gameId = _getGameIdFromExerciseId(exercise.id);
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
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
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
                        color: (tileData['textColor'] as Color).withOpacity(
                          0.7,
                        ),
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
                        color: (tileData['iconColor'] as Color).withOpacity(
                          0.2,
                        ),
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
                    if (gameId != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AnalyticsPage(
                                gameId: gameId,
                                gameName: exercise.name,
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.bar_chart,
                          color: (tileData['iconColor'] as Color).withOpacity(
                            0.6,
                          ),
                          size: 24,
                        ),
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

  Widget _buildStatsView() {
    // Automatically get all games with analytics from exercises
    // When adding a new game:
    // 1. Add gameId mapping in _getGameIdFromExerciseId()
    // 2. Add game name mapping in _getGameNameFromGameId()
    // 3. The game will automatically appear here!
    final gamesWithAnalytics = _getGamesWithAnalytics();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            ...gamesWithAnalytics.asMap().entries.map((entry) {
              final index = entry.key;
              final game = entry.value;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AnalyticsPage(
                        gameId: game['id']!,
                        gameName: game['name']!,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${index + 1}. ${game['name']!}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPillNavigationBar() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPillNavItem(
                      Icons.home_rounded,
                      'Home',
                      _selectedTab == 0,
                      () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                    ),
                    _buildPillNavItem(
                      Icons.bar_chart_rounded,
                      'Stats',
                      _selectedTab == 2,
                      () {
                        setState(() {
                          _selectedTab = 2;
                        });
                      },
                    ),
                    _buildPillNavItem(
                      Icons.person_rounded,
                      'Profile',
                      _selectedTab == 3,
                      () {
                        setState(() {
                          _selectedTab = 3;
                          // Close search field when switching to profile
                          if (_showSearchField) {
                            _showSearchField = false;
                            _searchController.clear();
                            _isSearching = false;
                            _filteredExercises = _allExercises;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _exerciseTab = 0;
              });
              _filterExercises();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: _exerciseTab == 0
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
                _exerciseTab = 1;
              });
              _filterExercises();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: _exerciseTab == 1
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

  Widget _buildPillNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isActive
                  ? const Color(
                      0xFF6366F1,
                    ) // Purple for active (same as login button)
                  : const Color(0xFF64748B), // Grey for inactive
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(
                        0xFF6366F1,
                      ) // Purple for active (same as login button)
                    : const Color(0xFF64748B), // Grey for inactive
              ),
            ),
          ],
        ),
      ),
    );
  }
}

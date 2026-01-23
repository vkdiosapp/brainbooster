import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/exercise.dart';
import '../data/exercise_data.dart';
import '../services/game_history_service.dart';
import 'pages/category_exercises_page.dart';
import 'pages/login_page.dart';
import 'pages/settings_page.dart';
import 'pages/analytics_page.dart';
import 'navigation/exercise_navigator.dart';
import 'widgets/gradient_background.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterExercises);
  }

  void _loadData() {
    setState(() {
      _categories = ExerciseData.getCategories();
      _allExercises = ExerciseData.getExercises();
      _randomExercises = ExerciseData.getRandomExercises(3);
      _filteredExercises = _allExercises;
    });
    // Start auto-scroll after data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBannerAutoScroll();
    });
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
      if (query.isEmpty) {
        _filteredExercises = _allExercises;
        _isSearching = false;
      } else {
        _filteredExercises = _allExercises
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
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: PageView.builder(
                                    controller: _bannerController,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentBannerIndex = index;
                                      });
                                    },
                                    itemCount: _randomExercises.length,
                                    itemBuilder: (context, index) {
                                      final exercise = _randomExercises[index];
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
                                    index + 1,
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
      bottomNavigationBar: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', _selectedTab == 0, () {
                setState(() {
                  _selectedTab = 0;
                });
              }),
              _buildNavItem(Icons.bar_chart, 'Stats', _selectedTab == 2, () {
                setState(() {
                  _selectedTab = 2;
                });
              }),
              _buildNavItem(Icons.person, 'Profile', _selectedTab == 3, () {
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
              }),
            ],
          ),
        ),
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
                            Container(
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
                            const SizedBox(width: 8),
                            Container(
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
                                Icons.star,
                                color: Colors.white,
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

    return GestureDetector(
      onTap: () {
        ExerciseNavigator.navigateToExercise(context, exercise.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (exercise.isPro)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise.desc,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Graph icon (only if game has history)
            if (gameId != null)
              FutureBuilder<List<dynamic>>(
                future: GameHistoryService.getSessions(gameId),
                builder: (context, snapshot) {
                  final hasHistory =
                      snapshot.hasData && snapshot.data!.isNotEmpty;
                  if (!hasHistory) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
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
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.show_chart,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            exercise.isPro
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock, color: Color(0xFF94A3B8)),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Color(0xFF6366F1),
                    ),
                  ),
          ],
        ),
      ),
    );
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
            ...gamesWithAnalytics.map((game) {
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
                        game['name']!,
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

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF6366F1) : Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFF6366F1) : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

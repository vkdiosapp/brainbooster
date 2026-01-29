import 'package:flutter/material.dart';
import '../language_selection_page.dart';
import '../game_settings.dart';
import '../services/game_history_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Widget _buildSettingsCard({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.borderColor(context), width: 1),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GradientBackground.getBackgroundColor(context),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Back button - match Analytics page style
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: AppTheme.iconColor(context),
                        ),
                      ),
                    ),
                    // Spacer to center the title
                    const Spacer(),
                    // Title - centered on screen
                    Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    // Spacer to balance the back button
                    const Spacer(),
                    // Invisible placeholder to balance the back button width
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Settings list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  children: [
                    // Language option
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSettingsCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LanguageSelectionPage(),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWithOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.language,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Language',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppTheme.iconSecondary(context),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Theme toggle
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeService.themeModeNotifier,
                        builder: (context, themeMode, _) {
                          final isDark = themeMode == ThemeMode.dark;
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
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
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryWithOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isDark ? Icons.dark_mode : Icons.light_mode,
                                    color: const Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Dark Theme',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ),
                                // Toggle switch
                                Switch(
                                  value: isDark,
                                  onChanged: (value) {
                                    ThemeService.setThemeMode(
                                      value ? ThemeMode.dark : ThemeMode.light,
                                    );
                                  },
                                  activeColor: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Sound toggle
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: GameSettings.soundEnabledNotifier,
                        builder: (context, soundEnabled, _) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
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
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryWithOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.volume_up,
                                    color: Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Sound',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ),
                                // Toggle switch
                                Switch(
                                  value: soundEnabled,
                                  onChanged: (value) {
                                    GameSettings.setSoundEnabled(value);
                                  },
                                  activeColor: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Number of repetitions in game
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ValueListenableBuilder<int>(
                        valueListenable: GameSettings.repetitionsNotifier,
                        builder: (context, repetitions, _) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
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
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryWithOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.repeat,
                                    color: Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Number of repetition in game',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ),
                                // Decrease button
                                IconButton(
                                  onPressed: () {
                                    if (repetitions > 1) {
                                      GameSettings.setNumberOfRepetitions(
                                        repetitions - 1,
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    Icons.remove,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Number display
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryWithOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    repetitions.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Increase button
                                IconButton(
                                  onPressed: () {
                                    GameSettings.setNumberOfRepetitions(
                                      repetitions + 1,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.add,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Clear Analytics Data option
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSettingsCard(
                        onTap: () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Theme.of(context).cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Clear Analytics Data',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to delete all analytics data for all games? This action cannot be undone.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(
                                    'Clear',
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await GameHistoryService.clearAllAnalyticsData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Analytics data cleared successfully',
                                    ),
                                    backgroundColor: Color(0xFF10B981),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error clearing data: $e'),
                                    backgroundColor: const Color(0xFFEF4444),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Clear Analytics Data',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
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
}

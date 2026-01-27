import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/round_result.dart';
import '../data/exercise_data.dart';
import '../services/sound_service.dart';
import '../widgets/gradient_background.dart';

/// Helper function to get exercise ID from game ID
int? _getExerciseIdFromGameId(String gameId) {
  switch (gameId) {
    case 'color_change':
      return 1;
    case 'find_number':
      return 2;
    case 'catch_ball':
      return 3;
    case 'find_color':
      return 4;
    case 'catch_color':
      return 5;
    case 'quick_math':
      return 6;
    case 'figure_change':
      return 7;
    case 'sound':
      return 8;
    case 'sensation':
      return 9;
    case 'sequence_rush':
      return 10;
    case 'ball_rush':
      return 11;
    case 'ball_track':
      return 12;
    case 'visual_memory':
      return 13;
    case 'swipe':
      return 14;
      case 'excess_cells':
        return 15;
      case 'peripheral_vision':
        return 18;
      case 'longest_line':
        return 19;
      default:
        return null;
  }
}

class ColorChangeResultsPage extends StatefulWidget {
  final List<RoundResult> roundResults;
  final int bestSession;
  final String gameName;
  final String? gameId;
  final int? exerciseId;

  const ColorChangeResultsPage({
    super.key,
    required this.roundResults,
    required this.bestSession,
    required this.gameName,
    this.gameId,
    this.exerciseId,
  });

  @override
  State<ColorChangeResultsPage> createState() => _ColorChangeResultsPageState();
}

class _ColorChangeResultsPageState extends State<ColorChangeResultsPage> {
  @override
  void initState() {
    super.initState();
    // Play result sound when page opens
    SoundService.playResultSound();
  }

  int _calculateAverage() {
    if (widget.roundResults.isEmpty) return 0;
    // Include all rounds (including failed ones with penalty) in average
    return widget.roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
        widget.roundResults.length;
  }

  String _formatMilliseconds(int ms) {
    return ms.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final averageTime = _calculateAverage();
    // Get Color Change exercise (id: 1) to get timeRequired
    final colorChangeExercise = ExerciseData.getExercises().firstWhere(
      (e) => e.id == 1,
      orElse: () => ExerciseData.getExercises().first,
    );
    final timeRequired = colorChangeExercise.timeRequired;

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
                    // Back button - left aligned with frosted glass effect
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                              blurStyle: BlurStyle.inner,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF475569),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Spacer to center the title
                    const Spacer(),
                    // Title - centered on screen
                    Column(
                      children: [
                        const Text(
                          'RESULT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          () {
                            final exerciseId = widget.exerciseId ?? 
                                (widget.gameId != null ? _getExerciseIdFromGameId(widget.gameId!) : null);
                            return exerciseId != null
                                ? '$exerciseId - ${widget.gameName.toUpperCase()}'
                                : widget.gameName.toUpperCase();
                          }(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    // Spacer to balance the back button
                    const Spacer(),
                    // Invisible placeholder to balance the back button width
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      // Average Result Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'AVERAGE RESULT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.5,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_formatMilliseconds(averageTime)} milliseconds',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              averageTime < timeRequired
                                  ? 'GREAT JOB! YOU MET THE TARGET.'
                                  : 'TRY AGAIN, YOU CAN DO BETTER. THE AVERAGE TIME IS REQUIRED TO BE LESS THAN ${_formatMilliseconds(timeRequired)} MILLISECONDS',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Repetitions List
                      ...widget.roundResults.map((result) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Text(
                                'REPETITION ${result.roundNumber}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                result.isFailed
                                    ? '${_formatMilliseconds(result.reactionTime)} ms (FAILED)'
                                    : '${_formatMilliseconds(result.reactionTime)} ms',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: result.isFailed
                                      ? Colors.red
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              // Bottom Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    // GO TO MENU Button
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Navigate to home page
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'GO TO MENU',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // TRY AGAIN Button
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Navigate back to color change page (will reset)
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'TRY AGAIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
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

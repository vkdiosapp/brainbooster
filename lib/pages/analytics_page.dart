import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../widgets/gradient_background.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Helper widget for glassy container effect similar to GameContainer
class _GlassyContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const _GlassyContainer({
    required this.child,
    this.backgroundColor,
    this.borderRadius = 32,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (backgroundColor ?? Colors.white).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AnalyticsPage extends StatefulWidget {
  final String gameId;
  final String gameName;

  const AnalyticsPage({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<GameSession> _sessions = [];
  List<GameSession> _last10Sessions = [];
  int _averageTime = 0;
  int _bestTime = 0;
  double _consistency = 0.0;
  bool _isLoading = true;
  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _isClickLimitGame => widget.gameId == 'click_limit';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final sessions = await GameHistoryService.getSessions(widget.gameId);
    final last10 = await GameHistoryService.getLast10Sessions(widget.gameId);
    final average = await GameHistoryService.getAverageTime(widget.gameId);
    final best = await GameHistoryService.getBestTime(widget.gameId);
    final consistency = await GameHistoryService.getConsistency(widget.gameId);

    setState(() {
      _sessions = sessions;
      _last10Sessions = last10;
      _averageTime = average;
      _bestTime = best;
      _consistency = consistency;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today, ${DateFormat('HH:mm').format(date)}';
    } else if (sessionDate == yesterday) {
      return 'Yesterday, ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(date);
    }
  }

  int _getPreviousAverage() {
    if (_last10Sessions.length < 2) return _averageTime;
    // Get average of sessions 2-10 (excluding the most recent)
    final previousSessions = _last10Sessions.skip(1).take(9).toList();
    if (previousSessions.isEmpty) return _averageTime;

    final allTimes = previousSessions
        .expand((s) => s.roundResults.map((r) => r.reactionTime))
        .toList();
    if (allTimes.isEmpty) return _averageTime;

    return allTimes.reduce((a, b) => a + b) ~/ allTimes.length;
  }

  Future<void> _shareScreenshot() async {
    try {
      // Capture screenshot
      final image = await _screenshotController.capture();
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture screenshot')),
          );
        }
        return;
      }

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final file = await File(
        '${tempDir.path}/analytics_screenshot.png',
      ).create();
      await file.writeAsBytes(image);

      // Get share button position for iOS/macOS share sheet
      Rect? sharePositionOrigin;
      if (_shareButtonKey.currentContext != null) {
        final RenderBox renderBox =
            _shareButtonKey.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        sharePositionOrigin = Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        );
      }

      // Share the screenshot
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.gameName} - Performance Analysis',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GradientBackground.getBackgroundColor(context),
      body: _isLoading
          ? GradientBackground(
              child: const Center(child: CircularProgressIndicator()),
            )
          : Screenshot(
              controller: _screenshotController,
              child: Container(
                color: GradientBackground.getBackgroundColor(context),
                child: GradientBackground(
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
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.gameName,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      'PERFORMANCE ANALYSIS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSecondary(context),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _shareScreenshot,
                                child: Container(
                                  key: _shareButtonKey,
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.buttonBackground(context),
                                  ),
                                  child: Icon(
                                    Icons.share,
                                    size: 20,
                                    color: AppTheme.iconColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Main content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                // Chart card
                                _GlassyContainer(
                                  borderRadius: 40,
                                  padding: const EdgeInsets.all(24),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _isClickLimitGame
                                                    ? 'Average Taps'
                                                    : 'Reaction Time (ms)',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _last10Sessions.isEmpty
                                                    ? 'No sessions yet'
                                                    : _last10Sessions.length <
                                                          10
                                                    ? 'Last ${_last10Sessions.length} ${_last10Sessions.length == 1 ? 'session' : 'sessions'}'
                                                    : 'Last 10 sessions',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF6366F1,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 192,
                                        child: _buildChart(),
                                      ),
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 24,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: _last10Sessions.isEmpty
                                              ? [
                                                  Text(
                                                    'Ses 01',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF94A3B8),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ]
                                              : _last10Sessions
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                      return Text(
                                                        'Ses ${entry.value.sessionNumber.toString().padLeft(2, '0')}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Color(
                                                            0xFF94A3B8,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      );
                                                    })
                                                    .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Stats cards - 3 in a row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _GlassyContainer(
                                        borderRadius: 24,
                                        padding: const EdgeInsets.all(16),
                                        border: Border.all(
                                          color: const Color(0xFFF1F5F9),
                                          width: 1,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'AVERAGE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF94A3B8),
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '$_averageTime',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _isClickLimitGame
                                                        ? ' clicks'
                                                        : 'ms',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF94A3B8),
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _GlassyContainer(
                                        backgroundColor: const Color(
                                          0xFF6366F1,
                                        ),
                                        borderRadius: 24,
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'BEST',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFC7D2FE),
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '$_bestTime',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _isClickLimitGame
                                                        ? ' clicks'
                                                        : 'ms',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFFC7D2FE),
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _GlassyContainer(
                                        borderRadius: 24,
                                        padding: const EdgeInsets.all(16),
                                        border: Border.all(
                                          color: const Color(0xFFF1F5F9),
                                          width: 1,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'CONSISTENCY',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF94A3B8),
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '${_consistency.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '%',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: const Color(
                                                        0xFF0F172A,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const SizedBox(height: 24),
                                // Progress Insight card
                                _GlassyContainer(
                                  backgroundColor: const Color(0xFFECFDF5),
                                  borderRadius: 32,
                                  padding: const EdgeInsets.all(20),
                                  border: Border.all(
                                    color: const Color(0xFFD1FAE5),
                                    width: 1,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.trending_up,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Progress Insight',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF065F46),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _sessions.length >= 2
                                                  ? !_isClickLimitGame
                                                        ? 'Incredible work! You are ${((_getPreviousAverage() - _averageTime) / _getPreviousAverage() * 100).abs().toStringAsFixed(0)}% ${_averageTime < _getPreviousAverage() ? "faster" : "slower"} than your previous average. Keep this momentum to break your all-time record.'
                                                        : (() {
                                                            final prevAvg =
                                                                _getPreviousAverage();
                                                            if (prevAvg <= 0) {
                                                              return 'Keep playing to see your progress!';
                                                            }
                                                            final diffPercent =
                                                                ((_averageTime -
                                                                            prevAvg) /
                                                                        prevAvg *
                                                                        100)
                                                                    .abs()
                                                                    .toStringAsFixed(
                                                                      0,
                                                                    );
                                                            final isBetter =
                                                                _averageTime >
                                                                prevAvg;
                                                            return 'Great effort! You are $diffPercent% ${isBetter ? "above" : "below"} your previous average tap count. Aim for more taps to keep improving.';
                                                          })()
                                                  : 'Keep playing to see your progress!',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF047857),
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Session History
                                Text(
                                  'Session History',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _GlassyContainer(
                                  borderRadius: 24,
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1,
                                  ),
                                  child: _sessions.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(40),
                                          child: Center(
                                            child: Text(
                                              'No sessions yet.\nPlay the game to see your stats!',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: _sessions.take(10).map((
                                            session,
                                          ) {
                                            final index = _sessions.indexOf(
                                              session,
                                            );
                                            final isLast =
                                                index ==
                                                _sessions.take(10).length - 1;
                                            final previousSession =
                                                index < _sessions.length - 1
                                                ? _sessions[index + 1]
                                                : null;

                                            // Calculate average from all rounds (including penalties)
                                            final sessionAvg =
                                                session.roundResults.isEmpty
                                                ? 0
                                                : (session.roundResults
                                                          .map(
                                                            (r) =>
                                                                r.reactionTime,
                                                          )
                                                          .reduce(
                                                            (a, b) => a + b,
                                                          ) ~/
                                                      session
                                                          .roundResults
                                                          .length);

                                            final previousAvg =
                                                previousSession != null
                                                ? (previousSession
                                                          .roundResults
                                                          .isEmpty
                                                      ? 0
                                                      : (previousSession
                                                                .roundResults
                                                                .map(
                                                                  (r) => r
                                                                      .reactionTime,
                                                                )
                                                                .reduce(
                                                                  (a, b) =>
                                                                      a + b,
                                                                ) ~/
                                                            previousSession
                                                                .roundResults
                                                                .length))
                                                : sessionAvg;
                                            final diff =
                                                sessionAvg - previousAvg;

                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                border: isLast
                                                    ? null
                                                    : Border(
                                                        bottom: BorderSide(
                                                          color: const Color(
                                                            0xFFE2E8F0,
                                                          ),
                                                          width: 1,
                                                        ),
                                                      ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color:
                                                                  const Color(
                                                                    0xFFF1F5F9,
                                                                  ),
                                                            ),
                                                        child: Center(
                                                          child: Text(
                                                            session
                                                                .sessionNumber
                                                                .toString()
                                                                .padLeft(
                                                                  2,
                                                                  '0',
                                                                ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color(
                                                                    0xFF64748B,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            _formatDate(
                                                              session.timestamp,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color(
                                                                    0xFF0F172A,
                                                                  ),
                                                                ),
                                                          ),
                                                          Text(
                                                            'Session #${session.sessionNumber.toString().padLeft(2, "0")}',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Color(
                                                                    0xFF94A3B8,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        _isClickLimitGame
                                                            ? '$sessionAvg clicks'
                                                            : '${sessionAvg}ms',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: diff < 0
                                                              ? const Color(
                                                                  0xFF6366F1,
                                                                )
                                                              : const Color(
                                                                  0xFF0F172A,
                                                                ),
                                                        ),
                                                      ),
                                                      if (previousSession !=
                                                          null)
                                                        Text(
                                                          _isClickLimitGame
                                                              ? '${diff < 0 ? "-" : "+"}${diff.abs()} taps'
                                                              : '${diff < 0 ? "-" : "+"}${diff.abs()}ms',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: diff < 0
                                                                ? const Color(
                                                                    0xFF10B981,
                                                                  )
                                                                : const Color(
                                                                    0xFFEF4444,
                                                                  ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),
                                const SizedBox(height: 96),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildChart() {
    if (_last10Sessions.isEmpty) {
      return Center(
        child: Text('No data yet', style: TextStyle(color: Colors.grey[400])),
      );
    }

    // Get average times for each session
    final dataPoints = _last10Sessions
        .map((session) {
          if (session.roundResults.isEmpty) return 0.0;
          final sum = session.roundResults
              .map((r) => r.reactionTime)
              .reduce((a, b) => a + b);
          final count = session.roundResults.length;
          if (count == 0) return 0.0;
          return sum / count;
        })
        .where((point) => point.isFinite && !point.isNaN)
        .toList();

    if (dataPoints.isEmpty) {
      return Center(
        child: Text('No valid data', style: TextStyle(color: Colors.grey[400])),
      );
    }

    // Normalize data points to fit in 0-100 range (higher values = higher on chart)
    final maxTime = dataPoints.reduce((a, b) => a > b ? a : b);
    final minTime = dataPoints.reduce((a, b) => a < b ? a : b);
    final range = maxTime - minTime;

    final normalizedPoints = dataPoints.map((point) {
      if (range == 0 || !range.isFinite) return 50.0;
      // Higher reaction time = higher on chart (normal orientation)
      final normalized = ((point - minTime) / range * 80 + 10);
      // Ensure the value is valid
      if (!normalized.isFinite || normalized.isNaN) return 50.0;
      // Clamp between 0 and 100
      return normalized.clamp(0.0, 100.0);
    }).toList();

    // Calculate Y-axis labels (4 evenly spaced values from max (top) to min (bottom))
    final yAxisLabelData = <Map<String, double>>[];

    if (range > 0 && maxTime.isFinite && minTime.isFinite) {
      // Round to nearest 10 for cleaner labels
      final roundedMax = ((maxTime / 10).ceil() * 10).toDouble();
      final roundedMin = ((minTime / 10).floor() * 10).toDouble();
      final step = (roundedMax - roundedMin) / 3;

      // Calculate 4 label values from max (top) to min (bottom)
      for (int i = 0; i < 4; i++) {
        // Start from max and go down to min
        final labelValue = roundedMax - (step * i);

        // Calculate normalized position for this label value (same formula as data points)
        // Higher time = higher normalized value = higher on chart
        final normalized = ((labelValue - minTime) / range * 80 + 10);
        final clampedNormalized = normalized.clamp(0.0, 100.0);

        // Convert normalized (0-100) to Y position in pixels
        // normalized 100 (max) = top (y=0), normalized 0 (min) = bottom (y=192)
        final yPosition = 192 - (clampedNormalized / 100 * 192);

        yAxisLabelData.add({'value': labelValue, 'yPosition': yPosition});
      }
    } else {
      // Handle single data point or zero range case
      final singleValue = maxTime.toDouble();

      // Round the single value to nearest 10
      final roundedValue = ((singleValue / 10).round() * 10).toDouble();

      // Determine spacing based on value magnitude
      final spacing = roundedValue >= 100 ? 20.0 : 10.0;

      // Create 4 rounded labels with the rounded center value included
      // Position them so the rounded value aligns with chart center (where the data point is)
      final roundedLabels = [
        roundedValue + spacing * 1.5, // Top
        roundedValue + spacing * 0.5, // Upper middle
        roundedValue, // Center - the rounded value itself
        roundedValue - spacing * 0.5, // Lower middle
      ].map((v) => ((v / 10).round() * 10).toDouble()).toList();

      // Position labels: center label (index 2, closest to actual value) at chart center
      // Chart center is at 96px from top (50% of 192px) where the data point is positioned
      final centerY = 96.0; // Center of chart where data point is
      final labelSpacing = 64.0; // Space between adjacent labels

      final positions = [
        (centerY - labelSpacing * 1.5).clamp(0.0, 192.0), // Top label
        (centerY - labelSpacing * 0.5).clamp(0.0, 192.0), // Upper middle label
        centerY, // Center label - aligns with data point
        (centerY + labelSpacing * 0.5).clamp(0.0, 192.0), // Lower middle label
      ];

      for (int i = 0; i < 4; i++) {
        yAxisLabelData.add({
          'value': roundedLabels[i],
          'yPosition': positions[i],
        });
      }
    }

    return Stack(
      children: [
        // Chart area - full width to align with session labels
        CustomPaint(
          painter: ChartPainter(normalizedPoints, leftPadding: 24),
          child: Container(),
        ),
        // Y-axis labels positioned at correct chart positions
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: SizedBox(
            width: 24, // Constrain width for Y-axis labels
            height: 192, // Match chart height
            child: Stack(
              children: yAxisLabelData.map((labelData) {
                final value = labelData['value']!;
                final yPos = labelData['yPosition']!;

                return Positioned(
                  top: yPos - 8, // Center the text vertically (text height ~16)
                  child: Text(
                    value.round().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> points;
  final double leftPadding;

  ChartPainter(this.points, {this.leftPadding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Filter out invalid points
    final validPoints = points.where((p) => p.isFinite && !p.isNaN).toList();
    if (validPoints.isEmpty) return;

    // Calculate chart area (excluding left padding)
    final chartWidth = (size.width - leftPadding).clamp(0.0, double.infinity);
    final chartStartX = leftPadding;

    // Safety check: ensure we have valid chart dimensions
    if (chartWidth <= 0) return;

    // Create gradient paint
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Create gradient shader across chart area
    final gradientEndX = chartStartX + chartWidth;
    if (gradientEndX > chartStartX && chartWidth > 0) {
      final gradient = ui.Gradient.linear(
        Offset(chartStartX, 0),
        Offset(gradientEndX.clamp(chartStartX, size.width), 0),
        const [
          Color(0xFF8B5CF6), // Purple
          Color(0xFF3B82F6), // Blue
        ],
      );
      paint.shader = gradient;
    } else {
      // Fallback: use solid color if gradient can't be created
      paint.color = const Color(0xFF3B82F6);
    }

    final path = Path();

    // Handle single point case
    if (validPoints.length == 1) {
      final x = chartStartX + chartWidth / 2;
      final y = size.height - (validPoints[0] / 100 * size.height);
      if (x.isFinite && y.isFinite && !x.isNaN && !y.isNaN) {
        path.moveTo(x, y);
        canvas.drawPath(path, paint);
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()
            ..color = const Color(0xFF3B82F6)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      return;
    }

    final stepX = chartWidth / (validPoints.length - 1);
    if (!stepX.isFinite || stepX.isNaN) return;

    for (int i = 0; i < validPoints.length; i++) {
      final x = chartStartX + i * stepX;
      final y = size.height - (validPoints[i] / 100 * size.height);

      // Validate coordinates before using
      if (!x.isFinite || x.isNaN || !y.isFinite || y.isNaN) continue;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = chartStartX + (i - 1) * stepX;
        final prevY = size.height - (validPoints[i - 1] / 100 * size.height);

        // Validate all control points
        if (!prevX.isFinite || prevX.isNaN || !prevY.isFinite || prevY.isNaN)
          continue;

        final controlX1 = prevX + stepX * 0.5;
        final controlY1 = prevY;
        final controlX2 = x - stepX * 0.5;
        final controlY2 = y;

        // Validate control points
        if (controlX1.isFinite &&
            !controlX1.isNaN &&
            controlY1.isFinite &&
            !controlY1.isNaN &&
            controlX2.isFinite &&
            !controlX2.isNaN &&
            controlY2.isFinite &&
            !controlY2.isNaN) {
          path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Draw circle on every data point (including last point)
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    canvas.drawPath(path, paint);

    // Draw grid lines across chart area
    final gridPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(chartStartX, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

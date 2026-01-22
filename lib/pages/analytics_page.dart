import 'package:flutter/material.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
    
    final allTimes = previousSessions.expand((s) => s.roundResults.map((r) => r.reactionTime)).toList();
    if (allTimes.isEmpty) return _averageTime;
    
    return allTimes.reduce((a, b) => a + b) ~/ allTimes.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                              color: Color(0xFF0F172A),
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'BENTO ANALYSIS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                          ),
                          child: const Icon(
                            Icons.share,
                            size: 20,
                            color: Color(0xFF0F172A),
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
                          // Chart card
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Reaction Time (ms)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Last 10 sessions',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.show_chart,
                                        size: 16,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 176,
                                  child: _buildChart(),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'S.${_last10Sessions.length >= 1 ? _last10Sessions.length : "01"}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'S.${_last10Sessions.length >= 5 ? "05" : "01"}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'S.${_last10Sessions.length >= 10 ? "10" : _last10Sessions.length.toString().padLeft(2, "0")}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Average and Best cards
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: const Color(0xFFF1F5F9),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$_averageTime',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'ms',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withOpacity(0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$_bestTime',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'ms',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFFC7D2FE),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Consistency card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Text(
                                      '${_consistency.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    children: [
                                      CircularProgressIndicator(
                                        value: _consistency / 100,
                                        strokeWidth: 4,
                                        backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                      ),
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                          child: const Icon(
                                            Icons.verified,
                                            size: 20,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Progress Insight card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: const Color(0xFFD1FAE5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(12),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                            ? 'You are ${((_getPreviousAverage() - _averageTime) / _getPreviousAverage() * 100).abs().toStringAsFixed(0)}% ${_averageTime < _getPreviousAverage() ? "faster" : "slower"} than your average!'
                                            : 'Keep playing to see your progress!',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Recent Sessions
                          const Text(
                            'RECENT SESSIONS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1,
                              ),
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
                                    children: _sessions.take(10).map((session) {
                                      final index = _sessions.indexOf(session);
                                      final isLast = index == _sessions.take(10).length - 1;
                                      final previousSession = index < _sessions.length - 1
                                          ? _sessions[index + 1]
                                          : null;
                                      final previousAvg = previousSession != null
                                          ? (previousSession.roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/ previousSession.roundResults.length)
                                          : session.averageTime;
                                      final diff = session.averageTime - previousAvg;
                                      
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: isLast
                                              ? null
                                              : Border(
                                                  bottom: BorderSide(
                                                    color: const Color(0xFFF8FAFC),
                                                    width: 1,
                                                  ),
                                                ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: const Color(0xFFF1F5F9),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      session.sessionNumber.toString().padLeft(2, '0'),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _formatDate(session.timestamp),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    Text(
                                                      'Session #${session.sessionNumber.toString().padLeft(2, "0")}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Color(0xFF94A3B8),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${session.averageTime}ms',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: diff < 0
                                                        ? const Color(0xFF6366F1)
                                                        : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                if (previousSession != null)
                                                  Text(
                                                    '${diff < 0 ? "-" : "+"}${diff.abs()}ms',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: diff < 0
                                                          ? const Color(0xFF10B981)
                                                          : const Color(0xFFEF4444),
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
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChart() {
    if (_last10Sessions.isEmpty) {
      return Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    // Get average times for each session
    final dataPoints = _last10Sessions.map((session) {
      if (session.roundResults.isEmpty) return 0.0;
      final sum = session.roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b);
      final count = session.roundResults.length;
      if (count == 0) return 0.0;
      return sum / count;
    }).where((point) => point.isFinite && !point.isNaN).toList();

    if (dataPoints.isEmpty) {
      return Center(
        child: Text(
          'No valid data',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    // Normalize data points to fit in 0-100 range (inverted for chart - lower is better)
    final maxTime = dataPoints.reduce((a, b) => a > b ? a : b);
    final minTime = dataPoints.reduce((a, b) => a < b ? a : b);
    final range = maxTime - minTime;
    
    final normalizedPoints = dataPoints.map((point) {
      if (range == 0 || !range.isFinite) return 50.0;
      // Invert: lower reaction time = higher on chart
      final normalized = 100 - ((point - minTime) / range * 80 + 10);
      // Ensure the value is valid
      if (!normalized.isFinite || normalized.isNaN) return 50.0;
      // Clamp between 0 and 100
      return normalized.clamp(0.0, 100.0);
    }).toList();

    return CustomPaint(
      painter: ChartPainter(normalizedPoints),
      child: Container(),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> points;

  ChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Filter out invalid points
    final validPoints = points.where((p) => p.isFinite && !p.isNaN).toList();
    if (validPoints.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Handle single point case
    if (validPoints.length == 1) {
      final x = size.width / 2;
      final y = size.height - (validPoints[0] / 100 * size.height);
      if (x.isFinite && y.isFinite && !x.isNaN && !y.isNaN) {
        path.moveTo(x, y);
        canvas.drawPath(path, paint);
        canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()
            ..color = const Color(0xFF3B82F6)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      return;
    }

    final stepX = size.width / (validPoints.length - 1);
    if (!stepX.isFinite || stepX.isNaN) return;

    for (int i = 0; i < validPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (validPoints[i] / 100 * size.height);

      // Validate coordinates before using
      if (!x.isFinite || x.isNaN || !y.isFinite || y.isNaN) continue;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (validPoints[i - 1] / 100 * size.height);
        
        // Validate all control points
        if (!prevX.isFinite || prevX.isNaN || !prevY.isFinite || prevY.isNaN) continue;
        
        final controlX1 = prevX + stepX * 0.5;
        final controlY1 = prevY;
        final controlX2 = x - stepX * 0.5;
        final controlY2 = y;
        
        // Validate control points
        if (controlX1.isFinite && !controlX1.isNaN &&
            controlY1.isFinite && !controlY1.isNaN &&
            controlX2.isFinite && !controlX2.isNaN &&
            controlY2.isFinite && !controlY2.isNaN) {
          path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(path, paint);

    // Draw point on last data point
    if (validPoints.isNotEmpty) {
      final lastX = (validPoints.length - 1) * stepX;
      final lastY = size.height - (validPoints.last / 100 * size.height);
      
      // Validate before drawing circle
      if (lastX.isFinite && !lastX.isNaN && lastY.isFinite && !lastY.isNaN) {
        canvas.drawCircle(
          Offset(lastX, lastY),
          3.5,
          Paint()
            ..color = const Color(0xFF3B82F6)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(lastX, lastY),
          3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

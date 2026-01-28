import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_session.dart';

class GameHistoryService {
  static const String _historyKeyPrefix = 'game_history_';

  // Save a game session
  static Future<void> saveSession(GameSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_historyKeyPrefix${session.gameId}';
      
      // Get existing sessions
      final existingJson = prefs.getString(key);
      List<GameSession> sessions = [];
      
      if (existingJson != null) {
        final List<dynamic> decoded = json.decode(existingJson);
        sessions = decoded.map((s) => GameSession.fromJson(s as Map<String, dynamic>)).toList();
      }
      
      // Add new session
      sessions.add(session);
      
      // Save back
      final encoded = json.encode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(key, encoded);
    } catch (e) {
      print('Error saving game session: $e');
    }
  }

  // Get all sessions for a specific game
  static Future<List<GameSession>> getSessions(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_historyKeyPrefix$gameId';
      final json = prefs.getString(key);
      
      if (json == null) return [];
      
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.map((s) => GameSession.fromJson(s as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort by newest first
    } catch (e) {
      print('Error loading game sessions: $e');
      return [];
    }
  }

  // Get the last 10 sessions for a game (for chart)
  static Future<List<GameSession>> getLast10Sessions(String gameId) async {
    final sessions = await getSessions(gameId);
    return sessions.take(10).toList();
  }

  // Get average reaction time from all sessions
  // This calculates the average of all individual rounds (including penalties)
  // to match the result page behavior
  static Future<int> getAverageTime(String gameId) async {
    final sessions = await getSessions(gameId);
    if (sessions.isEmpty) return 0;
    
    // Get all round results from all sessions (including failed ones with penalties)
    final allRoundResults = sessions.expand((s) => s.roundResults).toList();
    if (allRoundResults.isEmpty) return 0;
    
    // Calculate average from all rounds (including penalties)
    final sum = allRoundResults
        .map((r) => r.reactionTime)
        .reduce((a, b) => a + b);
    
    return sum ~/ allRoundResults.length;
  }

  // Get best time from all sessions
  static Future<int> getBestTime(String gameId) async {
    final sessions = await getSessions(gameId);
    if (sessions.isEmpty) return 0;
    
    final allTimes = sessions.expand((s) => s.roundResults.where((r) => !r.isFailed).map((r) => r.reactionTime)).toList();
    if (allTimes.isEmpty) return 0;
    
    return allTimes.reduce((a, b) => a < b ? a : b);
  }

  // Calculate consistency percentage (how many rounds were successful)
  static Future<double> getConsistency(String gameId) async {
    final sessions = await getSessions(gameId);
    if (sessions.isEmpty) return 0.0;
    
    int totalRounds = 0;
    int successfulRounds = 0;
    
    for (var session in sessions) {
      totalRounds += session.roundResults.length;
      successfulRounds += session.roundResults.where((r) => !r.isFailed).length;
    }
    
    if (totalRounds == 0) return 0.0;
    return (successfulRounds / totalRounds) * 100;
  }

  // Get session number for next session
  static Future<int> getNextSessionNumber(String gameId) async {
    final sessions = await getSessions(gameId);
    if (sessions.isEmpty) return 1;
    return sessions.length + 1;
  }

  // Clear all analytics data for all games
  static Future<void> clearAllAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Remove all keys that start with the history prefix
      for (final key in keys) {
        if (key.startsWith(_historyKeyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Error clearing analytics data: $e');
      rethrow;
    }
  }
}

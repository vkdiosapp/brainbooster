import 'round_result.dart';

class GameSession {
  final String gameId; // e.g., "color_change", "find_number"
  final String gameName; // e.g., "Color Change", "Find Number"
  final DateTime timestamp;
  final int sessionNumber;
  final List<RoundResult> roundResults;
  final int averageTime;
  final int bestTime;

  GameSession({
    required this.gameId,
    required this.gameName,
    required this.timestamp,
    required this.sessionNumber,
    required this.roundResults,
    required this.averageTime,
    required this.bestTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'gameName': gameName,
      'timestamp': timestamp.toIso8601String(),
      'sessionNumber': sessionNumber,
      'roundResults': roundResults.map((r) => {
        'roundNumber': r.roundNumber,
        'reactionTime': r.reactionTime,
        'isFailed': r.isFailed,
      }).toList(),
      'averageTime': averageTime,
      'bestTime': bestTime,
    };
  }

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      gameId: json['gameId'] as String,
      gameName: json['gameName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionNumber: json['sessionNumber'] as int,
      roundResults: (json['roundResults'] as List)
          .map((r) {
            final map = r as Map<String, dynamic>;
            return RoundResult(
              roundNumber: map['roundNumber'] as int,
              reactionTime: map['reactionTime'] as int,
              isFailed: map['isFailed'] as bool,
            );
          })
          .toList(),
      averageTime: json['averageTime'] as int,
      bestTime: json['bestTime'] as int,
    );
  }
}

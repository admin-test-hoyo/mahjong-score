import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calculator.dart';
import '../../core/models/app_config.dart';
import '../../core/database/database_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class GameRecord {
  final String id;
  final List<PlayerInput> inputs;
  final int startingOyaIndex;

  const GameRecord({
    required this.id, 
    required this.inputs,
    this.startingOyaIndex = 0,
  });

  GameRecord copyWith({
    String? id, 
    List<PlayerInput>? inputs,
    int? startingOyaIndex,
  }) {
    return GameRecord(
      id: id ?? this.id,
      inputs: inputs ?? this.inputs,
      startingOyaIndex: startingOyaIndex ?? this.startingOyaIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inputs': inputs.map((e) => e.toJson()).toList(),
    'startingOyaIndex': startingOyaIndex,
  };

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    return GameRecord(
      id: json['id'] as String,
      inputs: (json['inputs'] as List<dynamic>?)?.map((e) => PlayerInput.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      startingOyaIndex: json['startingOyaIndex'] as int? ?? 0,
    );
  }
}

// UI State that holds multiple game records
class CalcState {
  final List<String> playerNames;
  final List<int> globalChips; // [p1, p2, p3, p4]
  final List<GameRecord> games;
  final MahjongRule rule;
  final int? selectedGroupId;

  const CalcState({
    this.playerNames = const ['A', 'B', 'C', 'D'],
    this.globalChips = const [0, 0, 0, 0],
    required this.games,
    this.rule = const MahjongRule(),
    this.selectedGroupId,
  });

  CalcState copyWith({
    List<String>? playerNames,
    List<int>? globalChips,
    List<GameRecord>? games,
    MahjongRule? rule,
    int? selectedGroupId,
  }) {
    return CalcState(
      playerNames: playerNames ?? this.playerNames,
      globalChips: globalChips ?? this.globalChips,
      games: games ?? this.games,
      rule: rule ?? this.rule,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerNames': playerNames,
    'globalChips': globalChips,
    'games': games.map((e) => e.toJson()).toList(),
    'rule': rule.toJson(),
    'selectedGroupId': selectedGroupId,
  };

  factory CalcState.fromJson(Map<String, dynamic> json) {
    return CalcState(
      playerNames: (json['playerNames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const ['A', 'B', 'C', 'D'],
      globalChips: (json['globalChips'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [0, 0, 0, 0],
      games: (json['games'] as List<dynamic>?)?.map((e) => GameRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      rule: json['rule'] != null ? MahjongRule.fromJson(json['rule'] as Map<String, dynamic>) : const MahjongRule(),
      selectedGroupId: json['selectedGroupId'] as int?,
    );
  }
}

class CalcNotifier extends Notifier<CalcState> {
  @override
  set state(CalcState value) {
    super.state = value;
    try {
      ref.read(sharedPrefsProvider).setString('calcState', jsonEncode(value.toJson()));
    } catch (_) {}
  }

  @override
  CalcState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final str = prefs.getString('calcState');
    if (str != null) {
      try {
        return CalcState.fromJson(jsonDecode(str));
      } catch (_) {}
    }
    return const CalcState(games: []);
  }

  void resetGame() {
    state = CalcState(
      playerNames: const ['A', 'B', 'C', 'D'],
      globalChips: const [0, 0, 0, 0],
      games: const [],
      rule: state.rule,
    );
  }

  GameRecord _createEmptyGame(String id) {
    return GameRecord(
      id: id,
      inputs: const [
        PlayerInput(id: 1, score: 0),
        PlayerInput(id: 2, score: 0),
        PlayerInput(id: 3, score: 0),
        PlayerInput(id: 4, score: 0),
      ]
    );
  }

  void updatePlayerName(int playerId, String name) {
    final newNames = List<String>.from(state.playerNames);
    newNames[playerId - 1] = name;
    state = state.copyWith(playerNames: newNames);
  }

  void updateGlobalChip(int playerId, int chip) {
    final newChips = List<int>.from(state.globalChips);
    newChips[playerId - 1] = chip;
    state = state.copyWith(globalChips: newChips);
  }

  void addGame() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newGames = [...state.games, _createEmptyGame(newId)];
    state = state.copyWith(games: newGames);
  }

  void updateScore(String gameId, int playerId, int score) {
    if (score > 100000) score = 100000;
    if (score < -100000) score = -100000;
    
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      
      var tempInputs = game.inputs.map((p) {
        if (p.id == playerId) {
          int? nextBlownBy = p.blownByPlayerId;
          if (score >= 0) {
            nextBlownBy = null;
          }
          return p.copyWith(score: score, blownByPlayerId: nextBlownBy, clearBlownBy: nextBlownBy == null);
        }
        return p;
      }).toList();

      tempInputs = _recalculateTobi(tempInputs);
      return game.copyWith(inputs: tempInputs);
    }).toList();
    
    state = state.copyWith(games: newGames);
  }

  void updateChip(String gameId, int playerId, int chip) {
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final newInputs = game.inputs.map((p) => p.id == playerId ? PlayerInput(id: playerId, score: p.score, chip: chip, tobiPt: p.tobiPt, yakumanPt: p.yakumanPt) : p).toList();
      return game.copyWith(inputs: newInputs);
    }).toList();
    
    state = state.copyWith(games: newGames);
  }

  void deleteGame(String gameId) {
    final newGames = state.games.where((game) => game.id != gameId).toList();
    state = state.copyWith(games: newGames);
  }

  List<PlayerInput> _recalculateTobi(List<PlayerInput> inputs) {
    final tobiPrize = ref.read(configProvider).tobiPrize;
    return inputs.map((p) {
      int tPt = 0;
      if (p.blownByPlayerId != null) {
        tPt -= tobiPrize;
      }
      final blownCount = inputs.where((other) => other.blownByPlayerId == p.id).length;
      tPt += blownCount * tobiPrize;
      return p.copyWith(tobiPt: tPt);
    }).toList();
  }

  void setBlownBy(String gameId, int loserId, int? winnerId) {
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      
      var tempInputs = game.inputs.map((p) {
        if (p.id == loserId) {
          return p.copyWith(blownByPlayerId: winnerId, clearBlownBy: winnerId == null);
        }
        return p;
      }).toList();
      
      tempInputs = _recalculateTobi(tempInputs);
      return game.copyWith(inputs: tempInputs);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  void setYakumanRon(String gameId, int winnerId, int loserId) {
    final yakumanRonPrize = ref.read(configProvider).yakumanRonPrize;
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final isAlreadySet = game.inputs.any((p) => p.id == winnerId && p.yakumanPt == yakumanRonPrize);

      final newInputs = game.inputs.map((p) {
        if (isAlreadySet) return p.copyWith(yakumanPt: 0);
        if (p.id == winnerId) return p.copyWith(yakumanPt: yakumanRonPrize);
        if (p.id == loserId) return p.copyWith(yakumanPt: -yakumanRonPrize);
        return p.copyWith(yakumanPt: 0);
      }).toList();
      return game.copyWith(inputs: newInputs);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  void setYakumanTsumo(String gameId, int winnerId) {
    final yakumanTsumoPrize = ref.read(configProvider).yakumanTsumoPrize;
    final config = ref.read(configProvider);
    final isThreePlayer = config.isThreePlayer;
    final numPlayers = isThreePlayer ? 3 : 4;
    final totalWin = yakumanTsumoPrize * (numPlayers - 1);

    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final isAlreadySet = game.inputs.any((p) => p.id == winnerId && p.yakumanPt == totalWin);

      final newInputs = game.inputs.map((p) {
        if (isAlreadySet) return p.copyWith(yakumanPt: 0);
        if (p.id == winnerId) return p.copyWith(yakumanPt: totalWin);
        if (isThreePlayer && p.id == 4) return p.copyWith(yakumanPt: 0);
        return p.copyWith(yakumanPt: -yakumanTsumoPrize);
      }).toList();
      return game.copyWith(inputs: newInputs);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  void clearYakuman(String gameId) {
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final newInputs = game.inputs.map((p) => p.copyWith(yakumanPt: 0)).toList();
      return game.copyWith(inputs: newInputs);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  void setStartingOya(String gameId, int playerIndex) {
    if (playerIndex < 0 || playerIndex > 3) return;
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      return game.copyWith(startingOyaIndex: playerIndex);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  void resetGameRecord(String gameId) {
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final newInputs = game.inputs.map((p) => p.copyWith(
        score: 0,
        chip: 0,
        tobiPt: 0,
        yakumanPt: 0,
        blownByPlayerId: null,
        clearBlownBy: true,
      )).toList();
      return game.copyWith(inputs: newInputs);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  List<int> _buildUmaList(String umaText, bool isThreePlayer) {
    final parts = umaText.split('-');
    if (parts.length == 2) {
      final a = int.tryParse(parts[0]) ?? 10;
      final b = int.tryParse(parts[1]) ?? 20;
      return isThreePlayer ? [a + b, -a, -b] : [b, a, -a, -b];
    }
    return isThreePlayer ? [20, 0, -20] : [20, 10, -10, -20];
  }

  Future<void> saveCurrentSession() async {
    final config = ref.read(configProvider);
    final players = config.isThreePlayer ? 3 : 4;
    if (state.games.isEmpty) return;

    // Calculate final stats
    List<List<PlayerResult>> allResults = [];
    for (var g in state.games) {
      if (g.inputs.where((p) => p.id <= players).fold(0, (s, p) => s + p.score) == config.targetTotalScore) {
        try {
          allResults.add(MahjongCalculator.calculate(
            inputs: g.inputs.where((p) => p.id <= players).toList(),
            rule: state.rule.copyWith(
              oka: config.oka,
              uma: _buildUmaList(config.umaText, config.isThreePlayer),
            ),
            config: config,
          ));
        } catch (_) {}
      }
    }

    if (allResults.isEmpty) return;

    final summaries = { for (int i = 1; i <= players; i++) i: {'pt': 0, 'chip': state.globalChips[i - 1], 'tobi': 0} };
    for (var res in allResults) {
      for (var p in res) {
        summaries[p.id]!['pt'] = summaries[p.id]!['pt']! + p.finalPoint;
      }
    }
    
    // Check for tobis
    for (int i = 1; i <= players; i++) {
       bool isTobi = false;
       for (var g in state.games) {
         if (g.inputs.any((inp) => inp.id == i && (inp.tobiPt < 0))) isTobi = true;
       }
       summaries[i]!['tobi'] = isTobi ? 1 : 0;
    }

    // Final Ranks based on cumulative Pt
    final sortedIds = summaries.keys.toList()
      ..sort((a, b) => summaries[b]!['pt']!.compareTo(summaries[a]!['pt']!));
    
    final ranks = { for (int i = 1; i <= players; i++) i: sortedIds.indexOf(i) + 1 };

    final Map<String, dynamic> row = {
      'type': config.isThreePlayer ? '3-player' : '4-player',
      'date': DateTime.now().toIso8601String(),
      'group_id': state.selectedGroupId,
      'p1_name': state.playerNames[0],
      'p2_name': state.playerNames[1],
      'p3_name': state.playerNames[2],
      'p4_name': players == 4 ? state.playerNames[3] : '',
      'p1_pt': summaries[1]!['pt'],
      'p2_pt': summaries[2]!['pt'],
      'p3_pt': summaries[3]!['pt'],
      'p4_pt': players == 4 ? summaries[4]!['pt'] : 0,
      'p1_ch': summaries[1]!['chip'],
      'p2_ch': summaries[2]!['chip'],
      'p3_ch': summaries[3]!['chip'],
      'p4_ch': players == 4 ? summaries[4]!['chip'] : 0,
      'p1_tobi': summaries[1]!['tobi'],
      'p2_tobi': summaries[2]!['tobi'],
      'p3_tobi': summaries[3]!['tobi'],
      'p4_tobi': players == 4 ? summaries[4]!['tobi'] : 0,
      'p1_rank': ranks[1],
      'p2_rank': ranks[2],
      'p3_rank': ranks[3],
      'p4_rank': players == 4 ? ranks[4] : 4,
    };

    final db = DatabaseService();
    await db.insertGame(row);
  }
}

final calcProvider = NotifierProvider<CalcNotifier, CalcState>(() {
  return CalcNotifier();
});

class ConfigNotifier extends Notifier<AppConfig> {
  @override
  set state(AppConfig value) {
    super.state = value;
    try {
      ref.read(sharedPrefsProvider).setString('appConfig', jsonEncode(value.toJson()));
    } catch (_) {}
  }

  @override
  AppConfig build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final str = prefs.getString('appConfig');
    if (str != null) {
      try {
        return AppConfig.fromJson(jsonDecode(str));
      } catch (_) {}
    }
    return const AppConfig();
  }

  void updateRate(double rate) {
    state = state.copyWith(rate: rate);
  }

  void updateChipRate(int chipRate) {
    state = state.copyWith(chipRate: chipRate);
  }

  void updateGameFee(int gameFee) {
    state = state.copyWith(gameFee: gameFee);
  }

  void updateRoundingTenYen(bool roundingTenYen) {
    state = state.copyWith(roundingTenYen: roundingTenYen);
  }

  void updateUmaText(String umaText) {
    state = state.copyWith(umaText: umaText);
  }

  void updateOka(int oka) {
    state = state.copyWith(oka: oka);
  }

  void updateIsThreePlayer(bool isThreePlayer) {
    final numPlayers = isThreePlayer ? 3 : 4;
    final targetScore = state.startingPoints * numPlayers;
    state = state.copyWith(isThreePlayer: isThreePlayer, targetTotalScore: targetScore);
  }

  void updateStartingPoints(int startingPoints) {
    final numPlayers = state.isThreePlayer ? 3 : 4;
    final targetScore = startingPoints * numPlayers;
    state = state.copyWith(startingPoints: startingPoints, targetTotalScore: targetScore);
  }

  void updateTargetTotalScore(int targetTotalScore) {
    state = state.copyWith(targetTotalScore: targetTotalScore);
  }

  void updateTobiPrize(int tobiPrize) {
    state = state.copyWith(tobiPrize: tobiPrize);
  }

  void updateYakumanTsumoPrize(int yakumanTsumoPrize) {
    state = state.copyWith(yakumanTsumoPrize: yakumanTsumoPrize);
  }

  void updateYakumanRonPrize(int yakumanRonPrize) {
    state = state.copyWith(yakumanRonPrize: yakumanRonPrize);
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(() {
  return ConfigNotifier();
});

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calculator.dart';
import '../../core/models/app_config.dart';

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

  const CalcState({
    this.playerNames = const ['A', 'B', 'C', 'D'],
    this.globalChips = const [0, 0, 0, 0],
    required this.games,
    this.rule = const MahjongRule(),
  });

  CalcState copyWith({
    List<String>? playerNames,
    List<int>? globalChips,
    List<GameRecord>? games,
    MahjongRule? rule,
  }) {
    return CalcState(
      playerNames: playerNames ?? this.playerNames,
      globalChips: globalChips ?? this.globalChips,
      games: games ?? this.games,
      rule: rule ?? this.rule,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerNames': playerNames,
    'globalChips': globalChips,
    'games': games.map((e) => e.toJson()).toList(),
    'rule': rule.toJson(),
  };

  factory CalcState.fromJson(Map<String, dynamic> json) {
    return CalcState(
      playerNames: (json['playerNames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const ['A', 'B', 'C', 'D'],
      globalChips: (json['globalChips'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [0, 0, 0, 0],
      games: (json['games'] as List<dynamic>?)?.map((e) => GameRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      rule: json['rule'] != null ? MahjongRule.fromJson(json['rule'] as Map<String, dynamic>) : const MahjongRule(),
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
    final yakumanPrize = ref.read(configProvider).yakumanPrize;
    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final isAlreadySet = game.inputs.any((p) => p.id == winnerId && p.yakumanPt == yakumanPrize);

      final newInputs = game.inputs.map((p) {
        if (isAlreadySet) return p.copyWith(yakumanPt: 0);
        if (p.id == winnerId) return p.copyWith(yakumanPt: yakumanPrize);
        if (p.id == loserId) return p.copyWith(yakumanPt: -yakumanPrize);
        return p.copyWith(yakumanPt: 0);
      }).toList();
      return game.copyWith(inputs: newInputs);
    }).toList();
    state = state.copyWith(games: newGames);
  }

  void setYakumanTsumo(String gameId, int winnerId) {
    final yakumanTsumoPrize = (ref.read(configProvider).yakumanPrize * 1.5).round(); // Usually Sanma Tsumo is adjusted or 4-player 15pt
    final isThreePlayer = ref.read(configProvider).isThreePlayer;
    final divisor = isThreePlayer ? 2 : 3;

    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final isAlreadySet = game.inputs.any((p) => p.id == winnerId && p.yakumanPt == yakumanTsumoPrize);

      final newInputs = game.inputs.map((p) {
        if (isAlreadySet) return p.copyWith(yakumanPt: 0);
        if (p.id == winnerId) return p.copyWith(yakumanPt: yakumanTsumoPrize);
        // Exclude inactive player (ID 4 in Sanma) from paying the Tsumo
        if (isThreePlayer && p.id == 4) return p.copyWith(yakumanPt: 0); 
        return p.copyWith(yakumanPt: -(yakumanTsumoPrize ~/ divisor));
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
    final targetScore = isThreePlayer ? 105000 : 100000;
    state = state.copyWith(isThreePlayer: isThreePlayer, targetTotalScore: targetScore);
  }

  void updateTargetTotalScore(int targetTotalScore) {
    state = state.copyWith(targetTotalScore: targetTotalScore);
  }

  void updateTobiPrize(int tobiPrize) {
    state = state.copyWith(tobiPrize: tobiPrize);
  }

  void updateYakumanPrize(int yakumanPrize) {
    state = state.copyWith(yakumanPrize: yakumanPrize);
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(() {
  return ConfigNotifier();
});

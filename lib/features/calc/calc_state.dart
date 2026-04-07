import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calculator.dart';
import '../../core/models/app_config.dart';
import '../../core/database/database_service.dart';
import '../../core/models/db_models.dart';

enum SaveResult { registered, updated, failed }

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
  final int? currentId;
  final String? preservedStateJson;

  const CalcState({
    this.playerNames = const ['A', 'B', 'C', 'D'],
    this.globalChips = const [0, 0, 0, 0],
    this.games = const [],
    this.rule = const MahjongRule(),
    this.selectedGroupId,
    this.currentId,
    this.preservedStateJson,
  });

  CalcState copyWith({
    List<String>? playerNames,
    List<int>? globalChips,
    List<GameRecord>? games,
    MahjongRule? rule,
    int? selectedGroupId,
    int? currentId,
    String? preservedStateJson,
    bool clearPreserved = false,
  }) {
    return CalcState(
      playerNames: playerNames ?? this.playerNames,
      globalChips: globalChips ?? this.globalChips,
      games: games ?? this.games,
      rule: rule ?? this.rule,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      currentId: currentId ?? this.currentId,
      preservedStateJson: clearPreserved ? null : (preservedStateJson ?? this.preservedStateJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'playerNames': playerNames,
    'globalChips': globalChips,
    'games': games.map((e) => e.toJson()).toList(),
    'rule': rule.toJson(),
    'selectedGroupId': selectedGroupId,
    'currentId': currentId,
    'preservedStateJson': preservedStateJson,
  };

  factory CalcState.fromJson(Map<String, dynamic> json) {
    return CalcState(
      playerNames: (json['playerNames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const ['A', 'B', 'C', 'D'],
      globalChips: (json['globalChips'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [0, 0, 0, 0],
      games: (json['games'] as List<dynamic>?)?.map((e) => GameRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      rule: json['rule'] != null ? MahjongRule.fromJson(json['rule'] as Map<String, dynamic>) : const MahjongRule(),
      selectedGroupId: json['selectedGroupId'] as int?,
      currentId: json['currentId'] as int?,
      preservedStateJson: json['preservedStateJson'] as String?,
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
    const numPlayers = 4;
    final totalWin = yakumanTsumoPrize * (numPlayers - 1);

    final newGames = state.games.map((game) {
      if (game.id != gameId) return game;
      final isAlreadySet = game.inputs.any((p) => p.id == winnerId && p.yakumanPt == totalWin);

      final newInputs = game.inputs.map((p) {
        if (isAlreadySet) return p.copyWith(yakumanPt: 0);
        if (p.id == winnerId) return p.copyWith(yakumanPt: totalWin);
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

  List<int> _buildUmaList(String umaText) {
    final parts = umaText.split('-');
    if (parts.length == 2) {
      final a = int.tryParse(parts[0]) ?? 10;
      final b = int.tryParse(parts[1]) ?? 20;
      return [b, a, -a, -b];
    }
    return [20, 10, -10, -20];
  }

  Future<SaveResult> saveCurrentSession(DateTime date) async {
    try {
      final config = ref.read(configProvider);
      const players = 4;
      if (state.games.isEmpty) return SaveResult.failed;

      // Calculate final stats
      List<List<PlayerResult>> allResults = [];
      for (var g in state.games) {
        if (g.inputs.where((p) => p.id <= players).fold(0, (s, p) => s + p.score) == config.targetTotalScore) {
          try {
            allResults.add(MahjongCalculator.calculate(
              inputs: g.inputs.where((p) => p.id <= players).toList(),
              rule: state.rule.copyWith(
                oka: config.oka,
                uma: _buildUmaList(config.umaText),
              ),
              config: config,
            ));
          } catch (_) {}
        }
      }

      if (allResults.isEmpty) return SaveResult.failed;

      final summaries = { for (int i = 1; i <= players; i++) i: {'pt': 0, 'chip': state.globalChips[i - 1], 'tobi': 0, 'score': 0, 'money': 0} };
      for (var res in allResults) {
        for (var p in res) {
          summaries[p.id]!['pt'] = (summaries[p.id]!['pt']! as int) + p.finalPoint.toInt();
          // p.money は (Pt * rate) + (チップ * chipRate) - (場代/4) ですでに計算・丸められている
          // ここにセッション全体のチップを加算するため、まずは各ゲームの結果（チップ抜き）を累積する
          summaries[p.id]!['money'] = (summaries[p.id]!['money']! as int) + p.money;
        }
      }

      // セッション全体のチップ分を収支に反映させる
      for (int i = 1; i <= players; i++) {
        final sessionChip = summaries[i]!['chip'] as int;
        final chipValue = sessionChip * config.chipRate;
        summaries[i]!['money'] = (summaries[i]!['money'] as int) + chipValue;
      }

      // Sum raw scores from all valid games
      for (var g in state.games) {
        if (g.inputs.where((p) => p.id <= players).fold(0, (s, p) => s + p.score) == config.targetTotalScore) {
          for (var inp in g.inputs) {
            if (inp.id <= players) {
              summaries[inp.id]!['score'] = (summaries[inp.id]!['score']! as int) + inp.score;
            }
          }
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
        ..sort((a, b) => (summaries[b]!['pt']! as int).compareTo(summaries[a]!['pt']! as int));
      
      final ranks = { for (int i = 1; i <= players; i++) i: sortedIds.indexOf(i) + 1 };

      final Map<String, dynamic> row = {
        if (state.currentId != null) 'id': state.currentId,
        'type': '4-player',
        'date': date.toIso8601String(),
        'group_id': state.selectedGroupId,
        'p1_name': state.playerNames[0],
        'p2_name': state.playerNames[1],
        'p3_name': state.playerNames[2],
        'p4_name': players == 4 ? state.playerNames[3] : "",
        'p1_score': (summaries[1]?['score'] ?? 0) as int,
        'p2_score': (summaries[2]?['score'] ?? 0) as int,
        'p3_score': (summaries[3]?['score'] ?? 0) as int,
        'p4_score': players == 4 ? ((summaries[4]?['score'] ?? 0) as int) : 0,
        'p1_pt': (summaries[1]?['pt'] ?? 0) as int,
        'p2_pt': (summaries[2]?['pt'] ?? 0) as int,
        'p3_pt': (summaries[3]?['pt'] ?? 0) as int,
        'p4_pt': players == 4 ? ((summaries[4]?['pt'] ?? 0) as int) : 0,
        'p1_ch': (summaries[1]?['chip'] ?? 0) as int,
        'p2_ch': (summaries[2]?['chip'] ?? 0) as int,
        'p3_ch': (summaries[3]?['chip'] ?? 0) as int,
        'p4_ch': players == 4 ? ((summaries[4]?['chip'] ?? 0) as int) : 0,
        'p1_tobi': (summaries[1]?['tobi'] ?? 0) as int,
        'p2_tobi': (summaries[2]?['tobi'] ?? 0) as int,
        'p3_tobi': (summaries[3]?['tobi'] ?? 0) as int,
        'p4_tobi': players == 4 ? ((summaries[4]?['tobi'] ?? 0) as int) : 0,
        'p1_rank': ranks[1],
        'p2_rank': ranks[2],
        'p3_rank': ranks[3],
        'p4_rank': players == 4 ? ranks[4] : 0,
        'p1_money': (summaries[1]?['money'] ?? 0) as int,
        'p2_money': (summaries[2]?['money'] ?? 0) as int,
        'p3_money': (summaries[3]?['money'] ?? 0) as int,
        'p4_money': players == 4 ? ((summaries[4]?['money'] ?? 0) as int) : 0,
      };

      final db = DatabaseService();
      final isUpdate = state.currentId != null;
      print('Saving session: $row'); // Debug log
      final id = await db.upsertGame(row);
      
      if (!isUpdate) {
        // 新規登録成功時は状態をリセットする（ユーザー指示）
        resetToNewEntry();
      }
      return isUpdate ? SaveResult.updated : SaveResult.registered;
    } catch (e) {
      print('Save error: $e');
      return SaveResult.failed;
    }
  }

  void loadGame(SavedGame game) {
    // Construct a single GameRecord from the aggregated scores
    final inputs = List.generate(4, (i) => PlayerInput(
      id: i + 1,
      score: game.scores[i],
      tobiPt: game.tobis[i] ? -1 : 0,
    ));

    // 新規入力中（currentId == null）であれば現在の状態を一時保存する
    final currentPreserved = state.currentId == null ? jsonEncode(state.toJson()) : state.preservedStateJson;

    state = state.copyWith(
      currentId: game.id,
      playerNames: game.playerNames,
      globalChips: game.chips,
      games: [GameRecord(id: 'load_${game.id}', inputs: inputs)],
      selectedGroupId: game.groupId,
      preservedStateJson: currentPreserved,
    );
  }

  void resetToNewEntry() {
    state = CalcState(
      playerNames: const ['A', 'B', 'C', 'D'],
      globalChips: const [0, 0, 0, 0],
      games: const [],
      rule: state.rule,
      preservedStateJson: null, // 明示的なリセット時は一時保存もクリア
    );
  }

  void exitHistoryMode() {
    if (state.preservedStateJson != null) {
      try {
        final preserved = CalcState.fromJson(jsonDecode(state.preservedStateJson!));
        // 中身だけ復元し、自分自身のバックアップ(preservedStateJson)はクリアする
        state = preserved.copyWith(clearPreserved: true);
        return;
      } catch (e) {
        print('Restore error: $e');
      }
    }
    
    // バックアップがない場合は通常通り ID のみ解除
    state = CalcState(
      playerNames: state.playerNames,
      globalChips: state.globalChips,
      games: state.games,
      rule: state.rule,
      selectedGroupId: state.selectedGroupId,
      currentId: null,
      preservedStateJson: null,
    );
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

  void updateStartingPoints(int startingPoints) {
    const numPlayers = 4;
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

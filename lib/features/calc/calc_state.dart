import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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
  final String? currentDraft;
  final List<Map<String, dynamic>>? possibleGroupMatches; // 追加: マッチ候補

  const CalcState({
    this.playerNames = const ['A', 'B', 'C', 'D'],
    this.globalChips = const [0, 0, 0, 0],
    this.games = const [],
    this.rule = const MahjongRule(),
    this.selectedGroupId,
    this.currentId,
    this.currentDraft,
    this.possibleGroupMatches,
  });

  CalcState copyWith({
    List<String>? playerNames,
    List<int>? globalChips,
    List<GameRecord>? games,
    MahjongRule? rule,
    int? selectedGroupId,
    int? currentId,
    String? currentDraft,
    bool clearDraft = false,
    List<Map<String, dynamic>>? possibleGroupMatches,
    bool clearMatches = false,
  }) {
    return CalcState(
      playerNames: playerNames ?? this.playerNames,
      globalChips: globalChips ?? this.globalChips,
      games: games ?? this.games,
      rule: rule ?? this.rule,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      currentId: currentId ?? this.currentId,
      currentDraft: clearDraft ? null : (currentDraft ?? this.currentDraft),
      possibleGroupMatches: clearMatches ? null : (possibleGroupMatches ?? this.possibleGroupMatches),
    );
  }

  Map<String, dynamic> toJson() => {
    'playerNames': playerNames,
    'globalChips': globalChips,
    'games': games.map((e) => e.toJson()).toList(),
    'rule': rule.toJson(),
    'selectedGroupId': selectedGroupId,
    'currentId': currentId,
    'currentDraft': currentDraft,
  };

  factory CalcState.fromJson(Map<String, dynamic> json) {
    return CalcState(
      playerNames: (json['playerNames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const ['A', 'B', 'C', 'D'],
      globalChips: (json['globalChips'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [0, 0, 0, 0],
      games: (json['games'] as List<dynamic>?)?.map((e) => GameRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      rule: json['rule'] != null ? MahjongRule.fromJson(json['rule'] as Map<String, dynamic>) : const MahjongRule(),
      selectedGroupId: json['selectedGroupId'] as int?,
      currentId: json['currentId'] as int?,
      currentDraft: json['currentDraft'] as String?,
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
    
    // 4名の名前が埋まったら自動判別を試行
    if (newNames.every((n) => n.trim().isNotEmpty)) {
      _checkGroupMatches(newNames);
    }
  }

  Future<void> _checkGroupMatches(List<String> names) async {
    final db = DatabaseService();
    final allGroups = await db.getGroups();
    final List<Map<String, dynamic>> matches = [];

    for (var group in allGroups) {
      final members = await db.getMembers(group['id']);
      final memberNames = members.map((m) => m['name'] as String).toList()..sort();
      final inputNames = List<String>.from(names.map((e) => e.trim()))..sort();
      
      if (memberNames.join(',') == inputNames.join(',')) {
        matches.add(group);
      }
    }

    if (matches.length == 1) {
      // 1つだけ一致なら自動選択
      state = state.copyWith(selectedGroupId: matches.first['id'], clearMatches: true);
    } else if (matches.length > 1) {
      // 複数一致なら候補を保存して選択を促す
      state = state.copyWith(possibleGroupMatches: matches);
    } else {
       // 一致なし
       state = state.copyWith(clearMatches: true);
    }
  }

  void setSelectedGroupId(int? id) {
    state = state.copyWith(selectedGroupId: id, clearMatches: true);
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

      final db = DatabaseService();
      final isUpdate = state.currentId != null;

      // 1. セッション全体の場代込収支を計算するための準備
      // 各対局の計算結果を一時保持する
      final List<Map<String, dynamic>> calculatedGames = [];
      final List<int> totalMoneys = [0, 0, 0, 0];
      final configJson = jsonEncode(config.toJson());

      for (int i = 0; i < state.games.length; i++) {
        final g = state.games[i];
        if (g.inputs.where((p) => p.id <= players).fold(0, (s, p) => s + p.score) != config.targetTotalScore) {
          continue;
        }

        final result = MahjongCalculator.calculate(
          inputs: g.inputs.where((p) => p.id <= players).toList(),
          rule: state.rule.copyWith(
            oka: config.oka,
            uma: _buildUmaList(config.umaText),
          ),
          config: config,
          startingOyaIndex: g.startingOyaIndex,
        );

        // 各対局ごとのチップ分（DB保存用）
        // 最初の1ゲーム目にのみ「セッション単位の追加チップ」を合算して帳尻を合わせる
        final addChips = (i == 0) ? state.globalChips : const [0, 0, 0, 0];
        final gameMoneys = <String, int>{};
        
        for (var r in result) {
          final m = r.money + (addChips[r.id - 1] * config.chipRate);
          gameMoneys[r.id.toString()] = m;
          totalMoneys[r.id - 1] += m;
        }

        calculatedGames.add({
          'game': g,
          'result': result,
          'moneys': gameMoneys,
          'addChips': addChips,
        });
      }

      if (calculatedGames.isEmpty) return SaveResult.failed;

      // 2. セッション（ヘッダー）の特定または作成
      final sessionDay = DateFormat('yyyy/MM/dd').format(date);
      final int sessionId;
      if (isUpdate) {
        sessionId = state.currentId!;
        // セッション情報を更新（設定値と合計収支のスナップショットを保存）
        await db.updateSession(Session(
          id: sessionId,
          date: sessionDay,
          playerNames: state.playerNames,
          groupId: state.selectedGroupId,
          configJson: configJson,
          totalMoneys: totalMoneys,
        ));
        // 明細の重複を防ぐため、既存の対局データを一度すべて削除（指示通り）
        await db.deleteGamesBySessionId(sessionId);
      } else {
        sessionId = await db.findOrCreateSession(
          date: sessionDay,
          playerNames: state.playerNames,
          groupId: state.selectedGroupId,
          configJson: configJson,
          totalMoneys: totalMoneys,
        );
      }

      // 3. 明細（Games）の登録
      for (var cg in calculatedGames) {
        final g = cg['game'] as GameRecord;
        final result = cg['result'] as List<PlayerResult>;
        final gameMoneys = cg['moneys'] as Map<String, int>;
        final addChips = cg['addChips'] as List<int>;

        final Map<String, dynamic> row = {
          'session_id': sessionId,
          'type': '4-player',
          'date': date.toIso8601String(),
          'group_id': state.selectedGroupId,
          'p1_name': state.playerNames[0],
          'p2_name': state.playerNames[1],
          'p3_name': state.playerNames[2],
          'p4_name': state.playerNames[3],
          'p1_score': g.inputs[0].score,
          'p2_score': g.inputs[1].score,
          'p3_score': g.inputs[2].score,
          'p4_score': g.inputs[3].score,
          'p1_pt': result.firstWhere((r) => r.id == 1).finalPoint,
          'p2_pt': result.firstWhere((r) => r.id == 2).finalPoint,
          'p3_pt': result.firstWhere((r) => r.id == 3).finalPoint,
          'p4_pt': result.firstWhere((r) => r.id == 4).finalPoint,
          'p1_ch': addChips[0], // そのゲームに付随するチップ（セッション初回分含む）
          'p2_ch': addChips[1],
          'p3_ch': addChips[2],
          'p4_ch': addChips[3],
          'p1_tobi': g.inputs[0].score < 0 ? 1 : 0,
          'p2_tobi': g.inputs[1].score < 0 ? 1 : 0,
          'p3_tobi': g.inputs[2].score < 0 ? 1 : 0,
          'p4_tobi': g.inputs[3].score < 0 ? 1 : 0,
        };

        final sortedByPt = List<PlayerResult>.from(result)..sort((a, b) => b.finalPoint.compareTo(a.finalPoint));
        row['p1_rank'] = sortedByPt.indexWhere((r) => r.id == 1) + 1;
        row['p2_rank'] = sortedByPt.indexWhere((r) => r.id == 2) + 1;
        row['p3_rank'] = sortedByPt.indexWhere((r) => r.id == 3) + 1;
        row['p4_rank'] = sortedByPt.indexWhere((r) => r.id == 4) + 1;

        row['p1_money'] = gameMoneys['1'];
        row['p2_money'] = gameMoneys['2'];
        row['p3_money'] = gameMoneys['3'];
        row['p4_money'] = gameMoneys['4'];

        await db.insertGame(row);
      }

      resetToNewEntry();
      return isUpdate ? SaveResult.updated : SaveResult.registered;
    } catch (e) {
      print('Save error: $e');
      return SaveResult.failed;
    }
  }

  void loadSession(Session session, List<SavedGame> sessionGames) {
    // 履歴読み込み直前に現在の入力を退避 (新規入力時のみ)
    final draft = state.currentId == null ? jsonEncode(state.toJson()) : state.currentDraft;

    final List<GameRecord> newGames = sessionGames.map((game) {
      final inputs = List.generate(4, (i) => PlayerInput(
        id: i + 1,
        score: game.scores[i],
        tobiPt: game.tobis[i] ? -1 : 0, // Simplified tobi logic for display
        chip: game.chips[i],
      ));
      return GameRecord(
        id: 'load_${game.id}',
        inputs: inputs,
        startingOyaIndex: 0, // Placeholder
      );
    }).toList();

    state = state.copyWith(
      currentId: session.id,
      playerNames: session.playerNames,
      globalChips: const [0, 0, 0, 0], // Chips are per-game in DB or per-player session? 
      // In SavedGame, we have chips list. Let's use the first game's chips as global if needed, 
      // but usually they are per game. Ver 1.7.1 logic stores chips in SavedGame.
      games: newGames,
      selectedGroupId: session.groupId,
      currentDraft: draft,
    );
  }

  void loadGame(SavedGame game) {
    final draft = state.currentId == null ? jsonEncode(state.toJson()) : state.currentDraft;
    final inputs = List.generate(4, (i) => PlayerInput(
      id: i + 1,
      score: game.scores[i],
      tobiPt: game.tobis[i] ? -1 : 0,
      chip: game.chips[i],
    ));
    state = state.copyWith(
      currentId: game.id,
      playerNames: game.playerNames,
      globalChips: const [0, 0, 0, 0],
      games: [GameRecord(id: 'load_${game.id}', inputs: inputs)],
      selectedGroupId: game.groupId,
      currentDraft: draft,
    );
  }

  void resetGame() {
    if (state.currentDraft != null) {
      try {
        final draftData = CalcState.fromJson(jsonDecode(state.currentDraft!));
        state = draftData.copyWith(clearDraft: true);
        return;
      } catch (_) {}
    }
    state = CalcState(
      playerNames: const ['A', 'B', 'C', 'D'],
      globalChips: const [0, 0, 0, 0],
      games: const [],
      rule: state.rule,
      currentDraft: null,
    );
  }

  void resetToNewEntry() => resetGame();

  void exitHistoryMode() {
    if (state.currentDraft != null) {
      try {
        final draftData = CalcState.fromJson(jsonDecode(state.currentDraft!));
        state = draftData.copyWith(clearDraft: true);
        return;
      } catch (e) {
        print('Restore error: $e');
      }
    }
    state = state.copyWith(currentId: null, clearDraft: true);
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

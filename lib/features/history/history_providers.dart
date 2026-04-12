import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/database/database_providers.dart';
import '../../core/models/db_models.dart';
import '../calc/calc_providers.dart';
import '../stats/stats_providers.dart';
import '../../core/utils/mahjong_calculator.dart';

class HistoryNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    ref.watch(databaseVersionProvider);
    return _fetchSessions();
  }

  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    final db = DatabaseService();
    // Ver 3.3.6: データベースレベルでのフィルターを完全撤廃し、全件取得メソッドを呼び出す
    final sessionRows = await db.getAllSessions();
    final gameRows = await db.getAllGames();
    final groupRows = await db.getGroups();
    
    final List<Map<String, dynamic>> sessionsWithGames = [];
    
    for (var s in sessionRows) {
      final sessionGames = gameRows
          .where((g) => g['session_id'] == s['id'])
          .map((e) => SavedGame.fromMap(e))
          .toList();
      
      if (sessionGames.isEmpty) continue;

      // Ver 3.3.6: 安全なマッピング（見つからない場合は'フリー対局'）
      final group = groupRows.firstWhere((g) => g['id'] == s['group_id'], orElse: () => {'name': 'フリー対局'});
      final groupName = group['name'] as String;

      final Session session = Session.fromMap(s);

      // Ver 3.5.0: MahjongCalculator を使用して、各セッションの config_json に基づき収支を算出する
      final List<int> totalPts = [0, 0, 0, 0];
      final List<int> totalChips = [0, 0, 0, 0];
      
      for (var game in sessionGames) {
        for (int i = 0; i < game.points.length && i < 4; i++) {
          totalPts[i] += game.points[i];
          // ヒント: ここでの game.chips は各局のチップ増分。最終収支には global_chips_json を優先する方針。
          // ただし、もし global_chips_json が null の場合の互換性として保持。
        }
      }

      // セッション固有ルールのデコード (グローバル SettingsProvider は一切参照しない)
      double rate = 100.0; int chipRate = 100; double fee = 0.0;
      final configJson = s['config_json'] as String?;
      if (configJson != null) {
        try {
          final cfg = jsonDecode(configJson);
          rate = (cfg['rate'] as num?)?.toDouble() ?? 100.0;
          chipRate = (cfg['chipRate'] as num?)?.toInt() ?? 100;
          fee = (cfg['gameFee'] as num?)?.toDouble() ?? 0.0;
        } catch(_) {}
      }

      // 最終的なチップ数の確定 (global_chips_json を優先)
      if (s['global_chips_json'] != null) {
        try {
          final gc = (jsonDecode(s['global_chips_json'] as String) as List).cast<int>();
          for (int i = 0; i < gc.length && i < 4; i++) {
             totalChips[i] = gc[i]; 
          }
        } catch(_) {}
      }

      final List<int> totalMoneysCalculated = [0, 0, 0, 0];
      for (int i = 0; i < 4; i++) {
        // 全く同じ計算ロジック（MahjongCalculator）を呼び出す
        totalMoneysCalculated[i] = MahjongCalculator.calculateMoney(
          totalPt: totalPts[i],
          rate: rate,
          totalChips: totalChips[i],
          chipRate: chipRate,
          totalFee: fee,
        );
      }

      sessionsWithGames.add({
        'session': session,
        'games': sessionGames,
        'groupName': groupName,
        'totalPt': totalPts,
        'totalMoney': totalMoneysCalculated,
        'gameCount': sessionGames.length,
      });
    }
    return sessionsWithGames;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchSessions());
  }

  Future<void> deleteSession(int sessionId) async {
    final db = DatabaseService();
    await db.deleteSession(sessionId);
    ref.read(databaseVersionProvider.notifier).increment();
    await refresh();
  }

  Future<void> updateSessionGroupId(int sessionId, int? groupId) async {
    final db = DatabaseService();
    await db.updateSessionGroupId(sessionId, groupId);
    
    ref.read(databaseVersionProvider.notifier).increment(); 
    ref.invalidate(groupListProvider);
    ref.invalidate(allSessionsProvider);
    ref.invalidate(allGamesProvider);
    
    await refresh();
  }

  Future<void> clearHistory({bool all = false, int months = 0}) async {
    final db = DatabaseService();
    if (all) {
      await db.deleteAllHistory();
      ref.read(configProvider.notifier).updateGameFee(0);
    } else {
      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month - months, now.day);
      final dateStr = DateFormat('yyyy/MM/dd').format(targetDate);
      await db.deleteHistoryBefore(dateStr);
    }
    ref.read(databaseVersionProvider.notifier).increment();
    await refresh();
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<Map<String, dynamic>>>(HistoryNotifier.new);

class HistoryFilterNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;
  void setFilter(DateTimeRange? range) => state = range;
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, DateTimeRange?>(HistoryFilterNotifier.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/database/database_providers.dart';
import '../../core/models/db_models.dart';
import '../calc/calc_providers.dart';
import '../stats/stats_providers.dart';
import 'package:collection/collection.dart';

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

      // Ver 3.4.4: Sessionプロパティに依存せず、常に Games リストから最新の合計値を算出する
      // また、セッション固有の config_json を参照して金額を正確に再計算する
      final List<int> totalPts = [0, 0, 0, 0];
      final List<int> totalChips = [0, 0, 0, 0];
      
      for (var game in sessionGames) {
        for (int i = 0; i < game.points.length && i < 4; i++) {
          totalPts[i] += game.points[i];
          totalChips[i] += game.chips[i];
        }
      }

      // セッション固有ルールのデコード
      double rate = 0; int chipRate = 0; int fee = 0;
      final configJson = s['config_json'] as String?;
      if (configJson != null) {
        try {
          final cfg = jsonDecode(configJson);
          rate = (cfg['rate'] as num?)?.toDouble() ?? 0.0;
          chipRate = (cfg['chipRate'] as num?)?.toInt() ?? 0;
          fee = (cfg['gameFee'] as num?)?.toInt() ?? 0;
        } catch(_) {}
      }

      final List<int> totalMoneysCalculated = [0, 0, 0, 0];
      for (int i = 0; i < 4; i++) {
        final income = (totalPts[i] * rate) + (totalChips[i] * chipRate);
        // 厳守：場代(fee / 4) はセッション合計から1回だけ引く
        totalMoneysCalculated[i] = (income - (fee / 4.0)).round();
      }

      // グローバルチップの加算 (互換性維持)
      if (s['global_chips_json'] != null) {
        try {
          final gc = (jsonDecode(s['global_chips_json'] as String) as List).cast<int>();
          for (int i = 0; i < gc.length && i < 4; i++) {
             totalMoneysCalculated[i] += (gc[i] * chipRate);
             totalChips[i] += gc[i];
          }
        } catch(_) {}
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
    ref.invalidate(databaseVersionProvider);
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
    ref.invalidate(databaseVersionProvider);
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final sessionRows = await db.getSessions(all: true);
    final gameRows = await db.getGames(all: true);
    final groupRows = await db.getGroups();
    
    final List<Map<String, dynamic>> sessionsWithGames = [];
    
    for (var s in sessionRows) {
      final sessionGames = gameRows
          .where((g) => g['session_id'] == s['id'])
          .map((e) => SavedGame.fromMap(e))
          .toList();
      
      if (sessionGames.isEmpty) continue;

      final groupId = s['group_id'] as int?;
      String groupName = 'フリー対局';
      if (groupId != null) {
        final group = groupRows.firstWhereOrNull((g) => g['id'] == groupId);
        if (group != null) {
          groupName = group['name'] as String? ?? 'フリー対局';
        }
      }

      final List<int> totalPt = [0, 0, 0, 0];
      
      for (var g in sessionGames) {
        for (int i = 0; i < g.playerNames.length; i++) {
          if (i < 4) {
            totalPt[i] += g.points[i];
          }
        }
      }

      final session = Session.fromMap(s);

      sessionsWithGames.add({
        'session': session,
        'games': sessionGames,
        'groupName': groupName,
        'totalPt': totalPt,
        'totalMoney': [
          session.totalMoneys?[0] ?? 0,
          session.totalMoneys?[1] ?? 0,
          session.totalMoneys?[2] ?? 0,
          session.totalMoneys?[3] ?? 0,
        ],
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

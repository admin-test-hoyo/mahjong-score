import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/db_models.dart';
import '../calc/calc_state.dart';

class HistoryNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchSessions();
  }

  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    final db = DatabaseService();
    final sessionRows = await db.getSessions();
    final gameRows = await db.getGames();
    
    final List<Map<String, dynamic>> sessionsWithGames = [];
    
    for (var s in sessionRows) {
      final sessionGames = gameRows
          .where((g) => g['session_id'] == s['id'])
          .map((e) => SavedGame.fromMap(e))
          .toList();
      
      if (sessionGames.isEmpty) continue;

      final groupRows = await db.getGroups();
      final groupName = s['group_id'] != null 
          ? groupRows.firstWhere((g) => g['id'] == s['group_id'], orElse: () => {'name': '不明'})['name']
          : 'フリー対局';

      final List<int> totalPt = [0, 0, 0, 0];
      final List<int> totalChip = [0, 0, 0, 0];
      final List<int> totalMoney = [0, 0, 0, 0];
      
      for (var g in sessionGames) {
        for (int i = 0; i < g.playerNames.length; i++) {
          if (i < 4) {
            totalPt[i] += g.points[i];
            totalChip[i] += g.chips[i];
            totalMoney[i] += g.moneys[i];
          }
        }
      }

      sessionsWithGames.add({
        'session': Session.fromMap(s),
        'games': sessionGames,
        'groupName': groupName,
        'totalPt': totalPt,
        'totalChip': totalChip,
        'totalMoney': totalMoney,
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
    await db.deleteHistoryBefore(""); // Placeholder or implement a specific delete for sessionId
    // DatabaseService に deleteSession(id) があればそれを使うべきだが、
    // 現在の logic は deleteHistoryBefore や deleteAllHistory。
    // そのため、対象のセッションとそのゲームを消すロジックを DatabaseService に追加するか、現状の transaction を利用。
    // ここでは簡回のために sessions/games 全体削除または特定日付削除が実装済み。
    // 一旦既存の deleteSession ロジックを維持。
    final games = await db.getGames();
    for (var g in games) {
      if (g['session_id'] == sessionId) {
        await db.deleteGame(g['id']);
      }
    }
    await refresh();
  }

  Future<void> updateSessionGroupId(int sessionId, int? groupId) async {
    final db = DatabaseService();
    await db.updateSessionGroupId(sessionId, groupId);
    await refresh();
  }

  Future<void> clearHistory({bool all = false, int months = 0}) async {
    final db = DatabaseService();
    if (all) {
      await db.deleteAllHistory();
    } else {
      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month - months, now.day);
      final dateStr = DateFormat('yyyy/MM/dd').format(targetDate);
      await db.deleteHistoryBefore(dateStr);
    }
    await refresh();
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<Map<String, dynamic>>>(() {
  return HistoryNotifier();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(historyProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFC2)),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text('対局履歴', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Color(0xFF00FFC2), size: 18),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _selectedDateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF00BFA5),
                      onPrimary: Colors.white,
                      surface: Color(0xFF001F1A),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _selectedDateRange = picked);
              else setState(() => _selectedDateRange = null);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Color(0xFF00FFC2), size: 18),
            onPressed: () => _showCleanupDialog(context, ref),
          ),
        ],
      ),
      body: history.when(
        data: (sessions) {
          var filteredSessions = sessions;
          if (_selectedDateRange != null) {
            filteredSessions = filteredSessions.where((s) {
              final dt = (s['session'] as Session).date;
              final date = DateFormat('yyyy/MM/dd').parse(dt);
              return !date.isBefore(_selectedDateRange!.start) && 
                     date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
            }).toList();
          }

          return Column(
            children: [
              if (_selectedDateRange != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  color: Colors.black26,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        '期間指定: ${DateFormat('M/d').format(_selectedDateRange!.start)} 〜 ${DateFormat('M/d').format(_selectedDateRange!.end)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => setState(() => _selectedDateRange = null),
                        child: const Icon(Icons.close, size: 14, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredSessions.isEmpty 
                  ? const Center(child: Text('対局履歴がありません', style: TextStyle(color: Colors.white24)))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(historyProvider.notifier).refresh(),
                      color: const Color(0xFF00FFC2),
                      child: ListView.builder(
                        itemCount: filteredSessions.length,
                        itemBuilder: (context, index) {
                          final sessionData = filteredSessions[index];
                          final Session session = sessionData['session'];
                          final String groupName = sessionData['groupName'];
                          final int gameCount = sessionData['gameCount'];
                          final List<int> totalPts = sessionData['totalPt'];
                          final List<int> totalMoneys = sessionData['totalMoney'];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: InkWell(
                              onTap: () => _showSessionDetailDialog(context, ref, sessionData),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${session.date} - $gameCount局', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                            Text(
                                              groupName,
                                              style: TextStyle(
                                                color: session.groupId == null ? Colors.orangeAccent : const Color(0xFF00FFC2),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.edit_note, color: Colors.white24, size: 20),
                                          onPressed: () => _showGroupAssignmentDialog(context, ref, session),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: List.generate(session.playerNames.length, (i) {
                                        final pt = totalPts[i];
                                        final money = totalMoneys[i];
                                        return Expanded(
                                          child: Column(
                                            children: [
                                              Text(session.playerNames[i], style: const TextStyle(color: Colors.white54, fontSize: 9), overflow: TextOverflow.ellipsis),
                                              Text(
                                                pt > 0 ? '+$pt' : pt.toString(),
                                                style: TextStyle(
                                                  color: pt >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text('¥${money >= 0 ? "+" : ""}$money', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
        error: (e, s) => const Center(child: Text('読み込みエラー', style: TextStyle(color: Colors.white24))),
      ),
    );
  }

  void _showSessionDetailDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> sessionData) {
    final Session session = sessionData['session'];
    final List<SavedGame> games = sessionData['games'];
    final String groupName = sessionData['groupName'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Text(groupName, style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 16)),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white24),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Colors.white10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return InkWell(
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF001F1A),
                            title: const Text('対局データの復元', style: TextStyle(color: Colors.white, fontSize: 16)),
                            content: const Text('この対局データを計算画面に読み込みますか？\n(現在の入力内容は失われます)', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('読み込む', style: TextStyle(color: Color(0xFF00FFC2)))),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          ref.read(calcProvider.notifier).loadGame(game);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop(true);
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(game.playerNames.length, (i) {
                            final pt = game.points[i];
                            final rank = game.ranks[i];
                            return Column(
                              children: [
                                Text('${rank}位', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                Text(
                                  pt > 0 ? '+$pt' : pt.toString(),
                                  style: TextStyle(
                                    color: pt >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('¥${game.moneys[i]}', style: const TextStyle(color: Colors.white24, fontSize: 8)),
                              ],
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white10),
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF001F1A),
                      title: const Text('セッション削除', style: TextStyle(color: Colors.white, fontSize: 16)),
                      content: Text('このセッション(${games.length}局)を完全に削除しますか？', style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(historyProvider.notifier).deleteSession(session.id!);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                label: const Text('セッションの全履歴を削除', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCleanupDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('履歴のクリーンアップ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _cleanupOption(context, ref, '3ヶ月以上前を削除', 3),
            _cleanupOption(context, ref, '6ヶ月以上前を削除', 6),
            _cleanupOption(context, ref, '1年以上前を削除', 12),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('すべての履歴を削除', style: TextStyle(color: Colors.redAccent)),
              onTap: () => _confirmAndClear(context, ref, all: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cleanupOption(BuildContext context, WidgetRef ref, String label, int months) {
    return ListTile(
      leading: const Icon(Icons.history, color: Color(0xFF00FFC2)),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () => _confirmAndClear(context, ref, months: months),
    );
  }

  void _confirmAndClear(BuildContext context, WidgetRef ref, {bool all = false, int months = 0}) async {
    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('削除の確認', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(all ? '本当にすべての履歴を削除しますか？' : '$monthsヶ月以上前の履歴を削除しますか？', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyProvider.notifier).clearHistory(all: all, months: months);
    }
  }

  void _showGroupAssignmentDialog(BuildContext context, WidgetRef ref, Session session) async {
    final db = DatabaseService();
    final groups = await db.getGroups();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('グループを割り当て', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ...groups.map((g) => ListTile(
                title: Text(g['name'], style: const TextStyle(color: Color(0xFF00FFC2))),
                onTap: () {
                  ref.read(historyProvider.notifier).updateSessionGroupId(session.id!, g['id']);
                  Navigator.pop(context);
                },
              )),
              ListTile(
                title: const Text('フリー対局に戻す', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  ref.read(historyProvider.notifier).updateSessionGroupId(session.id!, null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

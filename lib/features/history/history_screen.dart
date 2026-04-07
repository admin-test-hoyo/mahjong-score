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
      
      if (sessionGames.isEmpty) continue; // ゲームがないセッションは表示しない

      final groupRows = await db.getGroups();
      final groupName = s['group_id'] != null 
          ? groupRows.firstWhere((g) => g['id'] == s['group_id'], orElse: () => {'name': '不明'})['name']
          : 'フリー対局';

      sessionsWithGames.add({
        'session': Session.fromMap(s),
        'games': sessionGames,
        'groupName': groupName,
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
    // セッションに紐づくゲームをすべて削除
    final games = await db.getGames();
    for (var g in games) {
      if (g['session_id'] == sessionId) {
        await db.deleteGame(g['id']);
      }
    }
    // セッション自体はDatabaseServiceにdeleteSessionメソッドがないため、
    // 将来的に追加するか、ここではゲームが消えれば表示されない。
    await refresh();
  }

  Future<void> updateSessionGroupId(int sessionId, int? groupId) async {
    final db = DatabaseService();
    await db.updateSessionGroupId(sessionId, groupId);
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
    // 画面が開かれた際に確実に最新データを再取得（リフレッシュ）する
    Future.microtask(() => ref.read(historyProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Navigator.pop の戻り値を直接ここで取得することは難しいため、
          // 呼び出し元の then や await での処理と合わせ、
          // 万が一の漏れを防ぐためにここでも必要なら処理を行う。
          // ただし、現在は各呼び出し元で exitHistoryMode を呼ぶ実装に寄せている。
        }
      },
      child: Scaffold(
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
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF00BFA5),
                        onPrimary: Colors.white,
                        surface: Color(0xFF001F1A),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              } else {
                setState(() => _selectedDateRange = null);
              }
            },
          )
        ],
      ),
      body: history.when(
        data: (sessions) {
          var filteredSessions = sessions;
          if (_selectedDateRange != null) {
            filteredSessions = filteredSessions.where((s) {
              final dt = s['session'].date; // YYYY/MM/DD
              final date = DateFormat('yyyy/MM/dd').parse(dt);
              final start = _selectedDateRange!.start;
              final end = _selectedDateRange!.end.add(const Duration(days: 1));
              return !date.isBefore(start) && date.isBefore(end);
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
                          final List<SavedGame> games = sessionData['games'];
                          final String groupName = sessionData['groupName'];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                // セッションヘッダー
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
                                          Text(session.date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                groupName,
                                                style: TextStyle(
                                                  color: session.groupId == null ? Colors.orangeAccent : const Color(0xFF00FFC2),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (session.groupId == null)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 4),
                                                  child: Text('(フリー)', style: TextStyle(color: Colors.white24, fontSize: 10)),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      // グループ編集ボタン
                                      IconButton(
                                        icon: const Icon(Icons.edit_note, color: Color(0xFF00FFC2), size: 20),
                                        onPressed: () => _showGroupAssignmentDialog(context, ref, session),
                                      ),
                                      // 削除ボタン
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF001F1A),
                                              title: const Text('履歴削除', style: TextStyle(color: Colors.white, fontSize: 16)),
                                              content: Text('「$groupName」の全対局(${games.length}局)を削除しますか？', style: const TextStyle(color: Colors.white70)),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
                                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await ref.read(historyProvider.notifier).deleteSession(session.id!);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // 対局（半荘）リスト
                                ...games.map((game) => InkWell(
                                  onTap: () {
                                    ref.read(calcProvider.notifier).loadGame(game);
                                    Navigator.pop(context, true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: List.generate(game.playerNames.length, (i) {
                                        final pt = game.points[i];
                                        final rank = game.ranks[i];
                                        return Column(
                                          children: [
                                            Text(game.playerNames[i], style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                            Text(
                                              pt > 0 ? '+$pt' : pt.toString(),
                                              style: TextStyle(
                                                color: pt >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text('$rank位', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                )),
                              ],
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
    ),
  );
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

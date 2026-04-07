import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/db_models.dart';
import '../calc/calc_state.dart';

class HistoryNotifier extends AsyncNotifier<List<SavedGame>> {
  @override
  Future<List<SavedGame>> build() async {
    return _fetchGames();
  }

  Future<List<SavedGame>> _fetchGames() async {
    final db = DatabaseService();
    final rows = await db.getGames();
    return rows.map((e) => SavedGame.fromMap(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchGames());
  }

  Future<void> deleteGame(int id) async {
    final db = DatabaseService();
    await db.deleteGame(id);
    await refresh();
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<SavedGame>>(() {
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
        data: (allGames) {
          var games = allGames;
          if (_selectedDateRange != null) {
            games = games.where((g) {
              final dt = g.date;
              final start = _selectedDateRange!.start;
              final end = _selectedDateRange!.end.add(const Duration(days: 1));
              return !dt.isBefore(start) && dt.isBefore(end);
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
                child: games.isEmpty 
                  ? const Center(child: Text('対局履歴がありません', style: TextStyle(color: Colors.white24)))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(historyProvider.notifier).refresh(),
                      color: const Color(0xFF00FFC2),
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return InkWell(
                  onTap: () {
                    ref.read(calcProvider.notifier).loadGame(game);
                    Navigator.pop(context, true); // 選択時は true を返す
                  },
                  child: Dismissible(
                    key: Key(game.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.redAccent.withOpacity(0.2),
                      child: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                    onDismissed: (_) async {
                      final currentId = ref.read(calcProvider).currentId;
                      await ref.read(historyProvider.notifier).deleteGame(game.id!);
                      if (currentId == game.id) {
                        ref.read(calcProvider.notifier).resetToNewEntry();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '4人',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('yyyy/MM/dd').format(game.date),
                                style: const TextStyle(color: Colors.white24, fontSize: 10),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF001F1A),
                                      title: const Text('対局削除', style: TextStyle(color: Colors.white, fontSize: 16)),
                                      content: const Text('この対局データを削除しますか？', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    final currentId = ref.read(calcProvider).currentId;
                                    await ref.read(historyProvider.notifier).deleteGame(game.id!);
                                    if (currentId == game.id) {
                                      ref.read(calcProvider.notifier).resetToNewEntry();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(game.playerNames.length, (i) {
                              final rank = game.ranks[i];
                              final pt = game.points[i];
                              return Column(
                                children: [
                                  Text(game.playerNames[i],
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$rank位',
                                    style: TextStyle(
                                      color: rank == 1 ? const Color(0xFF00FFC2) : Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    pt > 0 ? '+$pt' : pt.toString(),
                                    style: TextStyle(
                                      color: pt >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
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
        error: (e, s) {
          // If the error is just that nothing was found or DB not ready, show info instead of error
          return const Center(child: Text('対局履歴がありません', style: TextStyle(color: Colors.white24)));
        },
      ),
    ));
  }
}

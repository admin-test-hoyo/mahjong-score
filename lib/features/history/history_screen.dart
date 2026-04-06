import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/db_models.dart';

final historyProvider = ChangeNotifierProvider((ref) => HistoryNotifier());

class HistoryNotifier extends ChangeNotifier {
  List<SavedGame> _games = [];
  List<SavedGame> get games => _games;
  bool _loading = true;
  bool get loading => _loading;

  HistoryNotifier() {
    refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    final db = DatabaseService();
    final rows = await db.getGames();
    _games = rows.map((e) => SavedGame.fromMap(e)).toList();
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteGame(int id) async {
    final db = DatabaseService();
    await db.deleteGame(id);
    await refresh();
  }
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('対局履歴', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
      ),
      body: notifier.loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
        : notifier.games.isEmpty 
          ? const Center(child: Text('履歴がありません', style: TextStyle(color: Colors.white24)))
          : RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              color: const Color(0xFF00FFC2),
              child: ListView.builder(
                itemCount: notifier.games.length,
                itemBuilder: (context, index) {
                  final game = notifier.games[index];
                  return Dismissible(
                    key: Key(game.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.redAccent.withOpacity(0.2),
                      child: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                    onDismissed: (_) => notifier.deleteGame(game.id!),
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
                                  color: game.type == '3-player' ? Colors.orangeAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  game.type == '3-player' ? '3人' : '4人',
                                  style: TextStyle(
                                    color: game.type == '3-player' ? Colors.orangeAccent : Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('yyyy/MM/dd HH:mm').format(game.date),
                                style: const TextStyle(color: Colors.white24, fontSize: 10),
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
                                  Text(game.playerNames[i], style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${rank}位',
                                    style: TextStyle(
                                      color: rank == 1 ? const Color(0xFF00FFC2) : Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    pt > 0 ? '+${pt}' : pt.toString(),
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
                  );
                },
              ),
            ),
    );
  }
}
  }
}

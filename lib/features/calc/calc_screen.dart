import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/calculator.dart';
import '../../core/models/app_config.dart';
import '../../core/models/db_models.dart';
import 'calc_state.dart';
import '../history/history_screen.dart';
import '../stats/stats_screen.dart';
import '../group/group_screen.dart';

class CalcScreen extends ConsumerWidget {
  const CalcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final state = ref.watch(calcProvider);

    ref.listen<List<Map<String, dynamic>>?>(
      calcProvider.select((s) => s.possibleGroupMatches),
      (previous, next) {
        if (next != null && next.isNotEmpty) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF001F1A),
              title: const Text('グループの自動判別', style: TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('複数のグループが一致しました。保存先を選択してください。', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  ...next.map((g) => ListTile(
                    title: Text(g['name'], style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
                    onTap: () {
                      ref.read(calcProvider.notifier).setSelectedGroupId(g['id']);
                      Navigator.pop(context);
                    },
                  )),
                  ListTile(
                    title: const Text('フリー対局として保存', style: TextStyle(color: Colors.white54)),
                    onTap: () {
                      ref.read(calcProvider.notifier).setSelectedGroupId(null);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
    
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      drawer: const MainDrawer(),
      appBar: AppBar(
        leading: state.currentId != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF00FFC2)),
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
                if (result != true) {
                  ref.read(calcProvider.notifier).exitHistoryMode();
                }
              },
            )
          : null,
        title: GestureDetector(
          onTap: () => ref.read(calcProvider.notifier).resetGame(),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              state.currentId == null ? '麻雀スコア表' : '麻雀スコア表(履歴)',
              style: const TextStyle(
                color: Color(0xFF00FFC2),
                fontWeight: FontWeight.bold,
                fontSize: 22.0, // 一回り大きく (18.0 -> 22.0)
              ),
            ),
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00FFC2), size: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            onPressed: () => _showSettingsModal(context, ref)
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFF00FFC2), size: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            onPressed: () async {
              final calcNotifier = ref.read(calcProvider.notifier);
              final currentState = ref.read(calcProvider);
              final isUpdate = currentState.currentId != null;

              if (isUpdate) {
                // 更新の場合
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF001F1A),
                    title: const Text('更新の確認', style: TextStyle(color: Colors.white, fontSize: 16)),
                    content: const Text('画面内容で更新します。よろしいですか？', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK', style: TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold))),
                    ],
                  ),
                );

                if (confirmed == true) {
                  // 更新時は現在保持しているデータの日付（または現在日時）を使用
                  // 厳密には既存データをDBから引くべきだが、Webでのビルドエラー回避のため
                  // stateから取得するか、DateTime.now()を暫定で使用（calc_state側で調整可能）
                  final result = await calcNotifier.saveCurrentSession(DateTime.now());
                  if (context.mounted) {
                    _showSaveSnackBar(context, result);
                    if (result == SaveResult.registered || result == SaveResult.updated) {
                      ref.read(historyProvider.notifier).refresh();
                    }
                  }
                }
              } else {
                // 新規登録の場合
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  locale: const Locale('ja'),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF00BFA5),
                        onPrimary: Color(0xFF004D40),
                        surface: Color(0xFF001F1A),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );

                if (selectedDate != null && context.mounted) {
                  final dateStr = "${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}";
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF001F1A),
                      title: const Text('登録の確認', style: TextStyle(color: Colors.white, fontSize: 16)),
                      content: Text('$dateStrの対局データとして登録します。よろしいですか？', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK', style: TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    final result = await calcNotifier.saveCurrentSession(selectedDate);
                    if (context.mounted) {
                      _showSaveSnackBar(context, result);
                      if (result == SaveResult.registered || result == SaveResult.updated) {
                        ref.read(historyProvider.notifier).refresh();
                      }
                    }
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF5252), size: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            onPressed: () => _confirmReset(context, ref)
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMainDataTable(context, ref)),
            _buildBottomSummaryFooter(context, ref),
          ],
        ),
      ),
    );
  }

  void _showSaveSnackBar(BuildContext context, SaveResult result) {
    String msg = '保存に失敗しました。';
    if (result == SaveResult.registered) msg = '対局情報を登録しました。';
    if (result == SaveResult.updated) msg = '対局情報を更新しました。';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showSettingsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF001F1A), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => const SettingsModal());
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF001F1A), title: Text('全データをリセットしますか？', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)), content: Text('入力済みのスコアはすべて削除され、プレイヤー名も初期化されます。', style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('キャンセル', style: GoogleFonts.robotoMono(color: Colors.white54))), TextButton(onPressed: () { ref.read(calcProvider.notifier).resetGame(); Navigator.pop(context); }, child: Text('リセット', style: GoogleFonts.robotoMono(color: const Color(0xFFFF5252), fontWeight: FontWeight.bold)))]));
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

  Widget _buildMainDataTable(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final games = state.games;
    final config = ref.watch(configProvider);
    const expectedPlayers = 4;

    return LayoutBuilder(builder: (context, constraints) {
      const double ctrlWidth = 35;
      final double available = constraints.maxWidth - (ctrlWidth * 3) - 12;
      final double pWidth = available / expectedPlayers;

      return SingleChildScrollView(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.white10),
          child: DataTable(
            columnSpacing: 0,
            horizontalMargin: 4,
            showCheckboxColumn: false,
            headingTextStyle: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            dataTextStyle: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13),
            columns: [
              DataColumn(label: SizedBox(width: ctrlWidth, child: const Center(child: Text('No')))),
              ...List.generate(expectedPlayers, (i) => DataColumn(label: SizedBox(width: pWidth, child: Center(child: PlayerNameField(index: i, initialName: state.playerNames[i]))))),
              DataColumn(label: SizedBox(width: ctrlWidth, child: const Center(child: Text('Chk')))),
              DataColumn(label: SizedBox(width: ctrlWidth, child: const Center(child: Text('Del')))),
            ],
            rows: [
              ...games.asMap().entries.map((e) {
                final idx = e.key; final game = e.value;
                final sum = game.inputs.where((p) => p.id <= expectedPlayers).fold(0, (s, p) => s + p.score);
                final isValid = sum == config.targetTotalScore;
                List<PlayerResult>? results;
                if (isValid) {
                  try { results = MahjongCalculator.calculate(inputs: game.inputs.where((p) => p.id <= expectedPlayers).toList(), rule: state.rule.copyWith(oka: config.oka, uma: _buildUmaList(config.umaText)), config: config, startingOyaIndex: game.startingOyaIndex); } catch (_) {}
                }
                return DataRow(onSelectChanged: (_) => _showEditModal(context, ref, game), cells: [
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: Colors.white24))))),
                  ...List.generate(expectedPlayers, (pIdx) {
                    final p = game.inputs.firstWhere((p) => p.id == pIdx + 1, orElse: () => const PlayerInput(id: 0, score: 0));
                    String val = p.score.toCommaString(); Color col = Colors.white70;
                    if (results != null) {
                      final r = results.firstWhere((r) => r.id == pIdx + 1).finalPoint;
                      val = r > 0 ? '+${r.toCommaString()}' : r.toCommaString();
                      col = r < 0 ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);
                    }
                    return DataCell(SizedBox(width: pWidth, child: Center(child: Text(val, style: GoogleFonts.robotoMono(color: col, fontWeight: results != null ? FontWeight.bold : FontWeight.normal)))));
                  }),
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: GestureDetector(
                    onTap: isValid ? null : () {
                      final diff = config.targetTotalScore - sum;
                      final msg = diff > 0 ? '$diff点不足しています' : '${diff.abs()}点超過しています';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
                    },
                    child: Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? const Color(0xFF00FFC2).withOpacity(0.3) : Colors.redAccent, size: 16),
                  )))),
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 16), onPressed: () {
                    ref.read(calcProvider.notifier).deleteGame(game.id);
                  })))),
                ]);
              }),
              DataRow(color: MaterialStateProperty.all(Colors.black12), cells: [
                const DataCell(Center(child: Icon(Icons.stars, color: Colors.orangeAccent, size: 14))),
                ...List.generate(expectedPlayers, (i) => DataCell(SizedBox(width: pWidth, child: Center(child: TextFormField(initialValue: state.globalChips[i] == 0 ? '' : state.globalChips[i].toString(), keyboardType: const TextInputType.numberWithOptions(signed: true), textAlign: TextAlign.center, style: GoogleFonts.robotoMono(color: Colors.orangeAccent, fontSize: 13), decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0', hintStyle: TextStyle(color: Colors.white12)), onChanged: (v) => ref.read(calcProvider.notifier).updateGlobalChip(i + 1, int.tryParse(v) ?? 0)))))),
                DataCell(Center(child: Text(state.globalChips.sublist(0, expectedPlayers).fold(0, (s, c) => s + c) == 0 ? '' : 'ERR', style: const TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)))),
                const DataCell(SizedBox()),
              ]),
              DataRow(cells: [DataCell(Center(child: IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00FFC2), size: 20), onPressed: () => ref.read(calcProvider.notifier).addGame()))), ...List.generate(expectedPlayers, (_) => const DataCell(SizedBox())), const DataCell(SizedBox()), const DataCell(SizedBox())]),
            ],
          ),
        ),
      );
    });
  }

  void _showYakumanDialog(BuildContext context, WidgetRef ref, GameRecord game, int winnerId) {
    final state = ref.read(calcProvider);
    const players = 4;
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF001F1A),
      title: Text('${state.playerNames[winnerId-1]} の役満設定', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('和了タイプを選択してください', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bolt, color: Colors.orangeAccent, size: 18),
              label: const Text('ツモ和了', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.withOpacity(0.1), foregroundColor: Colors.orangeAccent),
              onPressed: () {
                ref.read(calcProvider.notifier).setYakumanTsumo(game.id, winnerId);
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('ロン (放銃者を選択)', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const Divider(color: Colors.white10),
          ...List.generate(players, (pIdx) => pIdx + 1).where((id) => id != winnerId).map((loserId) => ListTile(
            dense: true,
            title: Text('${state.playerNames[loserId - 1]} が放銃', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            onTap: () {
              ref.read(calcProvider.notifier).setYakumanRon(game.id, winnerId, loserId);
              Navigator.pop(ctx);
            },
          )),
        ],
      ),
    ));
  }

  void _showTobiDialog(BuildContext context, WidgetRef ref, GameRecord game, int blownPlayerId) {
    final state = ref.read(calcProvider);
    const players = 4;
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final updatedGame = ref.watch(calcProvider).games.firstWhere((g) => g.id == game.id);
      final p = updatedGame.inputs.firstWhere((inp) => inp.id == blownPlayerId);
      final currentBlowerId = p.blownByPlayerId;

      return AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: Text('${state.playerNames[blownPlayerId-1]} を飛ばした人を選択', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('飛ばした人にチェックを入れてください', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              ...List.generate(players, (i) => i + 1).where((id) => id != blownPlayerId).map((id) {
                final isBlower = currentBlowerId == id;
                return CheckboxListTile(
                  title: Text(state.playerNames[id - 1], style: TextStyle(color: isBlower ? const Color(0xFF00FFC2) : Colors.white70)),
                  value: isBlower,
                  activeColor: const Color(0xFF00FFC2),
                  checkColor: const Color(0xFF004D40),
                  onChanged: (val) {
                    ref.read(calcProvider.notifier).setBlownBy(game.id, blownPlayerId, val == true ? id : null);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル'))],
      );
    }));
  }

  void _showEditModal(BuildContext context, WidgetRef ref, GameRecord game) {
    const players = 4;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF001F1A), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Consumer(builder: (context, ref, child) {
        final updatedGame = ref.watch(calcProvider).games.firstWhere((g) => g.id == game.id);
        return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Spacer to balance the IconButton
                Text('スコア編集', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.cleaning_services, color: Colors.white38, size: 20),
                  onPressed: () => ref.read(calcProvider.notifier).resetGameRecord(game.id),
                  tooltip: '入力内容をクリア',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  const SizedBox(width: 34),
                  const Expanded(child: Text('名前', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 60, child: Center(child: Text('点数', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 32, child: Center(child: Text('トビ', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 8),
                  const SizedBox(width: 32, child: Center(child: Text('役満', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            ...updatedGame.inputs.where((p) => p.id <= players).map((p) => PlayerInputCard(gameId: game.id, player: p, showYakuman: (id) => _showYakumanDialog(context, ref, updatedGame, id), showTobi: (id) => _showTobiDialog(context, ref, updatedGame, id))), 
            const SizedBox(height: 16)]));
    }));
  }

  Widget _buildBottomSummaryFooter(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final config = ref.watch(configProvider);
    const players = 4;
    
    final summaries = { for (int i = 1; i <= players; i++) i: {'pt': 0, 'chip': 0} };
    
    // 集計処理
    for (var g in state.games) {
      if (g.inputs.where((ip) => ip.id <= players).fold(0, (s, ip) => s + ip.score) == config.targetTotalScore) {
        try {
          final res = MahjongCalculator.calculate(
            inputs: g.inputs.where((ip) => ip.id <= players).toList(),
            rule: state.rule.copyWith(oka: config.oka, uma: _buildUmaList(config.umaText)),
            config: config,
            startingOyaIndex: g.startingOyaIndex
          );
          for (var r in res) {
            summaries[r.id]!['pt'] = (summaries[r.id]!['pt'] ?? 0) + r.finalPoint;
            final pInput = g.inputs.firstWhere((inp) => inp.id == r.id);
            summaries[r.id]!['chip'] = (summaries[r.id]!['chip'] ?? 0) + pInput.chip;
          }
        } catch (_) {}
      }
    }
    for (int i=0; i<players; i++) {
       summaries[i+1]!['chip'] = (summaries[i+1]!['chip'] ?? 0) + state.globalChips[i];
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), 
      decoration: BoxDecoration(color: Colors.black26, border: const Border(top: BorderSide(color: Color(0xFF00FFC2), width: 1))), 
      child: Row(children: [
        for (int i = 1; i <= players; i++) 
          Expanded(child: _buildSumBlock(
            state.playerNames[i - 1], 
            summaries[i]!, 
            config, 
            players,
            state.snapshottedMoneys != null && state.snapshottedMoneys!.length >= i ? state.snapshottedMoneys![i-1] : null
          ))
      ])
    );
  }

  Widget _buildSumBlock(String name, Map<String, int> data, AppConfig conf, int players, [int? snapshottedMoney]) {
    final pt = data['pt']!; final ch = data['chip']!;
    
    // 収支計算 (Strict Formula: (Pt * Rate) + (Chip * ChipRate))
    final int income = (pt * conf.rate).toInt() + (ch * conf.chipRate).toInt();
    
    // 場代込計算 (Strict Formula: Income - (TotalFee / 4))
    final int finalBalance = snapshottedMoney ?? (income - (conf.gameFee / players)).round();
    
    return Column(mainAxisSize: MainAxisSize.min, children: [
      FittedBox(fit: BoxFit.scaleDown, child: Text(name, style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.normal), overflow: TextOverflow.ellipsis)),
      const SizedBox(height: 1),
      FittedBox(fit: BoxFit.scaleDown, child: Text('Pt:${pt.toCommaString()}|Ch:${ch.toCommaString()}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.normal))),
      const SizedBox(height: 1),
      FittedBox(fit: BoxFit.scaleDown, child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.normal),
          children: [
            const TextSpan(text: '収支:'),
            TextSpan(
              text: '¥${income.toCommaString()}',
              style: TextStyle(color: income < 0 ? const Color(0xFFFF5252) : Colors.white),
            ),
          ],
        ),
      )),
      FittedBox(fit: BoxFit.scaleDown, child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60),
          children: [
            const TextSpan(text: '場代込:'),
            TextSpan(
              text: '¥${finalBalance.toCommaString()}',
              style: TextStyle(color: finalBalance < 0 ? const Color(0xFFFF5252) : const Color(0xFF00FFC2)),
            ),
          ],
        ),
      )),
    ]);
  }
}

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: const Color(0xFF001F1A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF004D40)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('麻雀スコア表', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 20)),
                const Text('Ver 1.6', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          _drawerItem(context, ref, Icons.calculate, 'スコア計算', null),
          _drawerItem(context, ref, Icons.history, '対局履歴', const HistoryScreen()),
          _drawerItem(context, ref, Icons.analytics, '統計・分析', const StatsScreen()),
          _drawerItem(context, ref, Icons.groups, 'グループ管理', const GroupScreen()),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, WidgetRef ref, IconData icon, String title, Widget? screen) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00FFC2), size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => screen)).then((result) {
            if (screen is HistoryScreen && result != true) {
              ref.read(calcProvider.notifier).exitHistoryMode();
            }
          });
        } else {
          // If no screen and it's "スコア計算", act as home button / reset game
          ref.read(calcProvider.notifier).resetGame();
        }
      },
    );
  }
}

class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('アプリ設定', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => Navigator.pop(context))]),
        const SizedBox(height: 16),
        _row([_field(ref, 'Rate', config.rate.toString(), (v) => ref.read(configProvider.notifier).updateRate(double.tryParse(v) ?? 0), isDec: true), _field(ref, '場代', config.gameFee.toString(), (v) => ref.read(configProvider.notifier).updateGameFee(int.tryParse(v) ?? 0))]),
        const SizedBox(height: 12),
        _row([_field(ref, 'Chip', config.chipRate.toString(), (v) => ref.read(configProvider.notifier).updateChipRate(int.tryParse(v) ?? 0)), _field(ref, 'Uma (例: 10-30)', config.umaText, (v) => ref.read(configProvider.notifier).updateUmaText(v))]),
        const SizedBox(height: 12),
        _row([_field(ref, '配給原点', config.startingPoints.toString(), (v) => ref.read(configProvider.notifier).updateStartingPoints(int.tryParse(v) ?? 25000)), _field(ref, 'Oka', config.oka.toString(), (v) => ref.read(configProvider.notifier).updateOka(int.tryParse(v) ?? 0))]),
        const SizedBox(height: 12),
        _row([_field(ref, '役満賞(ツモ)', config.yakumanTsumoPrize.toString(), (v) => ref.read(configProvider.notifier).updateYakumanTsumoPrize(int.tryParse(v) ?? 5), suffixText: 'Pt'), _field(ref, '役満賞(ロン)', config.yakumanRonPrize.toString(), (v) => ref.read(configProvider.notifier).updateYakumanRonPrize(int.tryParse(v) ?? 10), suffixText: 'Pt')]),
        const SizedBox(height: 12),
        _row([_field(ref, 'トビ賞', config.tobiPrize.toString(), (v) => ref.read(configProvider.notifier).updateTobiPrize(int.tryParse(v) ?? 10), suffixText: 'Pt'), const SizedBox()]),
        const SizedBox(height: 32),
    ]));
  }
  Widget _row(List<Widget> c) => Row(children: c.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList());
  Widget _field(WidgetRef ref, String l, String i, Function(String) o, {bool isDec = false, String? suffixText}) => TextFormField(initialValue: i, keyboardType: TextInputType.numberWithOptions(decimal: isDec), textAlign: TextAlign.center, style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 15), decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white38, fontSize: 11), filled: true, fillColor: Colors.white.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), suffixText: suffixText, suffixStyle: const TextStyle(color: Colors.white24, fontSize: 10)), onChanged: o);
}


class PlayerNameField extends ConsumerStatefulWidget {
  final int index; final String initialName;
  const PlayerNameField({super.key, required this.index, required this.initialName});
  @override ConsumerState<PlayerNameField> createState() => _PlayerNameFieldState();
}
class _PlayerNameFieldState extends ConsumerState<PlayerNameField> {
  late TextEditingController _c;
  @override void initState() { super.initState(); _c = TextEditingController(text: widget.initialName); }
  @override void didUpdateWidget(PlayerNameField old) { super.didUpdateWidget(old); if (old.initialName != widget.initialName && _c.text != widget.initialName) _c.text = widget.initialName; }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => TextField(controller: _c, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 11, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none), onChanged: (v) => ref.read(calcProvider.notifier).updatePlayerName(widget.index + 1, v));
}

class PlayerInputCard extends ConsumerStatefulWidget {
  final String gameId; final PlayerInput player;
  final Function(int) showYakuman; final Function(int) showTobi;
  const PlayerInputCard({super.key, required this.gameId, required this.player, required this.showYakuman, required this.showTobi});
  @override ConsumerState<PlayerInputCard> createState() => _PlayerInputCardState();
}
class _PlayerInputCardState extends ConsumerState<PlayerInputCard> {
  late TextEditingController _s;
  @override void initState() { super.initState(); _s = TextEditingController(text: widget.player.score == 0 ? '' : widget.player.score.toString()); }
  @override void didUpdateWidget(PlayerInputCard old) { super.didUpdateWidget(old); if (old.player.score != widget.player.score) { if (widget.player.score != (int.tryParse(_s.text) ?? 0)) _s.text = widget.player.score == 0 ? '' : widget.player.score.toString(); } }
  @override void dispose() { _s.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final state = ref.watch(calcProvider); final game = state.games.firstWhere((g) => g.id == widget.gameId);
    final oya = game.startingOyaIndex == widget.player.id - 1; final wind = ['東', '南', '西', '北'][((widget.player.id - 1) - game.startingOyaIndex + 4) % 4];
    
    // Tobi Icon Logic
    final tobiPt = widget.player.tobiPt;
    IconData tobiIcon = Icons.favorite_border; Color tobiColor = Colors.grey.shade400;
    if (tobiPt > 0) { tobiIcon = Icons.favorite; tobiColor = Colors.red; }
    else if (tobiPt < 0) { tobiIcon = Icons.heart_broken; tobiColor = Colors.blueGrey; }
    
    // Yakuman Icon Logic
    final yakumanPt = widget.player.yakumanPt;
    IconData yakumanIcon = Icons.emoji_events; Color yakumanColor = Colors.grey.shade400;
    if (yakumanPt > 0) { yakumanIcon = Icons.emoji_events; yakumanColor = Colors.orange; }
    else if (yakumanPt < 0) { yakumanIcon = Icons.sentiment_dissatisfied; yakumanColor = Colors.blueGrey; }

    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF002922), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Row(children: [
        GestureDetector(onTap: () => ref.read(calcProvider.notifier).setStartingOya(widget.gameId, widget.player.id - 1), child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: oya ? const Color(0xFF00FFC2) : Colors.transparent, border: Border.all(color: oya ? const Color(0xFF00FFC2) : Colors.white24)), child: Center(child: Text(wind, style: TextStyle(color: oya ? const Color(0xFF004D40) : Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: Text(state.playerNames[widget.player.id - 1], style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: TextField(
            controller: _s, 
            textAlign: TextAlign.center, 
            keyboardType: const TextInputType.numberWithOptions(signed: true), 
            maxLength: 6, // #2 Allow up to 6 digits (999,999)
            style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 16, fontWeight: FontWeight.bold), 
            decoration: InputDecoration(
                isDense: true, 
                counterText: '', // Hide the length counter text
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), 
                hintText: '0', 
                hintStyle: const TextStyle(color: Colors.white12), 
                filled: true,
                fillColor: Colors.black12,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)), 
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00FFC2)))
            ), 
            onChanged: (v) => ref.read(calcProvider.notifier).updateScore(widget.gameId, widget.player.id, int.tryParse(v) ?? 0)
        )),
        const SizedBox(width: 12),
        SizedBox(width: 34, child: IconButton(icon: Icon(tobiIcon, color: tobiColor, size: 20), onPressed: () => widget.showTobi(widget.player.id), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
        const SizedBox(width: 4),
        SizedBox(width: 34, child: IconButton(icon: Icon(yakumanIcon, color: yakumanColor, size: 20), onPressed: () => widget.showYakuman(widget.player.id), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
    ]));
  }
}

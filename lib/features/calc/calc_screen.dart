import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/calculator.dart';
import '../../core/models/app_config.dart';
import 'calc_state.dart';

extension IntFormat on int {
  String toCommaString() {
    return toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}

class CalcScreen extends ConsumerWidget {
  const CalcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('麻雀スコア表', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        actions: [
          // 3P/4P Toggle with fixed styling to prevent overlap
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('4人', style: TextStyle(fontSize: 11)))),
                ButtonSegment(value: true, label: Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('3人', style: TextStyle(fontSize: 11)))),
              ],
              selected: {config.isThreePlayer},
              onSelectionChanged: (val) => ref.read(configProvider.notifier).updateIsThreePlayer(val.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.black26,
                selectedBackgroundColor: const Color(0xFF00FFC2),
                selectedForegroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white60,
                side: BorderSide(color: const Color(0xFF00FFC2).withOpacity(0.2)),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.settings, color: Color(0xFF00FFC2), size: 18), onPressed: () => _showSettingsModal(context, ref)),
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFFF5252), size: 18), onPressed: () => _confirmReset(context, ref)),
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

  void _showSettingsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF001F1A), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => const SettingsModal());
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF001F1A), title: Text('全データをリセットしますか？', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)), content: Text('入力済みのスコアはすべて削除され、プレイヤー名も初期化されます。', style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('キャンセル', style: GoogleFonts.robotoMono(color: Colors.white54))), TextButton(onPressed: () { ref.read(calcProvider.notifier).resetGame(); Navigator.pop(context); }, child: Text('リセット', style: GoogleFonts.robotoMono(color: const Color(0xFFFF5252), fontWeight: FontWeight.bold)))]));
  }

  List<int> _buildUmaList(String umaText, bool isThreePlayer) {
    final parts = umaText.split('-');
    if (parts.length == 2) {
      final a = int.tryParse(parts[0]) ?? 10;
      final b = int.tryParse(parts[1]) ?? 20;
      return isThreePlayer ? [a + b, -a, -b] : [b, a, -a, -b];
    }
    return isThreePlayer ? [20, 0, -20] : [20, 10, -10, -20];
  }

  Widget _buildMainDataTable(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final games = state.games;
    final config = ref.watch(configProvider);
    final expectedPlayers = config.isThreePlayer ? 3 : 4;

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
                  try { results = MahjongCalculator.calculate(inputs: game.inputs.where((p) => p.id <= expectedPlayers).toList(), rule: state.rule.copyWith(oka: config.oka, uma: _buildUmaList(config.umaText, config.isThreePlayer)), config: config, startingOyaIndex: game.startingOyaIndex); } catch (_) {}
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
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? const Color(0xFF00FFC2).withOpacity(0.3) : Colors.redAccent, size: 16)))),
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 16), onPressed: () => ref.read(calcProvider.notifier).deleteGame(game.id))))),
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
    final config = ref.read(configProvider);
    final players = config.isThreePlayer ? 3 : 4;
    
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
    final config = ref.read(configProvider);
    final players = config.isThreePlayer ? 3 : 4;
    
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
    final config = ref.read(configProvider); final players = config.isThreePlayer ? 3 : 4;
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
    final state = ref.watch(calcProvider); final config = ref.watch(configProvider); final players = config.isThreePlayer ? 3 : 4;
    List<List<PlayerResult>> all = [];
    for (var g in state.games) {
        if (g.inputs.where((p) => p.id <= players).fold(0, (s, p) => s + p.score) == config.targetTotalScore) {
            try { all.add(MahjongCalculator.calculate(inputs: g.inputs.where((p) => p.id <= players).toList(), rule: state.rule.copyWith(oka: config.oka, uma: _buildUmaList(config.umaText, config.isThreePlayer)), config: config)); } catch (_) {}
        }
    }
    final summaries = { for (int i = 1; i <= players; i++) i: {'pt': 0, 'chip': state.globalChips[i - 1]} };
    for (var res in all) { for (var p in res) { summaries[p.id]!['pt'] = summaries[p.id]!['pt']! + p.finalPoint; } }
    return Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.black26, border: const Border(top: BorderSide(color: Color(0xFF00FFC2), width: 1))), child: Row(children: [for (int i = 1; i <= players; i++) Expanded(child: _buildSumBlock(state.playerNames[i - 1], summaries[i]!, config, players))]));
  }

  Widget _buildSumBlock(String name, Map<String, int> data, AppConfig conf, int players) {
    final pt = data['pt']!; final ch = data['chip']!;
    final double raw = (pt * conf.rate) + (ch * conf.chipRate);
    final int fin = (raw - (conf.gameFee / players)).round();
    final int bFee = conf.roundingTenYen ? (raw / 10.0).ceil() * 10 : raw.round();
    final int fBal = conf.roundingTenYen ? (fin / 10.0).ceil() * 10 : fin;
    return Column(children: [Text(name, style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), Text('Pt:${pt.toCommaString()}|Ch:${ch.toCommaString()}', style: const TextStyle(color: Colors.white30, fontSize: 8)), Text('¥${bFee.toCommaString()}', style: TextStyle(color: bFee < 0 ? Colors.redAccent : Colors.white60, fontSize: 9)), Text('¥${fBal.toCommaString()}', style: TextStyle(color: fBal >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))]);
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text('役満賞', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(width: 12),
              const Text('ツモ', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: TextFormField(
                  initialValue: config.yakumanTsumoPrize.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                    suffixText: 'Pt',
                    suffixStyle: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  onChanged: (v) => ref.read(configProvider.notifier).updateYakumanTsumoPrize(int.tryParse(v) ?? 5),
                ),
              ),
              const SizedBox(width: 12),
              const Text('ロン', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: TextFormField(
                  initialValue: config.yakumanRonPrize.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                    suffixText: 'Pt',
                    suffixStyle: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  onChanged: (v) => ref.read(configProvider.notifier).updateYakumanRonPrize(int.tryParse(v) ?? 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _row([_field(ref, 'トビ賞', config.tobiPrize.toString(), (v) => ref.read(configProvider.notifier).updateTobiPrize(int.tryParse(v) ?? 10)), const SizedBox()]),
        const SizedBox(height: 32),
    ]));
  }
  Widget _row(List<Widget> c) => Row(children: c.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList());
  Widget _field(WidgetRef ref, String l, String i, Function(String) o, {bool isDec = false}) => TextFormField(initialValue: i, keyboardType: TextInputType.numberWithOptions(decimal: isDec), style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 15), decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white38, fontSize: 11), filled: true, fillColor: Colors.white.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), onChanged: o);
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
            style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 16, fontWeight: FontWeight.bold), 
            decoration: InputDecoration(
                isDense: true, 
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

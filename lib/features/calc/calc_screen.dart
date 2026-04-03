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
        title: Text('麻雀スコア表', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        centerTitle: false,
        actions: [
          // 3P/4P Toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('4人', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: true, label: Text('3人', style: TextStyle(fontSize: 12))),
              ],
              selected: {config.isThreePlayer},
              onSelectionChanged: (val) => ref.read(configProvider.notifier).updateIsThreePlayer(val.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.black26,
                selectedBackgroundColor: const Color(0xFF00FFC2),
                selectedForegroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white70,
                side: BorderSide(color: const Color(0xFF00FFC2).withOpacity(0.3)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00FFC2), size: 20),
            onPressed: () => _showSettingsModal(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF5252), size: 20),
            onPressed: () => _confirmReset(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildMainDataTable(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: _buildBottomSummaryFooter(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return const SettingsModal();
      },
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF001F1A),
          title: Text('全データをリセットしますか？', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)),
          content: Text('入力済みのスコアはすべて削除され、プレイヤー名も初期化されます。', style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('キャンセル', style: GoogleFonts.robotoMono(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                ref.read(calcProvider.notifier).resetGame();
                Navigator.of(context).pop();
              },
              child: Text('リセット', style: GoogleFonts.robotoMono(color: const Color(0xFFFF5252), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  List<int> _buildUmaList(String umaText, bool isThreePlayer) {
    final parts = umaText.split('-');
    if (parts.length == 2) {
      final a = int.tryParse(parts[0]) ?? 10;
      final b = int.tryParse(parts[1]) ?? 20;
      if (isThreePlayer) {
        return [a + b, -a, -b];
      } else {
        return [b, a, -a, -b];
      }
    }
    return isThreePlayer ? [20, 0, -20] : [20, 10, -10, -20];
  }

  Widget _buildMainDataTable(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final games = state.games;
    final playerNames = state.playerNames;
    final globalChips = state.globalChips;
    final config = ref.watch(configProvider);
    final expectedPlayers = config.isThreePlayer ? 3 : 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double noColWidth = 35;
        const double chkColWidth = 35;
        const double delColWidth = 35;
        final double availableWidth = constraints.maxWidth - noColWidth - chkColWidth - delColWidth - 10;
        final double playerColWidth = availableWidth / expectedPlayers;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: const Color(0xFF00FFC2).withOpacity(0.2),
              dataTableTheme: DataTableThemeData(
                headingRowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.4)),
                dataRowColor: MaterialStateProperty.all(Colors.transparent),
              ),
            ),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 0,
              horizontalMargin: 4,
              border: TableBorder.symmetric(
                inside: BorderSide(color: const Color(0xFF00FFC2).withOpacity(0.1), width: 1),
              ),
              headingTextStyle: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              dataTextStyle: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13),
              columns: [
                DataColumn(label: SizedBox(width: noColWidth, child: const Center(child: Text('No')))),
                ...List.generate(expectedPlayers, (i) {
                  return DataColumn(
                    label: SizedBox(
                      width: playerColWidth,
                      child: Center(
                        child: PlayerNameField(index: i, initialName: playerNames[i]),
                      ),
                    ),
                  );
                }),
                DataColumn(label: SizedBox(width: chkColWidth, child: const Center(child: Text('Chk')))),
                DataColumn(label: SizedBox(width: delColWidth, child: const Center(child: Text('Del')))),
              ],
              rows: [
                ...games.asMap().entries.map((entry) {
                  final index = entry.key;
                  final game = entry.value;

                  final scoreSum = game.inputs
                      .where((p) => p.id <= expectedPlayers)
                      .fold(0, (sum, p) => sum + p.score);
                  final isValid = scoreSum == config.targetTotalScore;

                  List<PlayerResult>? calculatedPoints;
                  if (isValid) {
                    try {
                      final currentUma = _buildUmaList(config.umaText, config.isThreePlayer);
                      final currentRule = state.rule.copyWith(oka: config.oka, uma: currentUma);
                      final enrichedInputs = game.inputs
                          .where((p) => p.id <= expectedPlayers)
                          .map((p) => PlayerInput(
                                id: p.id,
                                score: p.score,
                                chip: p.chip,
                                tobiPt: p.tobiPt,
                                yakumanPt: p.yakumanPt,
                                blownByPlayerId: p.blownByPlayerId,
                              ))
                          .toList();

                      calculatedPoints = MahjongCalculator.calculate(
                        inputs: enrichedInputs,
                        rule: currentRule,
                        config: config,
                        startingOyaIndex: game.startingOyaIndex,
                      );
                    } catch (_) {}
                  }

                  return DataRow(
                    onSelectChanged: (_) => _showEditModal(context, ref, game),
                    cells: [
                      DataCell(SizedBox(width: noColWidth, child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white38))))),
                      ...List.generate(expectedPlayers, (pIdx) {
                        final input = game.inputs.firstWhere((p) => p.id == pIdx + 1, orElse: () => const PlayerInput(id: 0, score: 0));
                        String displayValue = input.score.toCommaString();
                        Color textColor = Colors.white70;

                        if (calculatedPoints != null) {
                          final ptResult = calculatedPoints.firstWhere((p) => p.id == pIdx + 1).finalPoint;
                          displayValue = ptResult > 0 ? '+${ptResult.toCommaString()}' : ptResult.toCommaString();
                          textColor = ptResult < 0 ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);
                        }

                        return DataCell(
                          SizedBox(
                            width: playerColWidth,
                            child: Center(
                              child: Text(
                                displayValue,
                                style: GoogleFonts.robotoMono(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: calculatedPoints != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        SizedBox(width: chkColWidth, child: Center(
                          child: Icon(isValid ? Icons.check : Icons.priority_high,
                            color: isValid ? const Color(0xFF00FFC2).withOpacity(0.5) : Colors.redAccent, size: 16),
                        )),
                      ),
                      DataCell(
                        SizedBox(width: delColWidth, child: Center(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                            onPressed: () => ref.read(calcProvider.notifier).deleteGame(game.id),
                          ),
                        )),
                      ),
                    ],
                  );
                }),
                // Global Chip Row
                DataRow(
                  color: MaterialStateProperty.all(Colors.black.withOpacity(0.2)),
                  cells: [
                    const DataCell(SizedBox(width: noColWidth, child: Center(child: Icon(Icons.stars, color: Colors.orangeAccent, size: 14)))),
                    ...List.generate(expectedPlayers, (pIdx) {
                      final chip = globalChips[pIdx];
                      return DataCell(
                        SizedBox(
                          width: playerColWidth,
                          child: Center(
                            child: TextFormField(
                              initialValue: chip == 0 ? '' : chip.toString(),
                              keyboardType: const TextInputType.numberWithOptions(signed: true),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.robotoMono(color: Colors.orangeAccent, fontSize: 13),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0', hintStyle: TextStyle(color: Colors.white12)),
                              onChanged: (val) => ref.read(calcProvider.notifier).updateGlobalChip(pIdx + 1, int.tryParse(val) ?? 0),
                            ),
                          ),
                        ),
                      );
                    }),
                    DataCell(
                      SizedBox(width: chkColWidth, child: Center(
                        child: Text(
                          globalChips.sublist(0, expectedPlayers).fold(0, (sum, c) => sum + c) == 0 ? '' : 'ERR',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ))
                    ),
                    const DataCell(SizedBox(width: delColWidth)),
                  ]
                ),
                // Add Row
                DataRow(
                  cells: [
                    DataCell(
                      Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00FFC2), size: 20),
                          onPressed: () => ref.read(calcProvider.notifier).addGame(),
                        ),
                      ),
                    ),
                    ...List.generate(expectedPlayers, (_) => const DataCell(SizedBox())),
                    const DataCell(SizedBox()),
                    const DataCell(SizedBox()),
                  ]
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSummaryFooter(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final config = ref.watch(configProvider);
    final expectedPlayers = config.isThreePlayer ? 3 : 4;

    List<List<PlayerResult>> allValidResults = [];
    int validGamesCount = 0;

    for (var game in state.games) {
      final scoreSum = game.inputs.where((p) => p.id <= expectedPlayers).fold(0, (sum, p) => sum + p.score);
      if (scoreSum == config.targetTotalScore) {
        validGamesCount++;
        try {
          final currentUma = _buildUmaList(config.umaText, config.isThreePlayer);
          final currentRule = state.rule.copyWith(oka: config.oka, uma: currentUma);
          final enrichedInputs = game.inputs.where((p) => p.id <= expectedPlayers).map((p) => PlayerInput(id: p.id, score: p.score, chip: p.chip, tobiPt: p.tobiPt, yakumanPt: p.yakumanPt, blownByPlayerId: p.blownByPlayerId)).toList();
          allValidResults.add(MahjongCalculator.calculate(inputs: enrichedInputs, rule: currentRule, config: config));
        } catch (_) {}
      }
    }

    final Map<int, Map<String, int>> playerSummaries = { for (int i = 1; i <= expectedPlayers; i++) i: {'pt': 0, 'chip': state.globalChips[i - 1]} };
    for (var gameRes in allValidResults) {
      for (var pRes in gameRes) {
        playerSummaries[pRes.id]!['pt'] = playerSummaries[pRes.id]!['pt']! + pRes.finalPoint;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: const Border(top: BorderSide(color: Color(0xFF00FFC2), width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 1; i <= expectedPlayers; i++)
            Expanded(
              child: _buildSummaryBlock(state.playerNames[i - 1], playerSummaries[i]!, config, expectedPlayers),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryBlock(String title, Map<String, int> data, AppConfig config, int numPlayers) {
    final pt = data['pt']!;
    final chip = data['chip']!;
    final rawBalance = (pt * config.rate) + (chip * config.chipRate);
    final rawFinal = rawBalance - (config.gameFee / numPlayers).round();
    int finalBalance = config.roundingTenYen ? (rawFinal / 10.0).ceil() * 10 : rawFinal.round();
    int balanceBeforeFee = config.roundingTenYen ? (rawBalance / 10.0).ceil() * 10 : rawBalance.round();

    return Column(
      children: [
        Text(title, style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
        Text('Pt:${pt.toCommaString()}|Ch:${chip.toCommaString()}', style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 9)),
        Text('¥${balanceBeforeFee.toCommaString()}', style: GoogleFonts.robotoMono(color: balanceBeforeFee < 0 ? Colors.redAccent : Colors.white70, fontSize: 10)),
        Text('¥${finalBalance.toCommaString()}', style: GoogleFonts.robotoMono(color: finalBalance >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showEditModal(BuildContext context, WidgetRef ref, GameRecord game) {
    final config = ref.read(configProvider);
    final expectedPlayers = config.isThreePlayer ? 3 : 4;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('スコア編集', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...game.inputs.where((p) => p.id <= expectedPlayers).map((p) => PlayerInputCard(gameId: game.id, player: p)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class SettingsModal extends ConsumerStatefulWidget {
  const SettingsModal({super.key});
  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('アプリ設定', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          _buildRow([
            _buildField('Rate', config.rate.toString(), (v) => ref.read(configProvider.notifier).updateRate(double.tryParse(v) ?? 0), isDecimal: true),
            _buildField('場代', config.gameFee.toString(), (v) => ref.read(configProvider.notifier).updateGameFee(int.tryParse(v) ?? 0)),
          ]),
          const SizedBox(height: 12),
          _buildRow([
            _buildField('Chip', config.chipRate.toString(), (v) => ref.read(configProvider.notifier).updateChipRate(int.tryParse(v) ?? 0)),
            _buildField('Uma (例: 10-30)', config.umaText, (v) => ref.read(configProvider.notifier).updateUmaText(v)),
          ]),
          const SizedBox(height: 12),
          _buildRow([
            _buildField('配給原点', config.startingPoints.toString(), (v) => ref.read(configProvider.notifier).updateStartingPoints(int.tryParse(v) ?? 25000)),
            _buildField('Oka', config.oka.toString(), (v) => ref.read(configProvider.notifier).updateOka(int.tryParse(v) ?? 0)),
          ]),
          const SizedBox(height: 12),
          _buildRow([
            _buildField('トビ賞', config.tobiPrize.toString(), (v) => ref.read(configProvider.notifier).updateTobiPrize(int.tryParse(v) ?? 0)),
            _buildField('役満賞', config.yakumanPrize.toString(), (v) => ref.read(configProvider.notifier).updateYakumanPrize(int.tryParse(v) ?? 0)),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) => Row(children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList());

  Widget _buildField(String label, String initial, Function(String) onChanged, {bool isDecimal = false}) {
    return TextFormField(
      initialValue: initial,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

class PlayerNameField extends ConsumerStatefulWidget {
  final int index;
  final String initialName;
  const PlayerNameField({super.key, required this.index, required this.initialName});
  @override
  ConsumerState<PlayerNameField> createState() => _PlayerNameFieldState();
}

class _PlayerNameFieldState extends ConsumerState<PlayerNameField> {
  late TextEditingController _controller;
  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.initialName); }
  @override
  void didUpdateWidget(PlayerNameField old) { super.didUpdateWidget(old); if (old.initialName != widget.initialName && _controller.text != widget.initialName) { _controller.text = widget.initialName; } }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(controller: _controller, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 11, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none), onChanged: (val) => ref.read(calcProvider.notifier).updatePlayerName(widget.index + 1, val));
}

class PlayerInputCard extends ConsumerStatefulWidget {
  final String gameId;
  final PlayerInput player;
  const PlayerInputCard({super.key, required this.gameId, required this.player});
  @override
  ConsumerState<PlayerInputCard> createState() => _PlayerInputCardState();
}

class _PlayerInputCardState extends ConsumerState<PlayerInputCard> {
  late TextEditingController _scoreController;
  @override
  void initState() { super.initState(); _scoreController = TextEditingController(text: widget.player.score == 0 ? '' : widget.player.score.toString()); }
  @override
  void didUpdateWidget(PlayerInputCard old) { super.didUpdateWidget(old); if (old.player.score != widget.player.score) { if (widget.player.score != (int.tryParse(_scoreController.text) ?? 0)) { _scoreController.text = widget.player.score == 0 ? '' : widget.player.score.toString(); } } }
  @override
  void dispose() { _scoreController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
      final state = ref.watch(calcProvider);
      final game = state.games.firstWhere((g) => g.id == widget.gameId);
      final isOya = game.startingOyaIndex == widget.player.id - 1;
      final priority = ((widget.player.id - 1) - game.startingOyaIndex + 4) % 4;
      final windText = ['東', '南', '西', '北'][priority];
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF002922), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00FFC2).withOpacity(0.1))),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => ref.read(calcProvider.notifier).setStartingOya(widget.gameId, widget.player.id - 1),
              child: Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(shape: BoxShape.circle, color: isOya ? const Color(0xFF00FFC2) : Colors.transparent, border: Border.all(color: isOya ? const Color(0xFF00FFC2) : Colors.white38)), child: Center(child: Text(windText, style: TextStyle(color: isOya ? const Color(0xFF002922) : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)))),
            ),
            Expanded(child: Text(state.playerNames[widget.player.id - 1], style: const TextStyle(color: Colors.white70, fontSize: 13))),
            SizedBox(width: 100, child: TextField(controller: _scoreController, keyboardType: const TextInputType.numberWithOptions(signed: true), style: const TextStyle(color: Colors.greenAccent, fontSize: 16), decoration: const InputDecoration(isDense: true, hintText: '0', hintStyle: TextStyle(color: Colors.white12), border: InputBorder.none), onChanged: (v) => ref.read(calcProvider.notifier).updateScore(widget.gameId, widget.player.id, int.tryParse(v) ?? 0))),
            _buildSpecial(context, ref, game),
          ],
        ),
      );
  }

  Widget _buildSpecial(BuildContext context, WidgetRef ref, GameRecord game) {
    final input = game.inputs.firstWhere((p) => p.id == widget.player.id);
    final isBlown = input.blownByPlayerId != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(Icons.flight_takeoff, color: isBlown ? Colors.blueAccent : Colors.white10, size: 20), onPressed: () { if (input.score >= 0) return; if (isBlown) { ref.read(calcProvider.notifier).setBlownBy(widget.gameId, widget.player.id, null); } else { _showBlownByDialog(context, ref, game); } }),
        IconButton(icon: Icon(Icons.star, color: input.yakumanPt != 0 ? const Color(0xFF00FFC2) : Colors.white10, size: 20), onPressed: () => _showYakumanDialog(context, ref, game)),
      ],
    );
  }

  void _showBlownByDialog(BuildContext context, WidgetRef ref, GameRecord game) {
    final config = ref.read(configProvider);
    final players = config.isThreePlayer ? 3 : 4;
    showDialog(context: context, builder: (ctx) => SimpleDialog(backgroundColor: const Color(0xFF002922), title: const Text('放銃者を選択', style: TextStyle(color: Colors.white, fontSize: 14)), children: List.generate(players, (i) => i + 1).where((id) => id != widget.player.id).map((id) => SimpleDialogOption(child: Text(ref.read(calcProvider).playerNames[id - 1], style: const TextStyle(color: Color(0xFF00FFC2))), onPressed: () { ref.read(calcProvider.notifier).setBlownBy(game.id, widget.player.id, id); Navigator.pop(ctx); })).toList()));
  }

  void _showYakumanDialog(BuildContext context, WidgetRef ref, GameRecord game) {
    final config = ref.read(configProvider);
    final players = config.isThreePlayer ? 3 : 4;
    final input = game.inputs.firstWhere((p) => p.id == widget.player.id);
    if (input.yakumanPt != 0) { ref.read(calcProvider.notifier).clearYakuman(game.id); return; }
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF002922), title: const Text('役満', style: TextStyle(color: Colors.white, fontSize: 14)), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(title: const Text('ツモ', style: TextStyle(color: Colors.orangeAccent)), onTap: () { ref.read(calcProvider.notifier).setYakumanTsumo(game.id, widget.player.id); Navigator.pop(ctx); }), ...List.generate(players, (i) => i + 1).where((id) => id != widget.player.id).map((id) => ListTile(title: Text(ref.read(calcProvider).playerNames[id - 1], style: const TextStyle(color: Colors.white70)), onTap: () { ref.read(calcProvider.notifier).setYakumanRon(game.id, widget.player.id, id); Navigator.pop(ctx); }))])));
  }
}

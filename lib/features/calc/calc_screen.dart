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
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('麻雀スコア表', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FFC2)),
            onPressed: () => _confirmReset(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            IntrinsicHeight(
              child: _buildTopConfigHeader(context, ref),
            ),
            Expanded(
              child: _buildMainDataTable(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildBottomSummaryFooter(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF001F1A),
          title: Text('全データをリセットしますか？', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)),
          content: Text('入力済みのスコアはすべて削除され、プレイヤー名も初期化されます（レートなどの設定は維持されます）。', style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)),
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

  Widget _buildTopConfigHeader(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 4),
                blurRadius: 8,
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildConfigField(
                      label: 'Rate',
                      hintText: '例: 50',
                      initialValue: config.rate.toString(),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateRate(parsed);
                      },
                      isDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: _buildConfigField(
                      label: '場代',
                      hintText: '例: 13200',
                      initialValue: config.gameFee.toString(),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateGameFee(parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: _buildConfigField(
                      label: 'Chip',
                      initialValue: config.chipRate.toString(),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateChipRate(parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: _buildConfigField(
                      label: 'Uma',
                      initialValue: config.umaText,
                      onChanged: (val) {
                        ref.read(configProvider.notifier).updateUmaText(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: _buildConfigField(
                      label: 'Oka',
                      initialValue: config.oka.toString(),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateOka(parsed);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const Text('4人', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Switch(
                            value: config.isThreePlayer,
                            activeColor: const Color(0xFF00FFC2),
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.black45,
                            onChanged: (val) => ref.read(configProvider.notifier).updateIsThreePlayer(val),
                          ),
                          const Text('3人', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: _buildConfigField(
                      label: 'CHK点',
                      initialValue: config.targetTotalScore.toString(),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateTargetTotalScore(parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: _buildConfigField(
                      label: 'トビ賞',
                      initialValue: config.tobiPrize.toString(),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateTobiPrize(parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: _buildConfigField(
                      label: '役満賞',
                      initialValue: config.yakumanPrize.toString(),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) ref.read(configProvider.notifier).updateYakumanPrize(parsed);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigField({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
    bool isDecimal = false,
    String? hintText,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: GoogleFonts.robotoMono(color: Colors.white38, fontSize: 12),
        labelStyle: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00FFC2), width: 1)),
      ),
      onChanged: onChanged,
    );
  }

  /// Builds a Uma list from the config umaText, adapting for 3-player vs 4-player.
  List<int> _buildUmaList(String umaText, bool isThreePlayer) {
    final parts = umaText.split('-');
    if (parts.length == 2) {
      final a = int.tryParse(parts[0]) ?? 10;
      final b = int.tryParse(parts[1]) ?? 20;
      if (isThreePlayer) {
        // For Sanma: top gets (a+b), 2nd gets 0, 3rd gets -(a+b) typically
        // But we keep the user's intent: spread the top/bottom
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

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 400),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: const Color(0xFF00FFC2).withOpacity(0.5),
              dataTableTheme: DataTableThemeData(
                headingRowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.4)),
                dataRowColor: MaterialStateProperty.all(Colors.transparent),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00FFC2).withOpacity(0.5), width: 1),
                ),
              ),
            ),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 4,
              horizontalMargin: 2,
              border: TableBorder.all(
                color: const Color(0xFF00FFC2).withOpacity(0.3),
                width: 1,
              ),
              headingTextStyle: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold),
              dataTextStyle: GoogleFonts.robotoMono(color: Colors.white70),
              columns: [
                const DataColumn(label: SizedBox(width: 24, child: Center(child: Text('No', style: TextStyle(fontSize: 11))))),
                ...List.generate(expectedPlayers, (i) {
                  return DataColumn(
                    label: SizedBox(
                      width: 60,
                      child: Center(
                        child: PlayerNameField(index: i, initialName: playerNames[i]),
                      ),
                    ),
                  );
                }),
                const DataColumn(label: SizedBox(width: 20, child: Center(child: Text('Chk', style: TextStyle(fontSize: 11))))),
                const DataColumn(label: SizedBox(width: 20, child: Center(child: Text('Del', style: TextStyle(fontSize: 11))))),
              ],
              rows: [
                ...games.asMap().entries.map((entry) {
                  final index = entry.key;
                  final game = entry.value;

                  // Only sum the active players
                  final scoreSum = game.inputs
                      .where((p) => p.id <= expectedPlayers)
                      .fold(0, (sum, p) => sum + p.score);
                  final isValid = scoreSum == config.targetTotalScore;

                  // Precalculate Points if valid
                  List<PlayerResult>? calculatedPoints;
                  if (isValid) {
                    try {
                      final currentUma = _buildUmaList(config.umaText, config.isThreePlayer);
                      final currentRule = state.rule.copyWith(oka: config.oka, uma: currentUma);

                      // Only pass active players to calculator
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
                    color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return Theme.of(context).colorScheme.primary.withOpacity(0.08);
                      }
                      if (index % 2 == 0) return Colors.white.withOpacity(0.02);
                      return null;
                    }),
                    onSelectChanged: (_) => _showEditModal(context, ref, game),
                    cells: [
                      DataCell(SizedBox(width: 24, child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 11))))),
                      ...List.generate(expectedPlayers, (pIdx) {
                        final input = game.inputs.firstWhere((p) => p.id == pIdx + 1, orElse: () => const PlayerInput(id: 0, score: 0));
                        String displayValue = input.score.toCommaString();
                        Color textColor = Colors.white;

                        if (calculatedPoints != null) {
                          final ptResult = calculatedPoints.firstWhere((p) => p.id == pIdx + 1).finalPoint;
                          displayValue = ptResult > 0 ? '+${ptResult.toCommaString()}' : ptResult.toCommaString();
                          textColor = ptResult < 0 ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);
                        }

                        return DataCell(
                          SizedBox(
                            width: 60,
                            child: Center(
                              child: Text(
                                displayValue,
                                style: GoogleFonts.robotoMono(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: calculatedPoints != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        SizedBox(
                          width: 20,
                          child: Center(
                            child: Icon(isValid ? Icons.check_circle : Icons.error_outline,
                              color: isValid ? const Color(0xFF00FFC2) : Colors.redAccent, size: 18),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 20,
                          child: Align(
                            alignment: Alignment.center,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                              onPressed: () {
                                ref.read(calcProvider.notifier).deleteGame(game.id);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                // Global Chip Input Row
                DataRow(
                  color: MaterialStateProperty.all(Colors.black.withOpacity(0.3)),
                  cells: [
                    const DataCell(SizedBox(width: 32, child: Center(child: Text('チップ', style: TextStyle(color: Color(0xFF00FFC2), fontSize: 10))))),
                    ...List.generate(expectedPlayers, (pIdx) {
                      final chip = globalChips[pIdx];
                      return DataCell(
                        SizedBox(
                          width: 65,
                          child: Center(
                            child: TextFormField(
                              initialValue: chip == 0 ? '' : chip.toString(),
                              keyboardType: const TextInputType.numberWithOptions(signed: true),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.robotoMono(color: Colors.orangeAccent),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '0',
                                hintStyle: TextStyle(color: Colors.white24),
                                contentPadding: EdgeInsets.symmetric(vertical: 2),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                final c = int.tryParse(val) ?? 0;
                                ref.read(calcProvider.notifier).updateGlobalChip(pIdx + 1, c);
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                    DataCell(
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            globalChips.sublist(0, expectedPlayers).fold(0, (sum, c) => sum + c) == 0 ? 'OK' : 'ERR',
                            style: GoogleFonts.robotoMono(
                              color: globalChips.sublist(0, expectedPlayers).fold(0, (sum, c) => sum + c) == 0
                                  ? const Color(0xFF00FFC2)
                                  : const Color(0xFFFF5252),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                    ),
                    const DataCell(SizedBox(width: 32)),
                  ]
                ),
                // Add Row Button
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.add_circle, color: Color(0xFF00FFC2)),
                          onPressed: () {
                            ref.read(calcProvider.notifier).addGame();
                          },
                        ),
                      ),
                    ),
                    ...List.generate(expectedPlayers, (_) => const DataCell(SizedBox(width: 60))),
                    const DataCell(SizedBox(width: 20)),
                    const DataCell(SizedBox(width: 20)),
                  ]
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSummaryFooter(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final config = ref.watch(configProvider);
    final rule = state.rule;
    final expectedPlayers = config.isThreePlayer ? 3 : 4;

    List<List<PlayerResult>> allValidResults = [];
    int validGamesCount = 0;

    for (var game in state.games) {
      final scoreSum = game.inputs
          .where((p) => p.id <= expectedPlayers)
          .fold(0, (sum, p) => sum + p.score);
      if (scoreSum == config.targetTotalScore) {
        validGamesCount++;
        try {
          final currentUma = _buildUmaList(config.umaText, config.isThreePlayer);
          final currentRule = rule.copyWith(oka: config.oka, uma: currentUma);
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
          final res = MahjongCalculator.calculate(inputs: enrichedInputs, rule: currentRule, config: config);
          allValidResults.add(res);
        } catch (_) {}
      }
    }

    // Build per-player summaries for active players only
    final Map<int, Map<String, int>> playerSummaries = {
      for (int i = 1; i <= expectedPlayers; i++)
        i: {'pt': 0, 'chip': state.globalChips[i - 1]},
    };

    for (var gameRes in allValidResults) {
      for (var pRes in gameRes) {
        playerSummaries[pRes.id]!['pt'] = playerSummaries[pRes.id]!['pt']! + pRes.finalPoint;
      }
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(0, -4),
                blurRadius: 10,
              )
            ],
            border: const Border(top: BorderSide(color: Color(0xFF00FFC2), width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 1; i <= expectedPlayers; i++)
                Expanded(
                  child: _buildSummaryBlock(
                    state.playerNames[i - 1],
                    playerSummaries[i]!,
                    config,
                    validGamesCount,
                    expectedPlayers,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBlock(String title, Map<String, int> data, AppConfig config, int gamesCount, int numPlayers) {
    final pt = data['pt']!;
    final chip = data['chip']!;

    final rawBalance = (pt * config.rate) + (chip * config.chipRate);
    final rawFinal = rawBalance - (config.gameFee / numPlayers).round();

    int finalBalance = config.roundingTenYen ? (rawFinal / 10.0).ceil() * 10 : rawFinal.round();
    int balanceBeforeFee = config.roundingTenYen ? (rawBalance / 10.0).ceil() * 10 : rawBalance.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text('Pt:${pt.toCommaString()}|Chip:${chip.toCommaString()}', style: GoogleFonts.robotoMono(color: pt < 0 ? const Color(0xFFFF5252) : Colors.white70, fontSize: 10))),
        const SizedBox(height: 1),
        FittedBox(fit: BoxFit.scaleDown, child: Text('収支: ¥${balanceBeforeFee.toCommaString()}', textAlign: TextAlign.center, style: GoogleFonts.robotoMono(color: balanceBeforeFee < 0 ? const Color(0xFFFF5252) : Colors.white, fontSize: 10))),
        const SizedBox(height: 1),
        FittedBox(fit: BoxFit.scaleDown, child: Text('場代込: ¥${finalBalance.toCommaString()}', textAlign: TextAlign.center, style: GoogleFonts.robotoMono(
          color: finalBalance >= 0 ? Colors.greenAccent : const Color(0xFFFF5252),
          fontSize: 10,
          fontWeight: FontWeight.bold
        ))),
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
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Hanchan', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Only show active players
              ...game.inputs
                  .where((p) => p.id <= expectedPlayers)
                  .map((p) => PlayerInputCard(gameId: game.id, player: p)),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }
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
  void initState() {
    super.initState();
    final initial = widget.player.score;
    _scoreController = TextEditingController(text: initial == 0 ? '' : initial.toString());
  }

  @override
  void didUpdateWidget(PlayerInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.score != widget.player.score) {
      final currentScore = int.tryParse(_scoreController.text) ?? 0;
      if (widget.player.score != currentScore) {
        _scoreController.text = widget.player.score == 0 ? '' : widget.player.score.toString();
      }
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calcProvider);
    final game = state.games.firstWhere((g) => g.id == widget.gameId);
    final playerName = state.playerNames[widget.player.id - 1];

    final isOya = game.startingOyaIndex == widget.player.id - 1;
    final priority = ((widget.player.id - 1) - game.startingOyaIndex + 4) % 4;
    final windMarks = ['東', '南', '西', '北'];
    final windText = windMarks[priority];

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF002922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FFC2).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ref.read(calcProvider.notifier).setStartingOya(widget.gameId, widget.player.id - 1);
            },
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOya ? const Color(0xFF00FFC2) : Colors.transparent,
                border: Border.all(color: isOya ? const Color(0xFF00FFC2) : Colors.white38),
              ),
              child: Center(
                child: Text(
                  windText,
                  style: TextStyle(
                    color: isOya ? const Color(0xFF002922) : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: const Color(0xFF004D40),
            child: Text('${widget.player.id}', style: GoogleFonts.robotoMono(color: Colors.white)),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 50,
            child: Text(playerName, style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              style: GoogleFonts.robotoMono(color: Colors.greenAccent, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Score',
                hintText: '0',
                hintStyle: const TextStyle(color: Colors.white24),
                labelStyle: GoogleFonts.robotoMono(color: Colors.white54),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                final score = int.tryParse(val) ?? 0;
                ref.read(calcProvider.notifier).updateScore(widget.gameId, widget.player.id, score);
              },
            ),
          ),
          _buildSpecialButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildSpecialButtons(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final game = state.games.firstWhere((g) => g.id == widget.gameId);
    final input = game.inputs.firstWhere((p) => p.id == widget.player.id);

    final hasYakumanPt = input.yakumanPt != 0;
    final isBlown = input.blownByPlayerId != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 22,
              icon: Icon(Icons.flight_takeoff, color: isBlown ? const Color(0xFF29B6F6) : Colors.grey[700]),
              tooltip: '誰に飛ばされたか',
              onPressed: () {
                if (input.score >= 0) return;
                if (isBlown) {
                  ref.read(calcProvider.notifier).setBlownBy(widget.gameId, widget.player.id, null);
                } else {
                  _showBlownByDialog(context, ref, game);
                }
              },
            ),
            if (isBlown)
              Text('to ${state.playerNames[input.blownByPlayerId! - 1]}', style: const TextStyle(color: Color(0xFF29B6F6), fontSize: 9)),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 22,
          icon: Icon(Icons.star, color: hasYakumanPt ? const Color(0xFF00FFC2) : Colors.grey[700]),
          tooltip: '役満賞',
          onPressed: () => _showYakumanDialog(context, ref, game),
        ),
      ],
    );
  }

  void _showBlownByDialog(BuildContext context, WidgetRef ref, GameRecord game) {
    final config = ref.read(configProvider);
    final expectedPlayers = config.isThreePlayer ? 3 : 4;
    showDialog(context: context, builder: (ctx) {
       return SimpleDialog(
         backgroundColor: const Color(0xFF002922),
         title: Text('誰に飛ばされましたか？', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)),
         children: List.generate(expectedPlayers, (i) => i + 1)
             .where((id) => id != widget.player.id)
             .map((id) => SimpleDialogOption(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
               child: Text(ref.read(calcProvider).playerNames[id - 1], style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 16)),
               onPressed: () {
                 ref.read(calcProvider.notifier).setBlownBy(game.id, widget.player.id, id);
                 Navigator.pop(ctx);
               }
             )).toList(),
       );
    });
  }

  void _showYakumanDialog(BuildContext context, WidgetRef ref, GameRecord game) {
    final input = game.inputs.firstWhere((p) => p.id == widget.player.id);
    if (input.yakumanPt != 0) {
       ref.read(calcProvider.notifier).clearYakuman(game.id);
       return;
    }

    final config = ref.read(configProvider);
    final expectedPlayers = config.isThreePlayer ? 3 : 4;

    showDialog(context: context, builder: (ctx) {
       return AlertDialog(
         backgroundColor: const Color(0xFF002922),
         title: Text('役満のあがり方', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             ListTile(
               title: const Text('ツモ', style: TextStyle(color: Colors.orangeAccent)),
               onTap: () {
                 ref.read(calcProvider.notifier).setYakumanTsumo(game.id, widget.player.id);
                 Navigator.pop(ctx);
               }
             ),
             const Divider(color: Colors.white24),
             const Text('ロン (放銃者を選択)', style: TextStyle(color: Colors.white54, fontSize: 12)),
             ...List.generate(expectedPlayers, (i) => i + 1)
                 .where((id) => id != widget.player.id)
                 .map((id) => ListTile(
                   title: Text(ref.read(calcProvider).playerNames[id - 1], style: const TextStyle(color: Colors.white)),
                   onTap: () {
                     ref.read(calcProvider.notifier).setYakumanRon(game.id, widget.player.id, id);
                     Navigator.pop(ctx);
                   }
                 )).toList()
           ]
         ),
       );
    });
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
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void didUpdateWidget(PlayerNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName) {
      if (_controller.text != widget.initialName) {
        _controller.text = widget.initialName;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textAlign: TextAlign.center,
      style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
      onChanged: (val) {
        ref.read(calcProvider.notifier).updatePlayerName(widget.index + 1, val);
      },
    );
  }
}

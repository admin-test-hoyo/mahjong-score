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
      backgroundColor: const Color(0xFF004D40), // Deep green base background
      body: SafeArea(
        child: Column(
          children: [
            _buildTopConfigHeader(context, ref),
            Expanded(
              child: _buildMainDataTable(context, ref),
            ),
            _buildBottomSummaryFooter(context, ref),
          ],
        ),
      ),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: _buildConfigField(
                    label: 'Rate',
                    initialValue: config.rate.toString(),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) ref.read(configProvider.notifier).updateRate(parsed);
                    },
                    isDecimal: true,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: _buildConfigField(
                    label: '場代 (1日の1卓総額)',
                    hintText: '例: 13200',
                    initialValue: config.gameFee.toString(),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null) ref.read(configProvider.notifier).updateGameFee(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: _buildConfigField(
                    label: 'Chip Unit',
                    initialValue: config.chipRate.toString(),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null) ref.read(configProvider.notifier).updateChipRate(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: _buildConfigField(
                    label: 'Uma',
                    initialValue: config.umaText,
                    onChanged: (val) {
                      ref.read(configProvider.notifier).updateUmaText(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
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

  Widget _buildMainDataTable(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final games = state.games;
    final playerNames = state.playerNames;
    final globalChips = state.globalChips;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 650), // Enforce a safe minimum width for the table
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
              columnSpacing: 12,
              horizontalMargin: 8,
              border: TableBorder.all(
                color: const Color(0xFF00FFC2).withOpacity(0.3),
                width: 1,
              ),
              headingTextStyle: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold),
              dataTextStyle: GoogleFonts.robotoMono(color: Colors.white70),
              columns: [
                const DataColumn(label: SizedBox(width: 40, child: Center(child: Text('No')))),
                ...List.generate(4, (i) {
                  return DataColumn(
                    label: SizedBox(
                      width: 80,
                      child: Center(
                        child: TextFormField(
                          initialValue: playerNames[i],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 2), // Slightly reduced padding
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            ref.read(calcProvider.notifier).updatePlayerName(i + 1, val);
                          },
                        ),
                      ),
                    ),
                  );
                }),
                const DataColumn(label: SizedBox(width: 40, child: Center(child: Text('Check')))),
                const DataColumn(label: SizedBox(width: 40, child: Center(child: Text('Del')))), // Delete Column
              ],
            rows: [
              ...games.asMap().entries.map((entry) {
                final index = entry.key;
                final game = entry.value;

                final scoreSum = game.inputs.fold(0, (sum, p) => sum + p.score);
                final isValid = scoreSum == 100000; // Only check score now, chips are global
                
                // Precalculate Points if valid
                List<PlayerResult>? calculatedPoints;
                if (isValid) {
                  try {
                    // Inject config Uma/Oka to Rule here
                    final umaParts = ref.read(configProvider).umaText.split('-');
                    final List<int> currentUma = umaParts.length == 2 
                      ? [int.parse(umaParts[1]), int.parse(umaParts[0]), -int.parse(umaParts[0]), -int.parse(umaParts[1])] 
                      : [20, 10, -10, -20];
                    final currentRule = state.rule.copyWith(oka: ref.read(configProvider).oka, uma: currentUma);
                    
                    // Pass native tobiPt and yakumanPt straight into the calculator
                    final enrichedInputs = game.inputs.map((p) {
                      return PlayerInput(id: p.id, score: p.score, chip: p.chip, tobiPt: p.tobiPt, yakumanPt: p.yakumanPt, blownByPlayerId: p.blownByPlayerId);
                    }).toList();

                    calculatedPoints = MahjongCalculator.calculate(inputs: enrichedInputs, rule: currentRule, config: ref.read(configProvider), startingOyaIndex: game.startingOyaIndex);
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
                    DataCell(SizedBox(width: 40, child: Center(child: Text('${index + 1}')))),
                    ...List.generate(4, (pIdx) {
                      final input = game.inputs.firstWhere((p) => p.id == pIdx + 1, orElse: () => const PlayerInput(id: 0, score: 0));
                      String displayValue = input.score.toCommaString();
                      Color textColor = Colors.white;

                      if (calculatedPoints != null) {
                        final ptResult = calculatedPoints.firstWhere((p) => p.id == pIdx + 1).finalPoint;
                        displayValue = ptResult > 0 ? '+${ptResult.toCommaString()}' : ptResult.toCommaString();
                        textColor = ptResult < 0 ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);
                        
                        // Add Emojis for special prizes
                        if (input.tobiPt != 0) displayValue += " ✈️";
                        if (input.yakumanPt > 0) displayValue += " ⭐";
                      }

                      return DataCell(
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: Text(
                              displayValue,
                              style: GoogleFonts.robotoMono(
                                color: textColor,
                                fontWeight: calculatedPoints != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            isValid ? 'OK' : 'ERR',
                            style: GoogleFonts.robotoMono(
                              color: isValid ? const Color(0xFF00FFC2) : const Color(0xFFFF5252),
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: isValid ? const Color(0xFF00FFC2) : const Color(0xFFFF5252),
                                  blurRadius: 4, // Reduced blur to prevent clipping overflow
                                )
                              ]
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: Align(
                          alignment: Alignment.center,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
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
                  const DataCell(SizedBox(width: 40, child: Center(child: Text('Chip', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold))))),
                  ...List.generate(4, (pIdx) {
                    final chip = globalChips[pIdx];
                    return DataCell(
                      SizedBox(
                        width: 80,
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
                      width: 40,
                      child: Center(
                        child: Text(
                          globalChips.fold(0, (sum, c) => sum + c) == 0 ? 'OK' : 'ERR',
                          style: GoogleFonts.robotoMono(
                            color: globalChips.fold(0, (sum, c) => sum + c) == 0 ? const Color(0xFF00FFC2) : const Color(0xFFFF5252),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                  ),
                  const DataCell(SizedBox(width: 40)), // Align with trash can
                ]
              ),
              // Add Row Button
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 40,
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
                  const DataCell(SizedBox(width: 80)),
                  const DataCell(SizedBox(width: 80)),
                  const DataCell(SizedBox(width: 80)),
                  const DataCell(SizedBox(width: 80)),
                  const DataCell(SizedBox(width: 40)),
                  const DataCell(SizedBox(width: 40)),
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

    // Calculate sum of everything
    // First, convert all valid games to PlayerResults
    List<List<PlayerResult>> allValidResults = [];
    int validGamesCount = 0;

    for (var game in state.games) {
      final scoreSum = game.inputs.fold(0, (sum, p) => sum + p.score);
      // We no longer check chip sum per game since chips are global
      if (scoreSum == 100000) {
        validGamesCount++;
        try {
          final umaParts = config.umaText.split('-');
          final List<int> currentUma = umaParts.length == 2 
            ? [int.parse(umaParts[1]), int.parse(umaParts[0]), -int.parse(umaParts[0]), -int.parse(umaParts[1])] 
            : [20, 10, -10, -20];
          final currentRule = rule.copyWith(oka: config.oka, uma: currentUma);

          final res = MahjongCalculator.calculate(inputs: game.inputs, rule: currentRule, config: config);
          allValidResults.add(res);
        } catch (_) {}
      }
    }

    // Accumulators per player
    // Map of Player ID -> Map of metrics
    final Map<int, Map<String, int>> playerSummaries = {
      1: {'pt': 0, 'chip': state.globalChips[0]},
      2: {'pt': 0, 'chip': state.globalChips[1]},
      3: {'pt': 0, 'chip': state.globalChips[2]},
      4: {'pt': 0, 'chip': state.globalChips[3]},
    };

    // Gather pts
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryBlock(state.playerNames[0], playerSummaries[1]!, config, validGamesCount),
                const SizedBox(width: 16),
                _buildSummaryBlock(state.playerNames[1], playerSummaries[2]!, config, validGamesCount),
                const SizedBox(width: 16),
                _buildSummaryBlock(state.playerNames[2], playerSummaries[3]!, config, validGamesCount),
                const SizedBox(width: 16),
                _buildSummaryBlock(state.playerNames[3], playerSummaries[4]!, config, validGamesCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBlock(String title, Map<String, int> data, AppConfig config, int gamesCount) {
    final pt = data['pt']!;
    final chip = data['chip']!;
    
    // Calculate balance based on formula: (pt * rate) + (chip * chipRate)
    final rawBalance = (pt * config.rate) + (chip * config.chipRate);
    final rawFinal = rawBalance - (config.gameFee / 4).round(); // Flat daily rate per player 

    // Apply Ten Yen rounding logic if enabled
    int finalBalance = config.roundingTenYen ? (rawFinal / 10.0).ceil() * 10 : rawFinal.round();
    int balanceBeforeFee = config.roundingTenYen ? (rawBalance / 10.0).ceil() * 10 : rawBalance.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Pt: ${pt.toCommaString()}  |  Chip: ${chip.toCommaString()}', style: GoogleFonts.robotoMono(color: pt < 0 ? const Color(0xFFFF5252) : Colors.white70, fontSize: 12)),
        Text('収支: ¥${balanceBeforeFee.toCommaString()}', style: GoogleFonts.robotoMono(color: balanceBeforeFee < 0 ? const Color(0xFFFF5252) : Colors.white, fontSize: 13)),
        Text('場代込: ¥${finalBalance.toCommaString()}', style: GoogleFonts.robotoMono(
          color: finalBalance >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), 
          fontSize: 14, 
          fontWeight: FontWeight.bold
        )),
      ],
    );
  }

  void _showEditModal(BuildContext context, WidgetRef ref, GameRecord game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A), // Match theme
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Keyboard offset
            left: 16, right: 16, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Hanchan', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...game.inputs.map((p) => PlayerInputCard(gameId: game.id, player: p)),
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
    _scoreController = TextEditingController(text: widget.player.score.toString());
  }
  
  @override
  void didUpdateWidget(PlayerInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.score != widget.player.score && int.tryParse(_scoreController.text) != widget.player.score) {
      _scoreController.text = widget.player.score.toString();
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
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(playerName, style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              style: GoogleFonts.robotoMono(color: Colors.greenAccent, fontSize: 18),
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
    
    final hasTobiPt = input.tobiPt != 0;
    final hasYakumanPt = input.yakumanPt != 0;
    final isBlown = input.blownByPlayerId != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.flight_takeoff, color: isBlown ? const Color(0xFF29B6F6) : Colors.grey[700]), // Neon Blue for blown
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
              Text('to ${state.playerNames[input.blownByPlayerId! - 1]}', style: const TextStyle(color: Color(0xFF29B6F6), fontSize: 10)),
          ],
        ),
        IconButton(
          icon: Icon(Icons.star, color: hasYakumanPt ? const Color(0xFF00FFC2) : Colors.grey[700]),
          tooltip: '役満賞',
          onPressed: () => _showYakumanDialog(context, ref, game),
        ),
      ],
    );
  }

  void _showBlownByDialog(BuildContext context, WidgetRef ref, GameRecord game) {
    showDialog(context: context, builder: (ctx) {
       return SimpleDialog(
         backgroundColor: const Color(0xFF002922),
         title: Text('誰に飛ばされましたか？', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16)),
         children: [1,2,3,4].where((id) => id != widget.player.id).map((id) => SimpleDialogOption(
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
       // Toggle off if they already have Yakuman Pt (winner or loser)
       ref.read(calcProvider.notifier).clearYakuman(game.id);
       return;
    }

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
             ...[1,2,3,4].where((id) => id != widget.player.id).map((id) => ListTile(
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

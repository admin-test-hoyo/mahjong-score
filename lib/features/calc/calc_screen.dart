import 'dart:convert';
import 'dart:async';
import 'calc_providers.dart';
import '../history/history_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universal_html/html.dart' as html;
import '../../core/database/database_providers.dart';
import '../../core/calculator.dart';
import '../../core/models/app_config.dart';
import '../../core/models/db_models.dart';
import '../../core/database/database_service.dart';
import 'calc_state.dart';
import '../history/history_screen.dart';
import '../stats/stats_providers.dart';

class CalcScreen extends ConsumerWidget {
  const CalcScreen({super.key});

  // --- SPA対応のための静的メソッド ---

  static void exportData(BuildContext context, WidgetRef ref) {
    _exportData(context, ref);
  }

  static void importData(BuildContext context, WidgetRef ref) {
    final uploadInput = html.FileUploadInputElement()..accept = '.json';
    uploadInput.click();
    _importData(context, ref, uploadInput);
  }

  static void showSettings(BuildContext context, WidgetRef ref) {
    _showSettingsModal(context, ref);
  }

  static void showSave(BuildContext context, WidgetRef ref) {
    _showSaveLogic(context, ref);
  }

  static void showReset(BuildContext context, WidgetRef ref) {
    _confirmReset(context, ref);
  }

  static void showMemberPicker(BuildContext context, WidgetRef ref) {
    _showMemberPicker(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Ver 3.3.4: グループ自動判別の監視ロジックを物理削除
    
    return SafeArea(
      child: Column(
        children: [
          _buildQuickRuleBar(context, ref),
          _buildEditingModeBanner(context, ref),
          Expanded(child: _buildMainDataTable(context, ref)),
          _buildBottomSummaryFooter(context, ref),
        ],
      ),
    );
  }

  // --- 内部ロジック (static) ---

  static void _showMemberPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MemberPickerModal(ref: ref),
    );
  }

  static void _showSettingsModal(BuildContext context, WidgetRef ref) {


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF001F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const SettingsModal(),
    );
  }

  static void _showSaveLogic(BuildContext context, WidgetRef ref) async {
    final state = ref.read(calcProvider);
    if (!state.isGameFinished) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('合計点数が一致していません')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('対局記録の保存', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('現在の対局を保存しますか？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存', style: TextStyle(color: Color(0xFF00FFC2)))),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ref.read(calcProvider.notifier).saveCurrentSession(DateTime.now());
      if (context.mounted) {
        if (res == SaveResult.registered || res == SaveResult.updated) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res == SaveResult.registered ? '対局を保存しました' : '対局を更新しました')));
          // 履歴をリフレッシュ
          ref.read(historyProvider.notifier).refresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
        }
      }
    }
  }

  static void _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B0000),
        title: const Text('リセットの確認', style: TextStyle(color: Color(0xFFFF5252), fontSize: 16)),
        content: const Text('現在の入力をすべてリセットしますか？\n(保存済みの履歴は削除されません)', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('リセット', style: TextStyle(color: Color(0xFFFF5252)))),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(calcProvider.notifier).resetGame();
    }
  }

  static Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final db = DatabaseService();
    final data = await db.exportAllData();
    final jsonStr = jsonEncode(data);
    final date = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final filename = 'mahjong_backup_$date.json';
    
    final bytes = utf8.encode(jsonStr);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('バックアップファイルをダウンロードしました')));
    }
  }

  static Future<void> _importData(BuildContext context, WidgetRef ref, html.FileUploadInputElement uploadInput) async {
    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;
      
      try {
        final completer = Completer<String>();
        final reader = html.FileReader();
        reader.onLoadEnd.listen((_) => completer.complete(reader.result as String));
        reader.onError.listen((e) => completer.completeError('読み取り失敗'));
        reader.readAsText(files[0]!);
        final content = await completer.future;
        
        final jsonData = jsonDecode(content);
        if (jsonData is! Map<String, dynamic> || !jsonData.containsKey('sessions') || !jsonData.containsKey('games')) {
          html.window.alert('無効なファイル形式です。正規のバックアップJSONを選択してください。');
          return;
        }

        final confirmed = html.window.confirm('バックアップデータを復旧しますか？\n現時点の全データが上書きされ、アプリが再読み込みされます。');
        if (!confirmed) return;

        final db = DatabaseService();
        await db.importAllData(jsonData);

        // プロバイダー全体を強制的に無効化してリフレッシュ
        ref.invalidate(databaseVersionProvider);
        // import 'package:mahjong_score/features/history/history_providers.dart' etc might be needed if they are not visible
        // However, in a static method or listener, we use 'ref' passed as argument.
        
        // 主要なProviderを直ちに破棄（reloadまでの数秒のためだが、同期を確実にする）
        // stats系は databaseVersionProvider を watch しているので invalidate 1つで基本OKだが
        // 全Providerの状態をリセット対象にする
        
        html.window.location.reload();
        
      } catch (err) {
        html.window.alert('エラーが発生しました: $err');
      }
    });
  }

  // --- UI Parts (instance helpers) ---

  Widget _buildQuickRuleBar(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final state = ref.watch(calcProvider);
    final displayRate = state.currentId != null ? state.rule.rate.toDouble() : config.rate;
    final displayChipRate = state.currentId != null ? state.rule.chipRate : config.chipRate;
    final displayFee = state.currentId != null ? state.rule.totalFee : config.gameFee;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), border: const Border(bottom: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          _quickField(label: 'レート', value: displayRate.toString(), onChanged: (v) => ref.read(calcProvider.notifier).updateRuleRate(double.tryParse(v) ?? 0), width: 60),
          const SizedBox(width: 12),
          _quickField(label: 'チップ', value: displayChipRate.toString(), onChanged: (v) => ref.read(calcProvider.notifier).updateRuleChipRate(int.tryParse(v) ?? 0), width: 60),
          const SizedBox(width: 12),
          _quickField(label: '場代', value: displayFee.toString(), onChanged: (v) => ref.read(calcProvider.notifier).updateRuleGameFee(int.tryParse(v) ?? 0), width: 80),
          const Spacer(),
          const Text('Ver 3.3.4', style: TextStyle(color: Colors.white12, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildEditingModeBanner(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    if (state.currentId == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9100).withValues(alpha: 0.15), // Cinematic Deep Orange
        border: const Border(bottom: BorderSide(color: Colors.orangeAccent, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                '履歴編集モード中: ${state.sessionDate ?? "不明な日付"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _confirmReset(context, ref),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.close, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '編集を終了',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickField({required String label, required String value, required Function(String) onChanged, required double width}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        SizedBox(width: width, height: 24, child: TextField(controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)), keyboardType: TextInputType.number, style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none), onChanged: onChanged)),
      ],
    );
  }

  Widget _buildMainDataTable(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final config = ref.watch(configProvider);
    return LayoutBuilder(builder: (context, constraints) {
      const double ctrlWidth = 35;
      final double available = constraints.maxWidth - (ctrlWidth * 3) - 12;
      final double pWidth = available / 4;
      return SingleChildScrollView(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.white10),
          child: DataTable(
            columnSpacing: 0, horizontalMargin: 4, showCheckboxColumn: false,
            headingTextStyle: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            columns: [
              DataColumn(label: SizedBox(width: ctrlWidth, child: const Center(child: Text('No')))),
              ...List.generate(4, (i) => DataColumn(label: SizedBox(width: pWidth, child: Center(child: PlayerNameField(index: i, initialName: state.playerNames[i]))))),
              DataColumn(label: SizedBox(width: ctrlWidth, child: const Center(child: Text('Chk')))),
              DataColumn(label: SizedBox(width: ctrlWidth, child: const Center(child: Text('Del')))),
            ],
            rows: [
              ...state.games.asMap().entries.map((e) {
                final idx = e.key; final game = e.value;
                final sum = game.inputs.fold(0, (s, p) => s + p.score);
                final isValid = sum == config.targetTotalScore;
                List<PlayerResult>? results;
                if (isValid) {
                  try { results = MahjongCalculator.calculate(inputs: game.inputs, rule: state.rule.copyWith(oka: config.oka, uma: _buildUmaList(config.umaText)), config: config, startingOyaIndex: game.startingOyaIndex); } catch (_) {}
                }
                return DataRow(onSelectChanged: (_) => _showEditModal(context, ref, game), cells: [
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: Colors.white24))))),
                  ...List.generate(4, (pIdx) {
                    final p = game.inputs.firstWhere((p) => p.id == pIdx + 1, orElse: () => const PlayerInput(id: 0, score: 0));
                    String val = p.score.toCommaString(); Color col = Colors.white70;
                    if (results != null) {
                      final r = results.firstWhere((r) => r.id == pIdx + 1).finalPoint;
                      val = r > 0 ? '+${r.toCommaString()}' : r.toCommaString();
                      col = r < 0 ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);
                    }
                    return DataCell(SizedBox(width: pWidth, child: Center(child: Text(val, style: GoogleFonts.robotoMono(color: col, fontWeight: results != null ? FontWeight.bold : FontWeight.normal)))));
                  }),
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? const Color(0xFF00FFC2).withValues(alpha: 0.3) : Colors.redAccent, size: 16)))),
                  DataCell(SizedBox(width: ctrlWidth, child: Center(child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 16), onPressed: () => ref.read(calcProvider.notifier).deleteGame(game.id))))),
                ]);
              }),
              DataRow(color: WidgetStateProperty.all(const Color(0xFF00FFC2).withValues(alpha: 0.1)), cells: [
                const DataCell(Center(child: Icon(Icons.stars, color: Colors.orangeAccent, size: 14))),
                ...List.generate(4, (i) => DataCell(SizedBox(
                  width: pWidth, 
                  child: Center(
                    child: TextFormField(
                      initialValue: state.globalChips[i] == 0 ? '' : state.globalChips[i].toString(), 
                      keyboardType: TextInputType.number, 
                      textAlign: TextAlign.center, 
                      style: GoogleFonts.robotoMono(color: Colors.orangeAccent, fontSize: 13), 
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0', hintStyle: TextStyle(color: Colors.white12)), 
                      onChanged: (v) => ref.read(calcProvider.notifier).updateGlobalChip(i + 1, int.tryParse(v) ?? 0)
                    )
                  )
                ))),
                DataCell(Center(child: Text(state.globalChips.fold(0, (s, c) => s + c) == 0 ? '' : 'ERR', style: const TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)))),
                const DataCell(SizedBox()),
              ]),
              DataRow(cells: [DataCell(Center(child: IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00FFC2), size: 20), onPressed: () => ref.read(calcProvider.notifier).addGame()))), ...List.generate(4, (_) => const DataCell(SizedBox())), const DataCell(SizedBox()), const DataCell(SizedBox())]),
            ],
          ),
        ),
      );
    });
  }

  void _showEditModal(BuildContext context, WidgetRef ref, GameRecord game) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: const Color(0xFF001F1A), 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (context) => Consumer(builder: (context, ref, child) {
        final updatedGame = ref.watch(calcProvider).games.firstWhere((g) => g.id == game.id);
        const double cardHeight = 68.0;
        const double spacing = 8.0;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24), 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  const SizedBox(width: 48), 
                  Text('スコア編集', style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), 
                  IconButton(
                    icon: const Icon(Icons.cleaning_services, color: Colors.white38, size: 20), 
                    onPressed: () => ref.read(calcProvider.notifier).resetGameRecord(game.id)
                  )
                ]
              ),
              const Divider(color: Colors.white10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: updatedGame.inputs.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: spacing),
                    child: PlayerInputCard(
                      key: ValueKey('player_card_${p.id}'),
                      gameId: game.id, 
                      player: p, 
                      showYakuman: (id) => _showYakumanDialog(context, ref, updatedGame, id), 
                      showTobi: (id) => _showTobiDialog(context, ref, updatedGame, id),
                      cardHeight: cardHeight,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16)
            ]
          )
        );
      })
    );
  }

  void _showYakumanDialog(BuildContext context, WidgetRef ref, GameRecord game, int winnerId) {
    final names = ref.read(calcProvider).playerNames;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF001F1A),
      title: Text('${names[winnerId-1]} の役満設定', style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton(child: const Text('ツモ和了'), onPressed: () { ref.read(calcProvider.notifier).setYakumanTsumo(game.id, winnerId); Navigator.pop(ctx); }),
        const SizedBox(height: 16),
        ...List.generate(4, (i) => i + 1).where((id) => id != winnerId).map((loserId) => ListTile(title: Text('${names[loserId - 1]} が放銃'), onTap: () { ref.read(calcProvider.notifier).setYakumanRon(game.id, winnerId, loserId); Navigator.pop(ctx); })),
      ]),
    ));
  }

  void _showTobiDialog(BuildContext context, WidgetRef ref, GameRecord game, int blownId) {
    final names = ref.read(calcProvider).playerNames;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF001F1A),
      title: Text('${names[blownId-1]} を飛ばした人', style: const TextStyle(color: Colors.white, fontSize: 15)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(4, (i) => i + 1).where((id) => id != blownId).map((id) => ListTile(title: Text(names[id - 1]), onTap: () { ref.read(calcProvider.notifier).setBlownBy(game.id, blownId, id); Navigator.pop(ctx); })),
      ]),
    ));
  }

  Widget _buildBottomSummaryFooter(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calcProvider);
    final config = ref.watch(configProvider);
    final summaries = { for (int i = 1; i <= 4; i++) i: {'pt': 0, 'chip': 0} };
    int completed = 0;
    for (var g in state.games) {
      if (g.inputs.fold(0, (s, ip) => s + ip.score) == config.targetTotalScore) {
        completed++;
        try {
          final res = MahjongCalculator.calculate(inputs: g.inputs, rule: state.rule.copyWith(oka: config.oka, uma: _buildUmaList(config.umaText)), config: config, startingOyaIndex: g.startingOyaIndex);
          for (var r in res) {
            summaries[r.id]!['pt'] = (summaries[r.id]!['pt'] ?? 0) + r.finalPoint;
            summaries[r.id]!['chip'] = (summaries[r.id]!['chip'] ?? 0) + g.inputs.firstWhere((inp) => inp.id == r.id).chip;
          }
        } catch (_) {}
      }
    }
    for (int i=0; i<4; i++) summaries[i+1]!['chip'] = (summaries[i+1]!['chip'] ?? 0) + state.globalChips[i];
    return Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.black26, border: const Border(top: BorderSide(color: Color(0xFF00FFC2), width: 1))), child: Row(children: [
        for (int i = 1; i <= 4; i++) Expanded(child: _buildSumBlock(state.playerNames[i - 1], summaries[i]!, config, 4, completed, state.snapshottedMoneys != null && state.snapshottedMoneys!.length >= i ? state.snapshottedMoneys![i-1] : null))
    ]));
  }

  Widget _buildSumBlock(String name, Map<String, int> data, AppConfig conf, int players, int count, [int? snap]) {
    final pt = data['pt']!; final ch = data['chip']!;
    final income = (pt * conf.rate) + (ch * conf.chipRate);
    final balance = snap ?? (income - (conf.gameFee / players)).round();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(name, style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 13), overflow: TextOverflow.ellipsis),
      Text('Pt:${pt.toCommaString()}|Ch:${ch.toCommaString()}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      Text('¥${income.toInt().toCommaString()}', style: TextStyle(color: income < 0 ? Colors.redAccent : Colors.white60, fontSize: 10)),
      Text('¥${balance.toInt().toCommaString()}', style: TextStyle(color: balance < 0 ? Colors.redAccent : const Color(0xFF00FFC2), fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
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
}

class _MemberPickerModal extends StatefulWidget {
  final WidgetRef ref;
  const _MemberPickerModal({required this.ref});

  @override
  State<_MemberPickerModal> createState() => _MemberPickerModalState();
}

class _MemberPickerModalState extends State<_MemberPickerModal> {
  int? _selectedGroupId;
  final List<String> _selectedMembers = [];

  @override
  Widget build(BuildContext context) {
    final groupsAsync = widget.ref.watch(groupListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF001F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _selectedGroupId == null
                ? _buildGroupList(groupsAsync)
                : _buildMemberList(_selectedGroupId!),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(
            _selectedGroupId == null ? 'グループを選択' : 'メンバーを選択',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_selectedGroupId != null) ...[
            const SizedBox(height: 8),
            Text('選択済み：${_selectedMembers.length} / 4人', 
              style: TextStyle(
                color: _selectedMembers.length > 4 ? Colors.redAccent : const Color(0xFF00FFC2),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupList(AsyncValue<List<Map<String, dynamic>>> groupsAsync) {
    return groupsAsync.when(
      data: (groups) => ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          return ListTile(
            leading: const Icon(Icons.folder_outlined, color: Color(0xFF00FFC2)),
            title: Text(g['name'], style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
            onTap: () => setState(() => _selectedGroupId = g['id']),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildMemberList(int groupId) {
    return FutureBuilder<List<String>>(
      future: DatabaseService().getGroupMembers(groupId).timeout(const Duration(seconds: 3)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)));
        if (snapshot.hasError) return const Center(child: Text('データ取得に失敗しました', style: TextStyle(color: Colors.redAccent, fontSize: 12)));
        final members = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('グループ選択に戻る'),
                onPressed: () => setState(() => _selectedGroupId = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((name) {
                  final isSelected = _selectedMembers.contains(name);
                  return FilterChip(
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          if (_selectedMembers.length < 4) _selectedMembers.add(name);
                        } else {
                          _selectedMembers.remove(name);
                        }
                      });
                    },
                    backgroundColor: Colors.white10,
                    selectedColor: const Color(0xFF00FFC2).withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: isSelected ? const Color(0xFF00FFC2) : Colors.white70),
                    checkmarkColor: const Color(0xFF00FFC2),
                    shape: StadiumBorder(side: BorderSide(color: isSelected ? const Color(0xFF00FFC2) : Colors.white10)),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final canConfirm = _selectedMembers.isNotEmpty && _selectedMembers.length <= 4;
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).padding.bottom + 20, top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFC2),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white10,
            disabledForegroundColor: Colors.white24,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: canConfirm ? () {
            for (int i = 0; i < _selectedMembers.length; i++) {
              widget.ref.read(calcProvider.notifier).setPlayerName(i, _selectedMembers[i]);
            }
            Navigator.pop(context);
          } : null,
          child: Text(
            _selectedMembers.isEmpty ? 'メンバーを選択してください' : '確定して反映 (${_selectedMembers.length}名)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('アプリ設定', style: TextStyle(color: Color(0xFF00FFC2), fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => Navigator.pop(context))]),
        const SizedBox(height: 16),
        Row(children: [
            Expanded(child: _field(ref, 'Uma (例: 10-30)', config.umaText, (v) => ref.read(configProvider.notifier).updateUmaText(v))),
            const SizedBox(width: 8),
            Expanded(child: _field(ref, '配給原点', config.startingPoints.toString(), (v) => ref.read(configProvider.notifier).updateStartingPoints(int.tryParse(v) ?? 25000))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
            Expanded(child: _field(ref, 'Oka', config.oka.toString(), (v) => ref.read(configProvider.notifier).updateOka(int.tryParse(v) ?? 0))),
            const SizedBox(width: 8),
            Expanded(child: _field(ref, 'トビ賞', config.tobiPrize.toString(), (v) => ref.read(configProvider.notifier).updateTobiPrize(int.tryParse(v) ?? 10), suffixText: 'Pt')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
            Expanded(child: _field(ref, '役満賞(ツモ)', config.yakumanTsumoPrize.toString(), (v) => ref.read(configProvider.notifier).updateYakumanTsumoPrize(int.tryParse(v) ?? 5), suffixText: 'Pt')),
            const SizedBox(width: 8),
            Expanded(child: _field(ref, '役満賞(ロン)', config.yakumanRonPrize.toString(), (v) => ref.read(configProvider.notifier).updateYakumanRonPrize(int.tryParse(v) ?? 10), suffixText: 'Pt')),
        ]),
        const SizedBox(height: 32),
    ]));
  }
  Widget _field(WidgetRef ref, String l, String i, Function(String) o, {String? suffixText}) => TextFormField(initialValue: i, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white38, fontSize: 11), filled: true, fillColor: Colors.white.withValues(alpha: 0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), suffixText: suffixText), onChanged: o);
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
  final double cardHeight;
  const PlayerInputCard({super.key, required this.gameId, required this.player, required this.showYakuman, required this.showTobi, required this.cardHeight});
  @override ConsumerState<PlayerInputCard> createState() => _PlayerInputCardState();
}
class _PlayerInputCardState extends ConsumerState<PlayerInputCard> {
  late TextEditingController _s;
  late FocusNode _f;

  @override void initState() { 
    super.initState(); 
    _s = TextEditingController(text: widget.player.score == 0 ? '' : widget.player.score.toString()); 
    _f = FocusNode();
    _f.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_f.hasFocus) {
      // フォーカスが外れたタイミングで自動計算を実行
      ref.read(calcProvider.notifier).applyAutoCalculation(widget.gameId);
    }
  }

  @override void didUpdateWidget(PlayerInputCard old) { 
    super.didUpdateWidget(old); 
    if (old.player.score != widget.player.score) { 
      if (widget.player.score != (int.tryParse(_s.text) ?? 0)) {
        _s.text = widget.player.score == 0 ? '' : widget.player.score.toString(); 
      }
    } 
  }
  @override void dispose() { _s.dispose(); _f.removeListener(_onFocusChange); _f.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final state = ref.watch(calcProvider); final game = state.games.firstWhere((g) => g.id == widget.gameId);
    final oya = game.startingOyaIndex == widget.player.id - 1; final wind = ['東', '南', '西', '北'][((widget.player.id - 1) - game.startingOyaIndex + 4) % 4];
    final tPt = widget.player.tobiPt; final yPt = widget.player.yakumanPt;

    return Container(
      height: widget.cardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
      decoration: BoxDecoration(
        color: const Color(0xFF002922), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white10),
      ), 
      child: Row(children: [
        GestureDetector(onTap: () => ref.read(calcProvider.notifier).setStartingOya(widget.gameId, widget.player.id - 1), child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: oya ? const Color(0xFF00FFC2) : Colors.transparent, border: Border.all(color: oya ? const Color(0xFF00FFC2) : Colors.white24)), child: Center(child: Text(wind, style: TextStyle(color: oya ? const Color(0xFF004D40) : Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: Text(state.playerNames[widget.player.id - 1], style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: TextField(
          controller: _s, 
          focusNode: _f,
          textAlign: TextAlign.center, 
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onTapOutside: (_) => _f.unfocus(),
          maxLength: 6, 
          style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 16, fontWeight: FontWeight.bold), 
          decoration: const InputDecoration(isDense: true, counterText: '', hintText: '0', hintStyle: TextStyle(color: Colors.white12), filled: true, fillColor: Colors.black12, border: InputBorder.none), 
          onChanged: (v) => ref.read(calcProvider.notifier).updateScore(widget.gameId, widget.player.id, int.tryParse(v) ?? 0),
          onEditingComplete: () => _f.unfocus(),
        )),
        const SizedBox(width: 12),
        IconButton(icon: Icon(tPt != 0 ? Icons.favorite : Icons.favorite_border, color: tPt > 0 ? Colors.red : (tPt < 0 ? Colors.blue : Colors.white24)), onPressed: () => widget.showTobi(widget.player.id)),
        IconButton(icon: Icon(yPt != 0 ? Icons.emoji_events : Icons.emoji_events_outlined, color: yPt > 0 ? Colors.orange : (yPt < 0 ? Colors.blueGrey : Colors.white24)), onPressed: () => widget.showYakuman(widget.player.id)),
      ])
    );
  }
}

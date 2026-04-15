import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/db_models.dart';
import '../../core/database/database_providers.dart';
import 'history_providers.dart';
import '../main/main_providers.dart';
import '../stats/stats_providers.dart';
import '../calc/calc_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  static Future<void> exportCsv(BuildContext context, WidgetRef ref) async {
    final sessionsAsync = ref.read(historyProvider);
    final historySessions = sessionsAsync.asData?.value;
    if (historySessions == null || historySessions.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エクスポートするデータがありません')));
       return;
    }

    final selectedDateRange = ref.read(historyFilterProvider);
    final selectedGroup = ref.read(historyGroupFilterProvider);
    
    var filteredSessions = historySessions;
    if (selectedGroup != null) {
      filteredSessions = filteredSessions.where((s) {
        final session = s['session'] as Session;
        return session.groupId == selectedGroup || (session.groupId == null && selectedGroup == systemGroupIdFreeMatch);
      }).toList();
    }
    if (selectedDateRange != null) {
      filteredSessions = filteredSessions.where((s) {
        final dt = (s['session'] as Session).date;
        final date = DateFormat('yyyy/MM/dd').parse(dt);
        return !date.isBefore(selectedDateRange.start) && date.isBefore(selectedDateRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    if (filteredSessions.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エクスポートするデータがありません')));
       return;
    }

    // CSV構築 (Ver 2.2.3 強制上書きロジック)
    String csv = "対局ID,日付,グループ名,順位1,プレイヤー1,Pt1,チップ1,収支1,順位2,プレイヤー2,Pt2,チップ2,収支2,順位3,プレイヤー3,Pt3,チップ3,収支3,順位4,プレイヤー4,Pt4,チップ4,収支4\n";
    
    for (var data in filteredSessions) {
      final session = data['session'] as Session;
      final groupName = (data['groupName'] as String? ?? '').replaceAll(',', '，');
      final totalPts = data['totalPt'] as List<int>;
      final totalChips = data['totalChips'] as List<int>;
      final totalMoney = data['totalMoney'] as List<int>;
      
      String row = "${session.id},${session.date},$groupName";
      for (int i = 0; i < 4; i++) {
        if (i < session.playerNames.length) {
          final name = session.playerNames[i].replaceAll(',', '，');
          final pt = totalPts[i];
          final chip = i < totalChips.length ? totalChips[i] : 0;
          final money = totalMoney[i];
          // 順位(i+1), 名前, Pt, チップ, 収支
          row += ",${i + 1},$name,$pt,$chip,$money";
        } else {
          // プレイヤー不足時のパディング
          row += ",,,,,";
        }
      }
      csv += "$row\n";
    }

    final csvWithBom = '\uFEFF$csv';
    final blob = html.Blob([csvWithBom], 'text/csv; charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final dateStr = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final filename = 'mahjong_history_$dateStr.csv';

    html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);

    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSVファイルをエクスポートしました')));
    }
  }

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(historyProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final selectedDateRange = ref.watch(historyFilterProvider);
    final selectedGroup = ref.watch(historyGroupFilterProvider);

    return Column(
      children: [
        _buildHeader(context),
        _buildGroupFilter(ref, selectedGroup),
        if (selectedDateRange != null) _buildFilterBar(ref, selectedDateRange),
        Expanded(
          child: history.when(
            data: (sessions) => _buildList(sessions, selectedDateRange, selectedGroup),
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
            error: (e, s) => const Center(child: Text('読み込みエラー', style: TextStyle(color: Colors.white24))),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupFilter(WidgetRef ref, int? selectedGroup) {
    final groupsAsync = ref.watch(groupListProvider);
    return Container(
      width: double.infinity,
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.black12,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: groupsAsync.when(
        data: (groups) {
          final allGroups = [
            {'id': null, 'name': 'すべて'},
            {'id': systemGroupIdFreeMatch, 'name': 'フリー対局'},
            ...groups.where((g) => g['id'] != systemGroupIdFreeMatch),
          ];
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: allGroups.length,
            itemBuilder: (context, index) {
              final group = allGroups[index];
              final isSelected = selectedGroup == group['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    // すでに選択されている場合は null（すべて）に戻す
                    ref.read(historyGroupFilterProvider.notifier).setFilter(!isSelected ? (group['id'] as int?) : null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00FFC2) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2, // Noto Sans JP の見切れ防止のための明示的な行高
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Center(
        child: Text(
          '全対局履歴',
          style: GoogleFonts.notoSansJp(
            color: const Color(0xFF00FFC2),
            fontWeight: FontWeight.bold,
            fontSize: 22.0,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(WidgetRef ref, DateTimeRange selectedDateRange) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
      color: Colors.black26,
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 12, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            '期間: ${DateFormat('M/d').format(selectedDateRange.start)} 〜 ${DateFormat('M/d').format(selectedDateRange.end)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Spacer(),
          InkWell(
            onTap: () => ref.read(historyFilterProvider.notifier).setFilter(null),
            child: const Icon(Icons.close, size: 14, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> sessions, DateTimeRange? selectedDateRange, int? selectedGroup) {
    var filteredSessions = sessions;
    if (selectedGroup != null) {
      filteredSessions = filteredSessions.where((s) {
        final session = s['session'] as Session;
        return session.groupId == selectedGroup || (session.groupId == null && selectedGroup == systemGroupIdFreeMatch);
      }).toList();
    }
    if (selectedDateRange != null) {
      filteredSessions = filteredSessions.where((s) {
        final dt = (s['session'] as Session).date;
        final date = DateFormat('yyyy/MM/dd').parse(dt);
        return !date.isBefore(selectedDateRange.start) && 
               date.isBefore(selectedDateRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    if (filteredSessions.isEmpty) {
      return const Center(child: Text('履歴がありません', style: TextStyle(color: Colors.white24)));
    }

    return Column(
      children: [
        _buildTableHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: filteredSessions.length,
            itemBuilder: (context, index) {
              return _HistoryRow(
                data: filteredSessions[index],
                isOdd: index.isOdd,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withValues(alpha: 0.02),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('日付 / グループ', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('1位', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('2位', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('3位', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('4位', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  final Map<String, dynamic> data;
  final bool isOdd;
  const _HistoryRow({required this.data, required this.isOdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session session = data['session'];
    final String groupName = data['groupName'];
    final int gameCount = data['gameCount'];
    final List<int> totalPts = data['totalPt'];
    final List<int> totalMoney = data['totalMoney'];

    // プレイヤー情報をまとめてPt順にソート
    final List<Map<String, dynamic>> players = List.generate(totalPts.length, (i) {
      return {
        'name': session.playerNames[i],
        'pt': totalPts[i],
        'money': totalMoney[i],
      };
    });
    players.sort((a, b) => (b['pt'] as int).compareTo(a['pt'] as int));

    Color performanceColor(num value) {
      return value >= 0 ? const Color(0xFF00FFC2) : const Color(0xFFFF5252);
    }

    return InkWell(
      onTap: () => _showActionSheet(context, ref, data),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isOdd ? Colors.white.withValues(alpha: 0.01) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          children: [
            // Column 1: Info (flex 3)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.date, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    groupName,
                    style: TextStyle(
                      color: groupName == 'フリー対局' ? Colors.orangeAccent.withValues(alpha: 0.5) : const Color(0xFF00FFC2).withValues(alpha: 0.3),
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text('$gameCount局', style: const TextStyle(color: Colors.white12, fontSize: 9)),
                ],
              ),
            ),
            // Columns 2-5: Players (flex 2 each)
            ...players.asMap().entries.map((entry) {
              final int rank = entry.key; // 0-based index (0 is 1st place)
              final player = entry.value;
              final isWinner = rank == 0;

              return Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Name + Crown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isWinner)
                          const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(Icons.emoji_events, color: Colors.amber, size: 10),
                          ),
                        Flexible(
                          child: Text(
                            player['name'],
                            style: TextStyle(
                              color: isWinner ? Colors.white : Colors.white60,
                              fontSize: 10,
                              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Row 2: Pt
                    Text(
                      player['pt'] > 0 ? '+${player['pt']}' : '${player['pt']}',
                      style: TextStyle(
                        color: performanceColor(player['pt']),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Row 3: Money
                    Text(
                      '¥${(player['money'] as int).toCommaString()}',
                      style: TextStyle(
                        color: performanceColor(player['money']).withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Icon(Icons.chevron_right, color: Colors.white10, size: 12),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final Session session = data['session'];
    final groupsAsync = ref.watch(groupListProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${session.date} の対局',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.play_circle_outline, color: Color(0xFF00FFC2)),
              title: const Text('詳細を見る / 再開', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Action Sheetを閉じる
                FocusManager.instance.primaryFocus?.unfocus();
                ref.read(calcProvider.notifier).loadSession(session, data['games']);
                ref.read(navigationProvider.notifier).setTab(MainTab.calc);
              },
            ),
            groupsAsync.when(
              data: (groups) => ListTile(
                leading: const Icon(Icons.folder_shared_outlined, color: Colors.blueAccent),
                title: const Text('グループを変更', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupSelector(context, ref, session);
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFF00FFC2)),
              title: const Text('日付を変更', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final currentDate = DateFormat('yyyy/MM/dd').parse(session.date);
                final newDate = await showDatePicker(
                  context: context,
                  initialDate: currentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF00FFC2),
                          onPrimary: Colors.black,
                          surface: Color(0xFF001F1A),
                          onSurface: Colors.white,
                        ),
                        dialogBackgroundColor: const Color(0xFF001F1A),
                      ),
                      child: child!,
                    );
                  },
                );
                if (newDate != null && newDate != currentDate) {
                  await ref.read(historyProvider.notifier).updateSessionDate(session.id!, newDate);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('対局日を ${DateFormat('yyyy/MM/dd').format(newDate)} へ変更しました')),
                    );
                  }
                }
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('履歴を削除', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, session.id!);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showGroupSelector(BuildContext context, WidgetRef ref, Session session) {
    final groupsAsync = ref.watch(groupListProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      builder: (context) => groupsAsync.when(
        data: (groups) => ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('グループを選択', style: TextStyle(color: Colors.white54)),
            ),
            ListTile(
              title: const Text('フリー対局', style: TextStyle(color: Colors.white)),
              onTap: () {
                ref.read(historyProvider.notifier).updateSessionGroupId(session.id!, systemGroupIdFreeMatch);
                Navigator.pop(context);
              },
            ),
            ...groups.where((g) => g['id'] != systemGroupIdFreeMatch).map((g) => ListTile(
              title: Text(g['name'], style: const TextStyle(color: Colors.white)),
              onTap: () {
                ref.read(historyProvider.notifier).updateSessionGroupId(session.id!, g['id']);
                Navigator.pop(context);
              },
            )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('履歴削除', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('この対局履歴を削除してもよろしいですか？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(historyProvider.notifier).deleteSession(sessionId);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('履歴を削除しました')));
            },
            child: const Text('削除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/db_models.dart';
import 'history_providers.dart';
import '../main/main_providers.dart';
import '../stats/stats_providers.dart';
import '../calc/calc_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

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

    return Column(
      children: [
        _buildHeader(context),
        if (selectedDateRange != null) _buildFilterBar(ref, selectedDateRange),
        Expanded(
          child: history.when(
            data: (sessions) => _buildList(sessions, selectedDateRange),
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
            error: (e, s) => const Center(child: Text('読み込みエラー', style: TextStyle(color: Colors.white24))),
          ),
        ),
      ],
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
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF00FFC2),
            fontSize: 18,
            fontWeight: FontWeight.bold,
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

  Widget _buildList(List<Map<String, dynamic>> sessions, DateTimeRange? selectedDateRange) {
    var filteredSessions = sessions;
    if (selectedDateRange != null) {
      filteredSessions = sessions.where((s) {
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
          Expanded(flex: 2, child: Text('日付 / 局数', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('グループ / 参加者', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('成績 / 収支', textAlign: TextAlign.end, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))),
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

    // 自分 (Player 1) の成績
    final myPt = totalPts[0];
    final myMoney = totalMoney[0];

    final membersText = session.playerNames.join(', ');

    Color performanceColor(num value) {
      return value >= 0 ? const Color(0xFF00FFC2) : const Color(0xFFFF5252);
    }

    return InkWell(
      onTap: () => _showActionSheet(context, ref, data),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isOdd ? Colors.white.withValues(alpha: 0.01) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          children: [
            // Column 1: Date / Game Count
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.date, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$gameCount局', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
            ),
            // Column 2: Group / Members
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: TextStyle(
                      color: groupName == 'フリー対局' ? Colors.orangeAccent.withValues(alpha: 0.7) : const Color(0xFF00FFC2).withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    membersText,
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Column 3: My Performance
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    myPt > 0 ? '+$myPt pt' : '$myPt pt',
                    style: TextStyle(
                      color: performanceColor(myPt),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${myMoney.toCommaString()}',
                    style: TextStyle(
                      color: performanceColor(myMoney),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white10, size: 14),
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

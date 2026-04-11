import '../calc/calc_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/db_models.dart';
import 'history_providers.dart';
import '../main/main_providers.dart';
import '../stats/stats_providers.dart';

class HistoryBottomSheet extends ConsumerStatefulWidget {
  const HistoryBottomSheet({super.key});

  @override
  ConsumerState<HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends ConsumerState<HistoryBottomSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(historyProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final selectedDateRange = ref.watch(historyFilterProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF001F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Text(
            '対局履歴',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF00FFC2),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
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

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: filteredSessions.length,
      itemBuilder: (context, index) {
        final data = filteredSessions[index];
        final Session session = data['session'];
        
        return Dismissible(
          key: Key('session_${session.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.white.withValues(alpha: 0.03),
            child: const Icon(Icons.delete, color: Colors.redAccent),
          ),
          onDismissed: (_) {
            ref.read(historyProvider.notifier).deleteSession(session.id!);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('履歴を削除しました')));
          },
          child: _HistoryCard(data: data),
        );
      },
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session session = data['session'];
    final String groupName = data['groupName'];
    final int gameCount = data['gameCount'];
    final List<int> totalPts = data['totalPt'];
    final List<int> totalMoneys = data['totalMoney'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          ref.read(calcProvider.notifier).loadSession(session, data['games']);
          ref.read(navigationProvider.notifier).setTab(MainTab.calc);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${session.date} - $gameCount局', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      Text(
                        groupName,
                        style: TextStyle(
                          color: groupName == 'フリー対局' ? Colors.orangeAccent : const Color(0xFF00FFC2),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildHistoryActions(context, ref, session),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(session.playerNames.length, (i) {
                  final pt = totalPts[i];
                  final money = totalMoneys[i];
                  return Expanded(
                    child: Column(
                      children: [
                        Text(session.playerNames[i], style: const TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          pt > 0 ? '+$pt' : pt.toString(),
                          style: TextStyle(
                            color: pt >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('¥${money.toCommaString()}', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryActions(BuildContext context, WidgetRef ref, Session session) {
    final groupsAsync = ref.watch(groupListProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Group Edit Menu
        groupsAsync.when(
          data: (groups) => PopupMenuButton<int?>(
            icon: const Icon(Icons.folder_shared_outlined, color: Colors.white24, size: 18),
            tooltip: 'グループを変更',
            onSelected: (groupId) {
              ref.read(historyProvider.notifier).updateSessionGroupId(session.id!, groupId);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('フリー対局', style: TextStyle(fontSize: 13)),
              ),
              ...groups.map((g) => PopupMenuItem(
                    value: g['id'],
                    child: Text(g['name'], style: const TextStyle(fontSize: 13)),
                  )),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 4),
        // Delete Button
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
          onPressed: () => _confirmDelete(context, ref, session.id!),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
      ],
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

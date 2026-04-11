import '../calc/calc_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../calc/calc_screen.dart';
import '../history/history_screen.dart';
import '../stats/stats_screen.dart';
import '../group/group_screen.dart';
import '../calc/calc_state.dart';
import 'main_providers.dart';
import '../history/history_providers.dart';

// Navigation definitions moved to main_providers.dart

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(navigationProvider);
    final calcState = ref.watch(calcProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF001F1A),
      appBar: AppBar(
        leading: _buildLeading(context, ref, currentTab, calcState),
        title: _buildTitle(context, ref, currentTab, calcState),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        actions: _buildActions(context, ref, currentTab),
      ),
      drawer: _buildDrawer(context, ref, currentTab),
      body: IndexedStack(
        index: _getTabIndex(currentTab),
        children: const [
          CalcScreen(),
          StatsScreen(),
          GroupScreen(),
        ],
      ),
    );
  }

  int _getTabIndex(MainTab tab) {
    switch (tab) {
      case MainTab.calc: return 0;
      case MainTab.stats: return 1;
      case MainTab.groups: return 2;
      default: return 0;
    }
  }

  Widget? _buildLeading(BuildContext context, WidgetRef ref, MainTab tab, CalcState calcState) {
    return Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFF00FFC2)),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, WidgetRef ref, MainTab tab, CalcState calcState) {
    String title = '麻雀スコア表';
    if (tab == MainTab.stats) title = '統計・分析';
    if (tab == MainTab.groups) title = 'グループ管理';
    if (tab == MainTab.calc && calcState.currentId != null) title = '麻雀スコア表(履歴編集)';

    return GestureDetector(
      onTap: tab == MainTab.calc ? () => ref.read(calcProvider.notifier).resetGame() : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF00FFC2),
                fontWeight: FontWeight.bold,
                fontSize: 22.0,
              ),
            ),
          ),
          const Text(
            'Ver 3.2.4',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref, MainTab tab) {
    if (tab == MainTab.calc) {
      return [
        IconButton(
          icon: const Icon(Icons.settings, color: Color(0xFF00FFC2), size: 18),
          onPressed: () => CalcScreen.showSettings(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.save, color: Color(0xFF00FFC2), size: 18),
          onPressed: () => CalcScreen.showSave(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFFFF5252), size: 18),
          onPressed: () => CalcScreen.showReset(context, ref),
        ),
        const SizedBox(width: 8),
      ];
    }
    if (tab == MainTab.groups) {
      return [
        IconButton(
          icon: const Icon(Icons.add, color: Color(0xFF00FFC2)),
          onPressed: () => GroupScreen.showAddGroup(context, ref),
        ),
        const SizedBox(width: 8),
      ];
    }
    return [];
  }

  void _openHistoryBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
        child: const HistoryBottomSheet(),
      ),
    );
  }


  void _showHistoryCleanup(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('履歴のクリーンアップ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _cleanupOption(context, ref, '3ヶ月以上前を削除', 3),
            _cleanupOption(context, ref, '6ヶ月以上前を削除', 6),
            _cleanupOption(context, ref, '1年以上前を削除', 12),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('すべての履歴を削除', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirmDelete(context, '本当にすべての履歴を削除しますか？');
                if (confirmed) {
                  await ref.read(historyProvider.notifier).clearHistory(all: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cleanupOption(BuildContext context, WidgetRef ref, String label, int months) {
    return ListTile(
      leading: const Icon(Icons.history, color: Color(0xFF00FFC2)),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () async {
        Navigator.pop(context);
        final confirmed = await _confirmDelete(context, '$monthsヶ月以上前の履歴を削除しますか？');
        if (confirmed) {
          await ref.read(historyProvider.notifier).clearHistory(months: months);
        }
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('削除の確認', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, MainTab currentTab) {
    return Drawer(
      backgroundColor: const Color(0xFF001F1A),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF002E26)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFC2).withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text('🀄', style: TextStyle(fontSize: 44)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '麻雀スコア表',
                    style: GoogleFonts.notoSansJp(
                      color: const Color(0xFF00FFC2),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _drawerItem(context, ref, Icons.calculate, 'スコア計算', MainTab.calc, currentTab),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.white38, size: 20),
            title: const Text('対局履歴', style: TextStyle(color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _openHistoryBottomSheet(context, ref);
            },
          ),
          _drawerItem(context, ref, Icons.bar_chart, '統計・分析', MainTab.stats, currentTab),
          _drawerItem(context, ref, Icons.group, 'グループ管理', MainTab.groups, currentTab),
          const Spacer(),
          const Divider(color: Colors.white10),
          _drawerAction(context, ref, Icons.delete_sweep, '履歴クリーンアップ', () => _showHistoryCleanup(context, ref)),
          const Divider(color: Colors.white10),
          _drawerAction(context, ref, Icons.download, 'バックアップ保存', () => CalcScreen.exportData(context, ref)),
          _drawerAction(context, ref, Icons.upload, 'データ復元', () => CalcScreen.importData(context, ref)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, WidgetRef ref, IconData icon, String title, MainTab tab, MainTab currentTab) {
    final isSelected = tab == currentTab;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF00FFC2) : Colors.white38, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF00FFC2) : Colors.white70,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        ref.read(navigationProvider.notifier).setTab(tab);
        Navigator.pop(context);
      },
    );
  }

  Widget _drawerAction(BuildContext context, WidgetRef ref, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white38, size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

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
import '../help/help_screen.dart';

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
          HistoryScreen(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getTabIndex(currentTab),
        onTap: (index) {
          final tabs = [MainTab.calc, MainTab.history, MainTab.stats];
          ref.read(navigationProvider.notifier).setTab(tabs[index]);
        },
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        selectedItemColor: const Color(0xFF00FFC2),
        unselectedItemColor: Colors.white24,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), activeIcon: Icon(Icons.calculate), label: 'スコア計算'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: '対局履歴'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: '統計・分析'),
        ],
      ),
    );
  }

  int _getTabIndex(MainTab tab) {
    switch (tab) {
      case MainTab.calc: return 0;
      case MainTab.history: return 1;
      case MainTab.stats: return 2;
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
    if (tab == MainTab.history) title = '対局履歴';
    if (tab == MainTab.stats) title = '統計・分析';
    if (tab == MainTab.calc && calcState.currentId != null) title = '麻雀スコア表(履歴編集)';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
          ),
        ),
        Text(
          'Ver 2.3.0',
          style: GoogleFonts.notoSansJp(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref, MainTab tab) {
    if (tab == MainTab.calc) {
      return [
        IconButton(
          icon: const Icon(Icons.group_add, color: Color(0xFF00FFC2), size: 18),
          tooltip: 'グループからメンバーを呼び出す',
          onPressed: () => CalcScreen.showMemberPicker(context, ref),
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
    if (tab == MainTab.history) {
      return [
        IconButton(
          icon: const Icon(Icons.download, color: Color(0xFF00FFC2), size: 18),
          tooltip: 'CSVエクスポート',
          onPressed: () => HistoryScreen.exportCsv(context, ref),
        ),
        const SizedBox(width: 8),
      ];
    }
    return [];
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
            Text('履歴のクリーンアップ', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _cleanupOption(context, ref, '3ヶ月以上前を削除', 3),
            _cleanupOption(context, ref, '6ヶ月以上前を削除', 6),
            _cleanupOption(context, ref, '1年以上前を削除', 12),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: Text('すべての履歴を削除', style: GoogleFonts.notoSansJp(color: Colors.redAccent)),
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
      title: Text(label, style: GoogleFonts.notoSansJp(color: Colors.white70)),
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
        title: Text('削除の確認', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 16)),
        content: Text(message, style: GoogleFonts.notoSansJp(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('キャンセル', style: GoogleFonts.notoSansJp(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('削除', style: GoogleFonts.notoSansJp(color: Colors.redAccent))),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, MainTab currentTab) {
    return Drawer(
      backgroundColor: const Color(0xFF001F1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFC2).withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text('🀄', style: GoogleFonts.notoSansJp(fontSize: 44)),
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
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _categoryLabel('[SYSTEM]'),
                _drawerAction(context, ref, Icons.group, 'グループ管理', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupScreen()));
                }),
                _drawerAction(context, ref, Icons.settings_outlined, 'アプリ設定', () {
                  CalcScreen.showSettings(context, ref);
                }),

                const Spacer(),
                
                const Divider(color: Colors.white10),
                _categoryLabel('[DATA]'),
                _drawerAction(context, ref, Icons.storage_outlined, 'バックアップ', () => _showBackupMenu(context, ref), iconColor: Colors.white24),
                _drawerAction(context, ref, Icons.delete_sweep, '履歴クリーンアップ', () => _showHistoryCleanup(context, ref), iconColor: Colors.orangeAccent.withValues(alpha: 0.6), titleColor: Colors.orangeAccent.withValues(alpha: 0.8)),

                const Divider(color: Colors.white10),
                _categoryLabel('[SUPPORT]'),
                _drawerAction(context, ref, Icons.help_outline, 'ヘルプ / 使い方', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()));
                }),
                _drawerAction(context, ref, Icons.info_outline, 'バージョン情報', () => _showVersionInfo(context), iconColor: Colors.white24),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: Text('バージョン情報', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('麻雀スコア表', style: GoogleFonts.notoSansJp(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Version: 2.3.0', style: GoogleFonts.notoSansJp(color: Colors.white70, fontSize: 13)),
            Text('Build: 73', style: GoogleFonts.notoSansJp(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 16),
            Text('© 2026 Admin Test Hoyo', style: GoogleFonts.notoSansJp(color: Colors.white24, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる', style: GoogleFonts.notoSansJp(color: const Color(0xFF00FFC2))),
          ),
        ],
      ),
    );
  }

  void _showBackupMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('バックアップ設定', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF00FFC2)),
              title: Text('データを外部保存 (エクスポート)', style: GoogleFonts.notoSansJp(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                CalcScreen.exportData(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload, color: Color(0xFF00FFC2)),
              title: Text('データを復元 (インポート)', style: GoogleFonts.notoSansJp(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                CalcScreen.importData(context, ref);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _categoryLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.notoSansJp(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }


  Widget _drawerAction(BuildContext context, WidgetRef ref, IconData icon, String title, VoidCallback onTap, {Color? iconColor, Color? titleColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
      leading: Icon(icon, color: iconColor ?? Colors.white38, size: 20),
      title: Text(title, style: GoogleFonts.notoSansJp(color: titleColor ?? Colors.white70, fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

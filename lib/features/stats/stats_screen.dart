import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/database_service.dart';
import '../../core/models/db_models.dart';
import '../../core/database/database_providers.dart';
import '../stats/stats_providers.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  // ── タブ ──────────────────────────────────────────────
  late TabController _tabController;

  // ── 個人分析 ──────────────────────────────────────────
  String? _selectedPlayer;
  int? _selectedGroupId;
  List<SavedGame> _allGames = [];
  List<Session> _allSessions = [];
  List<String> _players = [];
  List<String> _groupMembers = [];

  // ── グループ分析 ───────────────────────────────────────
  int? _rankingGroupId;
  List<Map<String, dynamic>> _rankingData = [];
  bool _rankingLoading = false;
  // ソート状態
  int _sortColumnIndex = 2; // デフォルト: 総Pt
  bool _sortAscending = false; // 降順

  // ── 共通 ──────────────────────────────────────────────
  List<Map<String, dynamic>> _groupList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // 既存の非同期ロード処理を、プロバイダー経由に変更するか、
    // またはリフレッシュ目的で明示的に呼び出す。
    // ここでは互換性のため _loadGames を残しつつ、プロバイダーの恩恵も受ける。
    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      _players = await db.getAllPlayerNames();
      _groupList = await db.getGroups();
      await _loadGames();
    } catch (e) {
      debugPrint('Initial load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGames() async {
    final db = DatabaseService();
    final rows = await db.getGames();
    _allGames = rows.map((e) => SavedGame.fromMap(e)).toList();

    final sessionRows = await db.getSessions();
    _allSessions = sessionRows.map((e) {
      final names = <String>[e['p1_name']??'', e['p2_name']??'', e['p3_name']??'', e['p4_name']??''];
      final moneys = <int>[(e['p1_money'] as num?)?.toInt() ?? 0, (e['p2_money'] as num?)?.toInt() ?? 0, (e['p3_money'] as num?)?.toInt() ?? 0, (e['p4_money'] as num?)?.toInt() ?? 0];
      return Session(
        id: e['id'] as int,
        date: e['date'] as String,
        groupId: e['group_id'] as int?,
        playerNames: names,
        totalMoneys: moneys,
      );
    }).toList();

    if (_selectedGroupId != null) {
      final members = await db.getMembers(_selectedGroupId!);
      _groupMembers = members.map((e) => e['name'] as String).toList();
    } else {
      _groupMembers = [];
    }
  }

  List<Session> get _filteredSessions {
    if (_selectedPlayer == null) return [];
    var filtered = _allSessions;
    if (_selectedGroupId != null) {
      if (_groupMembers.isEmpty || !_groupMembers.contains(_selectedPlayer)) {
        return [];
      }
      filtered = filtered.where((s) => s.groupId == _selectedGroupId).toList();
    }
    filtered = filtered.where((s) => s.playerNames.contains(_selectedPlayer)).toList();
    return filtered;
  }

  Future<void> _loadGroupRanking(int groupId) async {
    setState(() => _rankingLoading = true);
    try {
      final db = DatabaseService();
      final data = await db.getGroupRanking(groupId);
      // デフォルトソート: 総Pt (インデックス 2) 降順
      _sortColumnIndex = 2;
      _sortAscending = false;
      _rankingData = _sortedData(data, 2, false);
    } catch (e) {
      debugPrint('Group ranking error: $e');
      _rankingData = [];
    } finally {
      if (mounted) setState(() => _rankingLoading = false);
    }
  }

  List<Map<String, dynamic>> _sortedData(
      List<Map<String, dynamic>> data, int colIdx, bool ascending) {
    final keys = [
      'name', 'matches', 'totalPt', 'totalChip', 'totalScore',
      'avgRank', 'games', 'topRate', 'rentaiRate', 'tobiRate',
    ];
    final key = colIdx < keys.length ? keys[colIdx] : 'totalPt';
    final sorted = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) {
        final av = a[key];
        final bv = b[key];
        int cmp;
        if (av is String && bv is String) {
          cmp = av.compareTo(bv);
        } else {
          cmp = (av as num).compareTo(bv as num);
        }
        return ascending ? cmp : -cmp;
      });
    return sorted;
  }

  List<SavedGame> get _filteredGames {
    if (_selectedPlayer == null) return [];
    var filtered = _allGames;
    if (_selectedGroupId != null) {
      filtered = filtered.where((g) => g.groupId == _selectedGroupId).toList();
    }
    filtered = filtered.where((g) => g.playerNames.contains(_selectedPlayer)).toList();
    return filtered;
  }

  // ─────────────────── BUILD ───────────────────────────
  @override
  Widget build(BuildContext context) {
    // 統計データプロバイダーの状態を監視し、変更があればデータを再ロードする
    ref.listen(databaseVersionProvider, (_, __) => _loadInitialData());
    
    if (_rankingGroupId != null) {
      final rankingAsync = ref.watch(groupRankingProvider(_rankingGroupId!));
      rankingAsync.whenData((data) {
        if (_rankingData != data) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) setState(() => _rankingData = data);
           });
        }
      });
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00FFC2)));
    }

    return Column(
      children: [
        Container(
          color: Colors.black12,
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00FFC2),
            labelColor: const Color(0xFF00FFC2),
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.robotoMono(fontSize: 13),
            tabs: const [
              Tab(text: '個人分析'),
              Tab(text: 'グループ分析'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalTab(),
              _buildGroupTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────── 個人分析タブ ────────────────────────
  Widget _buildPersonalTab() {
    final games = _filteredGames;
    return Column(
      children: [
        _buildPersonalFilters(),
        Expanded(
          child: _selectedPlayer == null
              ? const Center(
                  child: Text('プレイヤーを選択してください',
                      style: TextStyle(color: Colors.white54, fontSize: 14)))
              : games.isEmpty
                  ? const Center(
                      child: Text('データがありません',
                          style: TextStyle(color: Colors.white24)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Consumer(
                            builder: (context, ref, child) {
                              final statsAsync = ref.watch(recordStatsProvider((playerName: _selectedPlayer!, groupId: _selectedGroupId)));
                              return statsAsync.when(
                                data: (data) => Column(
                                  children: [
                                    _buildGeneralStats(data),
                                    const SizedBox(height: 24),
                                    _buildRankChart(games),
                                    const SizedBox(height: 24),
                                    _buildPointChart(data),
                                  ],
                                ),
                                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
                                error: (e, s) => Text('エラー: $e', style: const TextStyle(color: Colors.redAccent)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPersonalFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 8), // Top margin to avoid overlap with tabs
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlayer,
                hint: const Text('プレイヤー選択',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
                dropdownColor: const Color(0xFF001F1A),
                isExpanded: true,
                style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 13),
                items: [
                  ..._players.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p))),
                ],
                onChanged: (val) => setState(() => _selectedPlayer = val),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedGroupId,
                hint: const Text('グループ選択',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
                dropdownColor: const Color(0xFF001F1A),
                isExpanded: true,
                style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 13),
                items: [
                  const DropdownMenuItem<int>(
                      value: null,
                      child: Text('全グループ')),
                  ..._groupList.map((g) => DropdownMenuItem(
                      value: g['id'] as int,
                      child: Text(g['name']))),
                ],
                onChanged: (val) async {
                  setState(() => _selectedGroupId = val);
                  await _loadGames();
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── グループ分析タブ ────────────────────
  Widget _buildGroupTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rankingGroupId,
              hint: const Text('グループを選択してください',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              dropdownColor: const Color(0xFF001F1A),
              isExpanded: true,
              style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 13),
              items: [
                ..._groupList.map((g) => DropdownMenuItem(
                    value: g['id'] as int,
                    child: Text(g['name']))),
              ],
              onChanged: (val) async {
                setState(() => _rankingGroupId = val);
                if (val != null) await _loadGroupRanking(val);
              },
            ),
          ),
        ),
        // リーダーボード本体
        Expanded(
          child: _rankingGroupId == null
              ? const Center(
                  child: Text('グループを選択してください',
                      style: TextStyle(color: Colors.white54, fontSize: 14)))
              : _rankingLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00FFC2)))
                  : _rankingData.isEmpty
                      ? const Center(
                          child: Text('データがありません',
                              style: TextStyle(color: Colors.white24)))
                      : _buildLeaderboard(),
        ),
      ],
    );
  }

  Widget _buildLeaderboard() {
    // 順位列を追加した表示用データ
    final rows = _rankingData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowColor: WidgetStateProperty.all(
                const Color(0xFF00BFA5).withValues(alpha: 0.15)),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF00FFC2).withValues(alpha: 0.05);
              }
              return Colors.transparent;
            }),
            headingTextStyle: GoogleFonts.robotoMono(
                color: const Color(0xFF00FFC2),
                fontSize: 11,
                fontWeight: FontWeight.bold),
            dataTextStyle:
                const TextStyle(color: Colors.white70, fontSize: 11),
            columnSpacing: 16,
            columns: [
              // 列0: 名前
              DataColumn(
                label: const Text('名前'),
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列1: 対戦回数
              DataColumn(
                label: const Text('対戦回数'),
                tooltip: '打った日数（セッション数）',
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列2: 総Pt
              DataColumn(
                label: const Text('総Pt'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列3: 総Chip
              DataColumn(
                label: const Text('総Ch'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列4: 総収支
              DataColumn(
                label: const Text('収支 (円)'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列5: 平均順位
              DataColumn(
                label: const Text('平均順位'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列6: 対局数
              DataColumn(
                label: const Text('対局数(半荘)'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列7: トップ率
              DataColumn(
                label: const Text('1着%'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列8: 連対率
              DataColumn(
                label: const Text('連対%'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列9: トビ率
              DataColumn(
                label: const Text('トビ%'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
            ],
            rows: List.generate(rows.length, (i) {
              final r = rows[i];
              final matches = (r['matches'] as num?)?.toInt() ?? 0;
              final totalPt = (r['totalPt'] as num?)?.toInt() ?? 0;
              final totalChip = (r['totalChip'] as num?)?.toInt() ?? 0;
              final totalScore = (r['totalScore'] as num?)?.toInt() ?? 0;
              final avgRank = (r['avgRank'] as num?)?.toDouble() ?? 0.0;
              final games = (r['games'] as num?)?.toInt() ?? 0;
              final topRate = (r['topRate'] as num?)?.toDouble() ?? 0.0;
              final rentaiRate = (r['rentaiRate'] as num?)?.toDouble() ?? 0.0;
              final tobiRate = (r['tobiRate'] as num?)?.toDouble() ?? 0.0;

              Color ptColor = totalPt >= 0
                  ? const Color(0xFF00FFC2)
                  : Colors.redAccent;
              Color scoreColor = totalScore >= 0
                  ? const Color(0xFF00FFC2)
                  : Colors.redAccent;

              return DataRow(
                cells: [
                  // 名前（順位バッジ付き）
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _rankBadge(i + 1),
                      const SizedBox(width: 6),
                      Text(r['name'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  )),
                  // 対戦回数
                  DataCell(Text('$matches',
                      style: const TextStyle(fontSize: 11))),
                  // 総Pt
                  DataCell(Text(
                    totalPt >= 0 ? '+$totalPt' : '$totalPt',
                    style: TextStyle(
                        color: ptColor,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  )),
                  // 総Chip
                  DataCell(Text(
                    totalChip >= 0 ? '+$totalChip' : '$totalChip',
                    style: TextStyle(
                        color: totalChip >= 0
                            ? Colors.amberAccent
                            : Colors.redAccent,
                        fontFamily: 'RobotoMono',
                        fontSize: 12),
                  )),
                  // 総収支 (Money)
                   DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '¥${_formatNumber(totalScore)}',
                      style: TextStyle(
                          color: scoreColor,
                          fontFamily: 'RobotoMono',
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  )),
                  // 平均順位
                  DataCell(Text(avgRank.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 11))),
                  // 対局数
                  DataCell(Text('$games',
                      style: const TextStyle(fontSize: 11))),
                  // トップ率
                  DataCell(Text('${topRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: topRate >= 25
                              ? const Color(0xFF00FFC2)
                              : Colors.white54,
                          fontSize: 11))),
                  // 連対率
                  DataCell(Text('${rentaiRate.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 11))),
                  // トビ率
                  DataCell(Text('${tobiRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: tobiRate > 10
                              ? Colors.redAccent
                              : Colors.white54,
                          fontSize: 11))),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    final colors = {
      1: const Color(0xFFFFD700), // gold
      2: const Color(0xFFC0C0C0), // silver
      3: const Color(0xFFCD7F32), // bronze
    };
    final color = colors[rank] ?? Colors.white24;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _rankingData = _sortedData(_rankingData, columnIndex, ascending);
    });
  }

  // ─────────────────── 個人分析ウィジェット群 ───────────────
  Widget _buildGeneralStats(Map<String, dynamic> stats) {
    if (_selectedPlayer == null) return const SizedBox.shrink();

    final totalPt = stats['totalPt'] as int? ?? 0;
    final totalChips = stats['totalChip'] as int? ?? 0;
    final totalMoney = stats['totalMoney'] as int? ?? 0;
    final avgRank = stats['avgRank'] as double? ?? 0.0;
    final winRate = (stats['topRate'] as double? ?? 0.0).toStringAsFixed(1);
    final rentaiRate = (stats['rentaiRate'] as double? ?? 0.0).toStringAsFixed(1);
    final tobiRate = (stats['tobiRate'] as double? ?? 0.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('平均順位', avgRank.toStringAsFixed(2)),
              _statItem(
                '総Pt',
                totalPt > 0 ? '+$totalPt' : totalPt.toString(),
                color: totalPt >= 0
                    ? const Color(0xFF00FFC2)
                    : Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(
                '総Chip',
                totalChips > 0 ? '+$totalChips' : totalChips.toString(),
                color: totalChips >= 0
                    ? Colors.amberAccent
                    : Colors.redAccent,
              ),
              _statItem(
                '収支 (円)',
                _formatNumber(totalMoney),
                color: totalMoney >= 0
                    ? const Color(0xFF00FFC2)
                    : Colors.redAccent,
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('トップ率', '$winRate%'),
              _statItem('連対率', '$rentaiRate%'),
              _statItem('トビ率', '$tobiRate%', color: Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white24, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'RobotoMono')),
      ],
    );
  }

  Widget _buildRankChart(List<SavedGame> games) {
    final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0};
    for (var g in games) {
      int idx = 0;
      if (_selectedPlayer != null) {
        idx = g.playerNames.indexOf(_selectedPlayer!);
        if (idx == -1) idx = 0;
      }
      counts[g.ranks[idx]] = (counts[g.ranks[idx]] ?? 0) + 1;
    }

    final sections = [
      PieChartSectionData(
          value: counts[1]!.toDouble(),
          title: '1',
          color: const Color(0xFF00FFC2),
          radius: 40,
          titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
      PieChartSectionData(
          value: counts[2]!.toDouble(),
          title: '2',
          color: Colors.lightGreenAccent,
          radius: 40,
          titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
      PieChartSectionData(
          value: counts[3]!.toDouble(),
          title: '3',
          color: Colors.orangeAccent,
          radius: 40,
          titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
      PieChartSectionData(
          value: counts[4]!.toDouble(),
          title: '4',
          color: Colors.redAccent,
          radius: 40,
          titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.black26, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('順位分布',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PieChart(
                PieChartData(
                    sections: sections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildPointChart(Map<String, dynamic> data) {
    final history = data['pointHistory'] as List<Map<String, dynamic>>? ?? [];
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = history.map((h) => 
      FlSpot((h['gameNo'] as int).toDouble(), (h['cumulativePt'] as int).toDouble())
    ).toList();

    // 0点目（開始点）を追加
    final allSpots = [const FlSpot(0, 0), ...spots];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text('累計Pt推移', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        Container(
          height: 260,
          padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 50,
                verticalInterval: 5,
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                getDrawingVerticalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('対局数 (No.)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 5,
                    getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('累計Pt', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ),
                ),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
              lineBarsData: [
                LineChartBarData(
                  spots: allSpots,
                  isCurved: true,
                  color: const Color(0xFF00FFC2),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: const Color(0xFF00FFC2), strokeWidth: 2, strokeColor: Colors.black),
                  ),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF00FFC2).withValues(alpha: 0.1)),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: 0, color: const Color(0xFFFF4D4D).withValues(alpha: 0.5), strokeWidth: 2, dashArray: [5, 5], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 10), labelResolver: (_) => '基準(0pt)')),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Colors.grey[900]!,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((spot) {
                      final h = history.firstWhere((element) => element['gameNo'] == spot.x.toInt(), orElse: () => {'pt': 0});
                      return LineTooltipItem(
                        'No.${spot.x.toInt()}\nPt: ${h['pt']}\n累計: ${spot.y.toInt()}',
                        const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  String _formatNumber(int number) {
    final s = number.toString();
    final isNegative = number < 0;
    final absS = isNegative ? s.substring(1) : s;
    final buffer = StringBuffer();
    for (int i = 0; i < absS.length; i++) {
      if (i > 0 && (absS.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(absS[i]);
    }
    return (isNegative ? '-' : '+') + buffer.toString();
  }
}

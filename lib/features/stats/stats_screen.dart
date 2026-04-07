import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/database_service.dart';
import '../../core/models/db_models.dart';

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
  bool _isThreePlayer = false;
  String? _selectedPlayer;
  int? _selectedGroupId;
  List<SavedGame> _allGames = [];
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
    final rows = await db.getGames(
      type: _isThreePlayer ? '3-player' : '4-player',
    );
    _allGames = rows.map((e) => SavedGame.fromMap(e)).toList();

    if (_selectedGroupId != null) {
      final members = await db.getMembers(_selectedGroupId!);
      _groupMembers = members.map((e) => e['name'] as String).toList();
    } else {
      _groupMembers = [];
    }
  }

  Future<void> _loadGroupRanking(int groupId) async {
    setState(() => _rankingLoading = true);
    try {
      final db = DatabaseService();
      final data = await db.getGroupRanking(groupId);
      // デフォルトソート: 総Pt 降順
      _sortColumnIndex = 1;
      _sortAscending = false;
      _rankingData = _sortedData(data, 1, false);
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
      'name', 'totalPt', 'totalChip', 'totalScore',
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
      if (_groupMembers.isEmpty || !_groupMembers.contains(_selectedPlayer)) {
        return [];
      }
      filtered = filtered.where((g) {
        final participants = g.playerNames.where((n) => n.isNotEmpty);
        return participants.isNotEmpty &&
            participants.every((name) => _groupMembers.contains(name));
      }).toList();
    }
    filtered = filtered.where((g) => g.playerNames.contains(_selectedPlayer)).toList();
    return filtered;
  }

  // ─────────────────── BUILD ───────────────────────────
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF004D40),
        appBar: AppBar(
          title: Text(
            '統計・分析',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF00FFC2),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.black.withOpacity(0.3),
          elevation: 0,
          actions: [
            Switch(
              value: _isThreePlayer,
              onChanged: (val) async {
                setState(() => _isThreePlayer = val);
                await _loadGames();
                setState(() {});
              },
              activeColor: const Color(0xFF00BFA5),
              activeTrackColor: const Color(0xFF00BFA5).withOpacity(0.3),
              inactiveThumbColor: const Color(0xFF00BFA5),
              inactiveTrackColor: const Color(0xFF00BFA5).withOpacity(0.3),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  _isThreePlayer ? '3人' : '4人',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ),
          ],
          bottom: TabBar(
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
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalTab(),
                  _buildGroupTab(),
                ],
              ),
      ),
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
                          _buildGeneralStats(games),
                          const SizedBox(height: 24),
                          _buildRankChart(games),
                          const SizedBox(height: 24),
                          _buildRevenueChart(games),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPersonalFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black12,
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
                items: [
                  ..._players.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)))),
                ],
                onChanged: (val) => setState(() => _selectedPlayer = val),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedGroupId,
                hint: const Text('グループ選択',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
                dropdownColor: const Color(0xFF001F1A),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                      value: null,
                      child: Text('全グループ',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12))),
                  ..._groupList.map((g) => DropdownMenuItem(
                      value: g['id'] as int,
                      child: Text(g['name'],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)))),
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
        // グループ選択ドロップダウン
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black12,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rankingGroupId,
              hint: const Text('グループを選択してください',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              dropdownColor: const Color(0xFF001F1A),
              isExpanded: true,
              items: [
                ..._groupList.map((g) => DropdownMenuItem(
                    value: g['id'] as int,
                    child: Text(g['name'],
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)))),
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
                const Color(0xFF00BFA5).withOpacity(0.15)),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF00FFC2).withOpacity(0.05);
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
              // 列1: 総Pt
              DataColumn(
                label: const Text('総Pt'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列2: 総Chip
              DataColumn(
                label: const Text('総Ch'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列3: 総収支
              DataColumn(
                label: const Text('収支 (円)'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列4: 平均順位
              DataColumn(
                label: const Text('平均順'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列5: 対局数
              DataColumn(
                label: const Text('対局数'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列6: トップ率
              DataColumn(
                label: const Text('1着%'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列7: 連対率
              DataColumn(
                label: const Text('連対%'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
              // 列8: トビ率
              DataColumn(
                label: const Text('トビ%'),
                numeric: true,
                onSort: (col, asc) => _onSort(col, asc),
              ),
            ],
            rows: List.generate(rows.length, (i) {
              final r = rows[i];
              final totalPt = r['totalPt'] as int;
              final totalChip = r['totalChip'] as int;
              final totalScore = r['totalScore'] as int;
              final avgRank = r['avgRank'] as double;
              final games = r['games'] as int;
              final topRate = r['topRate'] as double;
              final rentaiRate = r['rentaiRate'] as double;
              final tobiRate = r['tobiRate'] as double;

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
                      color: scoreColor.withOpacity(0.1),
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
        color: color.withOpacity(0.2),
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
  Widget _buildGeneralStats(List<SavedGame> games) {
    final totalGames = games.length;
    double avgRank = 0;
    int totalPt = 0;
    int tobiCount = 0;
    int topCount = 0;
    int rentaiCount = 0;

    for (var g in games) {
      int idx = 0;
      if (_selectedPlayer != null) {
        idx = g.playerNames.indexOf(_selectedPlayer!);
        if (idx == -1) idx = 0;
      }
      avgRank += g.ranks[idx];
      totalPt += g.points[idx];
      if (g.tobis[idx]) tobiCount++;
      if (g.ranks[idx] == 1) topCount++;
      if (g.ranks[idx] <= 2) rentaiCount++;
    }

    avgRank /= totalGames;
    final winRate = (topCount / totalGames * 100).toStringAsFixed(1);
    final rentaiRate = (rentaiCount / totalGames * 100).toStringAsFixed(1);
    final tobiRate = (tobiCount / totalGames * 100).toStringAsFixed(1);

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
                '総収支',
                totalPt > 0 ? '+$totalPt' : totalPt.toString(),
                color: totalPt >= 0
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
      if (!_isThreePlayer)
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

  Widget _buildRevenueChart(List<SavedGame> games) {
    List<FlSpot> spots = [const FlSpot(0, 0)];
    int cumulative = 0;
    for (int i = 0; i < games.length; i++) {
      final g = games[games.length - 1 - i];
      int idx = 0;
      if (_selectedPlayer != null) {
        idx = g.playerNames.indexOf(_selectedPlayer!);
        if (idx == -1) idx = 0;
      }
      cumulative += g.points[idx];
      spots.add(FlSpot((i + 1).toDouble(), cumulative.toDouble()));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.black26, borderRadius: BorderRadius.circular(16)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF00FFC2),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF00FFC2).withOpacity(0.1)),
            ),
          ],
        ),
      ),
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

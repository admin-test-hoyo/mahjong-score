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

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _isThreePlayer = false;
  String? _selectedPlayer;
  int? _selectedGroupId;
  
  List<SavedGame> _allGames = []; // Cache all games for filtering
  List<String> _players = [];
  List<Map<String, dynamic>> _groupList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      _players = await db.getAllPlayerNames();
      _groupList = await db.getGroups();
      await _loadGames();
    } catch (e) {
      print('Initial load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGames() async {
    final db = DatabaseService();
    final rows = await db.getGames(
      type: _isThreePlayer ? '3-player' : '4-player',
      groupId: _selectedGroupId,
    );
    _allGames = rows.map((e) => SavedGame.fromMap(e)).toList();
  }

  List<SavedGame> get _filteredGames {
    if (_selectedPlayer == null || _selectedPlayer!.isEmpty) return _allGames;
    return _allGames.where((g) => g.playerNames.contains(_selectedPlayer)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final games = _filteredGames;

    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('統計・分析', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 16)),
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
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
        : Column(
            children: [
              _buildFilters(),
              Expanded(
                child: games.isEmpty 
                  ? const Center(child: Text('データがありません', style: TextStyle(color: Colors.white24)))
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
                          if (_selectedGroupId != null) ...[
                            const SizedBox(height: 24),
                            _buildGroupRanking(),
                          ],
                        ],
                      ),
                    ),
              ),
            ],
          ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black12,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlayer,
                hint: const Text('プレイヤー選択', style: TextStyle(color: Colors.white24, fontSize: 12)),
                dropdownColor: const Color(0xFF001F1A),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('全員', style: TextStyle(color: Colors.white70, fontSize: 12))),
                  ..._players.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 12)))),
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
                hint: const Text('グループ選択', style: TextStyle(color: Colors.white24, fontSize: 12)),
                dropdownColor: const Color(0xFF001F1A),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('全グループ', style: TextStyle(color: Colors.white70, fontSize: 12))),
                  ..._groupList.map((g) => DropdownMenuItem(value: g['id'] as int, child: Text(g['name'], style: const TextStyle(color: Colors.white, fontSize: 12)))),
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
              _statItem('総収支', totalPt > 0 ? '+${totalPt}' : totalPt.toString(), 
                color: totalPt >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent),
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
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')),
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
      PieChartSectionData(value: counts[1]!.toDouble(), title: '1', color: const Color(0xFF00FFC2), radius: 40, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      PieChartSectionData(value: counts[2]!.toDouble(), title: '2', color: Colors.lightGreenAccent, radius: 40, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      PieChartSectionData(value: counts[3]!.toDouble(), title: '3', color: Colors.orangeAccent, radius: 40, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      if (!_isThreePlayer)
        PieChartSectionData(value: counts[4]!.toDouble(), title: '4', color: Colors.redAccent, radius: 40, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('順位分布', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 2)),
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
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
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
              belowBarData: BarAreaData(show: true, color: const Color(0xFF00FFC2).withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupRanking() {
    final Map<String, int> scores = {};
    for (var g in _allGames) {
      for (int i = 0; i < g.playerNames.length; i++) {
        final name = g.playerNames[i];
        if (name.isNotEmpty) {
          scores[name] = (scores[name] ?? 0) + g.points[i];
        }
      }
    }

    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('グループ内収支ランキング', style: TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: sortedEntries.map((e) => ListTile(
              dense: true,
              title: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              trailing: Text(
                e.value > 0 ? '+${e.value}' : e.value.toString(),
                style: TextStyle(
                  color: e.value >= 0 ? const Color(0xFF00FFC2) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

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
  List<SavedGame> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      final rows = await db.getGames(type: _isThreePlayer ? '3-player' : '4-player');
      _games = rows.map((e) => SavedGame.fromMap(e)).toList();
    } catch (e) {
      print('Stats load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('統計・分析', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        actions: [
          Switch(
            value: _isThreePlayer,
            onChanged: (val) {
              setState(() => _isThreePlayer = val);
              _loadData();
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
        : _games.isEmpty 
          ? const Center(child: Text('データがありません', style: TextStyle(color: Colors.white24)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGeneralStats(),
                  const SizedBox(height: 24),
                  _buildRankChart(),
                  const SizedBox(height: 24),
                  _buildRevenueChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildGeneralStats() {
    // Current user's stats (Assuming p1 is always the user for this iteration or overall aggregate)
    // Actually the user wants statistics for "Members". For now we'll calculate simple overall averages for p1.
    final totalGames = _games.length;
    double avgRank = 0;
    int totalPt = 0;
    int tobiCount = 0;
    int topCount = 0;
    int rentaiCount = 0;

    for (var g in _games) {
      avgRank += g.ranks[0];
      totalPt += g.points[0];
      if (g.tobis[0]) tobiCount++;
      if (g.ranks[0] == 1) topCount++;
      if (g.ranks[0] <= 2) rentaiCount++;
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

  Widget _buildRankChart() {
    final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0};
    for (var g in _games) { counts[g.ranks[0]] = (counts[g.ranks[0]] ?? 0) + 1; }

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

  Widget _buildRevenueChart() {
    List<FlSpot> spots = [const FlSpot(0, 0)];
    int cumulative = 0;
    for (int i = 0; i < _games.length; i++) {
       // Reverse reverse chronological order for the chart (oldest to newest)
       cumulative += _games[_games.length - 1 - i].points[0];
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
}

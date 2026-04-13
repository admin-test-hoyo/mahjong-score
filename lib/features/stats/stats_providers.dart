import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_service.dart';
import '../../core/database/database_providers.dart';

final groupListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  return DatabaseService().getGroups();
});

final playerNamesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(databaseVersionProvider);
  return DatabaseService().getAllPlayerNames();
});

final groupRankingProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, groupId) async {
  ref.watch(databaseVersionProvider);
  return DatabaseService().getGroupRanking(groupId);
});

final allGamesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  return DatabaseService().getGames();
});

final allSessionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(databaseVersionProvider);
  return DatabaseService().getSessions();
});

/// 個人の統計データを取得するProvider (引数: プレイヤー名, グループID)
final recordStatsProvider = FutureProvider.family<Map<String, dynamic>, ({String playerName, int? groupId})>((ref, arg) async {
  ref.watch(databaseVersionProvider);
  return DatabaseService().getUserStats(arg.playerName, groupId: arg.groupId);
});
class RankingSort {
  final int columnIndex;
  final bool ascending;
  RankingSort({required this.columnIndex, required this.ascending});
}

class RankingSortNotifier extends Notifier<RankingSort> {
  @override
  RankingSort build() => RankingSort(columnIndex: 2, ascending: false);
  void updateSort(int index, bool asc) => state = RankingSort(columnIndex: index, ascending: asc);
}

/// グループランキングのソート状態を管理するProvider
final rankingSortProvider = NotifierProvider<RankingSortNotifier, RankingSort>(RankingSortNotifier.new);

/// ソート済みのグループ構成ランキングを取得するProvider
final sortedGroupRankingProvider = Provider.family<AsyncValue<List<Map<String, dynamic>>>, int>((ref, groupId) {
  final rankingAsync = ref.watch(groupRankingProvider(groupId));
  final sort = ref.watch(rankingSortProvider);

  return rankingAsync.whenData((data) {
    if (data.isEmpty) return [];
    
    final keys = [
      'name', 'matches', 'totalPt', 'totalChip', 'totalScore',
      'avgRank', 'games', 'topRate', 'rentaiRate', 'tobiRate',
    ];
    final key = sort.columnIndex < keys.length ? keys[sort.columnIndex] : 'totalPt';
    
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
        return sort.ascending ? cmp : -cmp;
      });
    return sorted;
  });
});

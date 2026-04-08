import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_service.dart';

final groupListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseService().getGroups();
});

final playerNamesProvider = FutureProvider<List<String>>((ref) async {
  return DatabaseService().getAllPlayerNames();
});

final groupRankingProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, groupId) async {
  return DatabaseService().getGroupRanking(groupId);
});

final allGamesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseService().getGames();
});

final allSessionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseService().getSessions();
});

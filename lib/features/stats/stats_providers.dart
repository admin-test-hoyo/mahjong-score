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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/db_models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      if (!kIsWeb) {
        _database = await _initDatabase();
        await _migrateToHeaderDetail(_database!);
        await forceSyncSessionTotals(); // 指示：不整合データの一括修正
      } else {
        await forceSyncSessionTotals(); // Web版対応
      }
      return _database!;
    } catch (e) {
      print('Database initialization error: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) return Future.error("sqflite is not supported on web");
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mahjong_stats.db');

    return await openDatabase(
      path,
      version: 4, // Ver 1.9.2: スナップショット強化
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
        if (oldVersion < 3) await _upgradeToV3(db);
        if (oldVersion < 4) await _upgradeToV4(db);
      },
    );
  }

  Future<void> _upgradeToV2(Database db) async {
    try {
      await db.execute('ALTER TABLE games ADD COLUMN session_id INTEGER');
    } catch (e) {
      print('Column already exists or error: $e');
    }
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        group_id INTEGER,
        p1_name TEXT, p2_name TEXT, p3_name TEXT, p4_name TEXT,
        config_json TEXT,
        p1_money INTEGER, p2_money INTEGER, p3_money INTEGER, p4_money INTEGER
      )
    ''');
  }

  Future<void> _upgradeToV3(Database db) async {
    try {
      await db.execute('ALTER TABLE sessions ADD COLUMN config_json TEXT');
      await db.execute('ALTER TABLE sessions ADD COLUMN p1_money INTEGER');
      await db.execute('ALTER TABLE sessions ADD COLUMN p2_money INTEGER');
      await db.execute('ALTER TABLE sessions ADD COLUMN p3_money INTEGER');
      await db.execute('ALTER TABLE sessions ADD COLUMN p4_money INTEGER');
    } catch (e) {
      print('Columns already exist or error: $e');
    }

    final sessions = await db.query('sessions');
    for (var s in sessions) {
      final sid = s['id'];
      final games = await db.query('games', where: 'session_id = ?', whereArgs: [sid]);
      if (games.isEmpty) continue;

      final List<int> sums = [0, 0, 0, 0];
      for (var g in games) {
        sums[0] += (g['p1_money'] as num?)?.toInt() ?? 0;
        sums[1] += (g['p2_money'] as num?)?.toInt() ?? 0;
        sums[2] += (g['p3_money'] as num?)?.toInt() ?? 0;
        sums[3] += (g['p4_money'] as num?)?.toInt() ?? 0;
      }

      await db.update('sessions', {
        'p1_money': sums[0], 'p2_money': sums[1], 'p3_money': sums[2], 'p4_money': sums[3],
      }, where: 'id = ?', whereArgs: [sid]);
    }
  }

  Future<void> _upgradeToV4(Database db) async {
    try {
      await db.execute('ALTER TABLE sessions ADD COLUMN global_chips_json TEXT');
      await db.execute('ALTER TABLE games ADD COLUMN p1_blown_by INTEGER');
      await db.execute('ALTER TABLE games ADD COLUMN p2_blown_by INTEGER');
      await db.execute('ALTER TABLE games ADD COLUMN p3_blown_by INTEGER');
      await db.execute('ALTER TABLE games ADD COLUMN p4_blown_by INTEGER');
    } catch (e) {
      print('Columns already exist or error: $e');
    }
  }

  Future<void> forceSyncSessionTotals() async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final games = await _webQuery('web_db_games');
      
      bool changed = false;
      for (var s in sessions) {
        final sid = s['id'];
        final sGames = games.where((g) => g['session_id'] == sid).toList();
        if (sGames.isEmpty) continue;

        final List<int> sums = [0, 0, 0, 0];
        for (var g in sGames) {
          sums[0] += (g['p1_money'] as num?)?.toInt() ?? 0;
          sums[1] += (g['p2_money'] as num?)?.toInt() ?? 0;
          sums[2] += (g['p3_money'] as num?)?.toInt() ?? 0;
          sums[3] += (g['p4_money'] as num?)?.toInt() ?? 0;
        }

        if (s['p1_money'] != sums[0] || s['p2_money'] != sums[1] || s['p3_money'] != sums[2] || s['p4_money'] != sums[3]) {
          s['p1_money'] = sums[0];
          s['p2_money'] = sums[1];
          s['p3_money'] = sums[2];
          s['p4_money'] = sums[3];
          changed = true;
        }
      }
      
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('web_db_sessions', jsonEncode(sessions));
      }
    } else {
      final db = await database;
      final sessions = await db.query('sessions');
      for (var s in sessions) {
        final sid = s['id'];
        final games = await db.query('games', where: 'session_id = ?', whereArgs: [sid]);
        if (games.isEmpty) continue;

        final List<int> sums = [0, 0, 0, 0];
        for (var g in games) {
          sums[0] += (g['p1_money'] as num?)?.toInt() ?? 0;
          sums[1] += (g['p2_money'] as num?)?.toInt() ?? 0;
          sums[2] += (g['p3_money'] as num?)?.toInt() ?? 0;
          sums[3] += (g['p4_money'] as num?)?.toInt() ?? 0;
        }

        await db.update('sessions', {
          'p1_money': sums[0], 'p2_money': sums[1], 'p3_money': sums[2], 'p4_money': sums[3],
        }, where: 'id = ?', whereArgs: [sid]);
      }
    }
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        group_id INTEGER,
        p1_name TEXT, p2_name TEXT, p3_name TEXT, p4_name TEXT,
        config_json TEXT,
        global_chips_json TEXT,
        p1_money INTEGER, p2_money INTEGER, p3_money INTEGER, p4_money INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        group_id INTEGER,
        p1_name TEXT, p2_name TEXT, p3_name TEXT, p4_name TEXT,
        p1_score INTEGER, p2_score INTEGER, p3_score INTEGER, p4_score INTEGER,
        p1_ch INTEGER, p2_ch INTEGER, p3_ch INTEGER, p4_ch INTEGER,
        p1_tobi INTEGER, p2_tobi INTEGER, p3_tobi INTEGER, p4_tobi INTEGER,
        p1_pt INTEGER, p2_pt INTEGER, p3_pt INTEGER, p4_pt INTEGER,
        p1_rank INTEGER, p2_rank INTEGER, p3_rank INTEGER, p4_rank INTEGER,
        p1_money INTEGER, p2_money INTEGER, p3_money INTEGER, p4_money INTEGER,
        p1_blown_by INTEGER, p2_blown_by INTEGER, p3_blown_by INTEGER, p4_blown_by INTEGER,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateToHeaderDetail(dynamic dbSource) async {
    final isWeb = kIsWeb;
    final prefs = isWeb ? await SharedPreferences.getInstance() : null;
    
    if (isWeb) {
      if (prefs!.getBool('migration_v17_done') == true) {
        if (prefs.getBool('migration_v19_snapshot_done') != true) {
          final sessions = await _webQuery('web_db_sessions');
          final games = await _webQuery('web_db_games');
          bool changed = false;
          for (var s in sessions) {
            if (s['p1_money'] != null) continue;
            final sid = s['id'];
            final sGames = games.where((g) => g['session_id'] == sid);
            final List<int> sums = [0, 0, 0, 0];
            for (var g in sGames) {
              sums[0] += (g['p1_money'] as num?)?.toInt() ?? 0;
              sums[1] += (g['p2_money'] as num?)?.toInt() ?? 0;
              sums[2] += (g['p3_money'] as num?)?.toInt() ?? 0;
              sums[3] += (g['p4_money'] as num?)?.toInt() ?? 0;
            }
            s['p1_money'] = sums[0];
            s['p2_money'] = sums[1];
            s['p3_money'] = sums[2];
            s['p4_money'] = sums[3];
            changed = true;
          }
          if (changed) await prefs.setString('web_db_sessions', jsonEncode(sessions));
          await prefs.setBool('migration_v19_snapshot_done', true);
        }
        return;
      }
      final allGames = await _webQuery('web_db_games');
      if (allGames.isEmpty) {
        await prefs.setBool('migration_v17_done', true);
        return;
      }

      final sessions = <Map<String, dynamic>>[];
      int lastSessionId = 5000;
      for (var game in allGames) {
        if (game['session_id'] != null) continue;
        final dateStr = (game['date'] as String).substring(0, 10).replaceAll('-', '/');
        final names = [(game['p1_name'] ?? '').toString().trim(), (game['p2_name'] ?? '').toString().trim(), (game['p3_name'] ?? '').toString().trim(), (game['p4_name'] ?? '').toString().trim()]..sort();
        int? sid;
        for (var s in sessions) {
          final sNames = [s['p1_name'], s['p2_name'], s['p3_name'], s['p4_name']]..sort();
          if (s['date'] == dateStr && s['group_id'] == game['group_id'] && names.join(',') == sNames.join(',')) { sid = s['id']; break; }
        }
        if (sid == null) {
          lastSessionId++; sid = lastSessionId;
          final rawNames = [(game['p1_name'] ?? '').toString().trim(), (game['p2_name'] ?? '').toString().trim(), (game['p3_name'] ?? '').toString().trim(), (game['p4_name'] ?? '').toString().trim()];
          sessions.add({'id': sid, 'date': dateStr, 'group_id': game['group_id'], 'p1_name': rawNames[0], 'p2_name': rawNames[1], 'p3_name': rawNames[2], 'p4_name': rawNames[3]});
        }
        game['session_id'] = sid;
      }
      await prefs.setString('web_db_sessions', jsonEncode(sessions));
      await prefs.setString('web_db_games', jsonEncode(allGames));
      await prefs.setBool('migration_v17_done', true);
    } else {
      final db = dbSource as Database;
      final games = await db.query('games', where: 'session_id IS NULL');
      if (games.isEmpty) return;
      for (var game in games) {
        final dateStr = (game['date'] as String).substring(0, 10).replaceAll('-', '/');
        final names = [(game['p1_name'] ?? '').toString().trim(), (game['p2_name'] ?? '').toString().trim(), (game['p3_name'] ?? '').toString().trim(), (game['p4_name'] ?? '').toString().trim()]..sort();
        final sQuery = await db.query('sessions', where: 'date = ? AND group_id ${game['group_id'] == null ? 'IS NULL' : '= ?'}', whereArgs: [dateStr, if (game['group_id'] != null) game['group_id']]);
        int? sid;
        for (var s in sQuery) {
          final sNames = [s['p1_name'], s['p2_name'], s['p3_name'], s['p4_name']]..sort();
          if (names.join(',') == sNames.join(',')) { sid = s['id'] as int; break; }
        }
        if (sid == null) {
          final rawNames = [(game['p1_name'] ?? '').toString().trim(), (game['p2_name'] ?? '').toString().trim(), (game['p3_name'] ?? '').toString().trim(), (game['p4_name'] ?? '').toString().trim()];
          sid = await db.insert('sessions', {'date': dateStr, 'group_id': game['group_id'], 'p1_name': rawNames[0], 'p2_name': rawNames[1], 'p3_name': rawNames[2], 'p4_name': rawNames[3]});
        }
        await db.update('games', {'session_id': sid}, where: 'id = ?', whereArgs: [game['id']]);
      }
    }
  }

  // Basic CRUD for Games
  Future<int> insertGame(Map<String, dynamic> row) async {
    if (kIsWeb) return _webInsert('web_db_games', row);
    final db = await database;
    return await db.insert('games', row);
  }

  Future<int> upsertGame(Map<String, dynamic> row) async {
    if (kIsWeb) {
      if (row.containsKey('id') && row['id'] != null) return _webUpdate('web_db_games', row);
      return _webInsert('web_db_games', row);
    }
    final db = await database;
    if (row.containsKey('id') && row['id'] != null) {
      return await db.update('games', row, where: 'id = ?', whereArgs: [row['id']]);
    }
    return await db.insert('games', row);
  }

  Future<List<Map<String, dynamic>>> getGames({int? groupId}) async {
    if (kIsWeb) {
      final all = await _webQuery('web_db_games');
      var filtered = groupId != null ? all.where((e) => e['group_id'] == groupId).toList() : all;
      filtered.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return filtered;
    }
    final db = await database;
    String? where; List<dynamic>? whereArgs;
    if (groupId != null) { where = 'group_id = ?'; whereArgs = [groupId]; }
    return await db.query('games', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
  }

  Future<int> deleteGame(int id) async {
    if (kIsWeb) return _webDelete('web_db_games', id);
    final db = await database;
    return await db.delete('games', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGamesBySessionId(int sessionId) async {
    if (kIsWeb) {
      final games = await _webQuery('web_db_games');
      final newGames = games.where((g) => g['session_id'] != sessionId).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_db_games', jsonEncode(newGames));
      return 1;
    }
    final db = await database;
    return await db.delete('games', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> updateGameGroupIdToNull(int groupId) async {
    if (kIsWeb) {
      final games = await _webQuery('web_db_games');
      final sessions = await _webQuery('web_db_sessions');
      bool changed = false;
      for (var g in games) { if (g['group_id'] == groupId) { g['group_id'] = null; changed = true; } }
      for (var s in sessions) { if (s['group_id'] == groupId) { s['group_id'] = null; changed = true; } }
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('web_db_games', jsonEncode(games));
        await prefs.setString('web_db_sessions', jsonEncode(sessions));
      }
    } else {
      final db = await database;
      await db.update('games', {'group_id': null}, where: 'group_id = ?', whereArgs: [groupId]);
      await db.update('sessions', {'group_id': null}, where: 'group_id = ?', whereArgs: [groupId]);
    }
  }

  // Session Management
  Future<List<Map<String, dynamic>>> getSessions() async {
    if (kIsWeb) return _webQuery('web_db_sessions');
    final db = await database;
    return await db.query('sessions', orderBy: 'date DESC');
  }

  Future<int> findOrCreateSession({
    required String date,
    required List<String> playerNames,
    int? groupId,
    String? configJson,
    String? globalChipsJson,
    List<int>? totalMoneys,
  }) async {
    final names = List<String>.from(playerNames.map((e) => e.trim()))..sort();
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      for (var s in sessions) {
        final sNames = [(s['p1_name']??''), (s['p2_name']??''), (s['p3_name']??''), (s['p4_name']??'')]..sort();
        if (s['date'] == date && s['group_id'] == groupId && names.join(',') == sNames.join(',')) return s['id'] as int;
      }
      return _webInsert('web_db_sessions', {
        'date': date, 'group_id': groupId, 'p1_name': playerNames[0], 'p2_name': playerNames[1], 'p3_name': playerNames[2], 'p4_name': playerNames.length > 3 ? playerNames[3] : '',
        'config_json': configJson, 'global_chips_json': globalChipsJson,
        'p1_money': totalMoneys != null && totalMoneys.length > 0 ? totalMoneys[0] : 0,
        'p2_money': totalMoneys != null && totalMoneys.length > 1 ? totalMoneys[1] : 0,
        'p3_money': totalMoneys != null && totalMoneys.length > 2 ? totalMoneys[2] : 0,
        'p4_money': totalMoneys != null && totalMoneys.length > 3 ? totalMoneys[3] : 0,
      });
    }
    final db = await database;
    final results = await db.query('sessions', where: 'date = ? AND group_id ${groupId == null ? 'IS NULL' : '= ?'}', whereArgs: [date, if (groupId != null) groupId]);
    for (var s in results) {
      final sNames = [(s['p1_name']??''), (s['p2_name']??''), (s['p3_name']??''), (s['p4_name']??'')]..sort();
      if (names.join(',') == sNames.join(',')) return s['id'] as int;
    }
    return await db.insert('sessions', {
      'date': date, 'group_id': groupId, 'p1_name': playerNames[0], 'p2_name': playerNames[1], 'p3_name': playerNames[2], 'p4_name': playerNames.length > 3 ? playerNames[3] : '',
      'config_json': configJson, 'global_chips_json': globalChipsJson,
      'p1_money': totalMoneys != null && totalMoneys.length > 0 ? totalMoneys[0] : 0,
      'p2_money': totalMoneys != null && totalMoneys.length > 1 ? totalMoneys[1] : 0,
      'p3_money': totalMoneys != null && totalMoneys.length > 2 ? totalMoneys[2] : 0,
      'p4_money': totalMoneys != null && totalMoneys.length > 3 ? totalMoneys[3] : 0,
    });
  }

  Future<int> updateSession(Session session) async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final idx = sessions.indexWhere((s) => s['id'] == session.id);
      if (idx != -1) {
        sessions[idx]['group_id'] = session.groupId;
        sessions[idx]['config_json'] = session.configJson;
        sessions[idx]['global_chips_json'] = session.globalChipsJson;
        sessions[idx]['p1_money'] = session.totalMoneys?[0] ?? 0;
        sessions[idx]['p2_money'] = session.totalMoneys?[1] ?? 0;
        sessions[idx]['p3_money'] = session.totalMoneys?[2] ?? 0;
        sessions[idx]['p4_money'] = (session.totalMoneys != null && session.totalMoneys!.length > 3) ? session.totalMoneys![3] : 0;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('web_db_sessions', jsonEncode(sessions));
        return 1;
      }
      return 0;
    }
    final db = await database;
    return await db.update('sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> updateSessionGroupId(int sessionId, int? groupId) async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final games = await _webQuery('web_db_games');
      final idx = sessions.indexWhere((e) => e['id'] == sessionId);
      if (idx != -1) {
        sessions[idx]['group_id'] = groupId;
        for (var g in games) { if (g['session_id'] == sessionId) g['group_id'] = groupId; }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('web_db_sessions', jsonEncode(sessions));
        await prefs.setString('web_db_games', jsonEncode(games));
      }
    } else {
      final db = await database;
      await db.update('sessions', {'group_id': groupId}, where: 'id = ?', whereArgs: [sessionId]);
      await db.update('games', {'group_id': groupId}, where: 'session_id = ?', whereArgs: [sessionId]);
    }
  }

  Future<void> deleteHistoryBefore(String dateStr) async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final games = await _webQuery('web_db_games');
      final toDelete = sessions.where((s) => (s['date'] as String).compareTo(dateStr) < 0).map((s) => s['id']).toSet();
      final newSessions = sessions.where((s) => !toDelete.contains(s['id'])).toList();
      final newGames = games.where((g) => !toDelete.contains(g['session_id'])).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_db_sessions', jsonEncode(newSessions));
      await prefs.setString('web_db_games', jsonEncode(newGames));
    } else {
      final db = await database;
      await db.transaction((txn) async {
        final sessions = await txn.query('sessions', columns: ['id'], where: 'date < ?', whereArgs: [dateStr]);
        final ids = sessions.map((s) => s['id']).toList();
        if (ids.isNotEmpty) {
          final idList = ids.join(',');
          await txn.delete('games', where: 'session_id IN ($idList)');
          await txn.delete('sessions', where: 'id IN ($idList)');
        }
      });
    }
  }

  Future<void> deleteAllHistory() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_db_sessions');
      await prefs.remove('web_db_games');
    } else {
      final db = await database;
      await db.transaction((txn) async { await txn.delete('games'); await txn.delete('sessions'); });
    }
  }

  // Groups and Members
  Future<int> insertGroup(String name) async {
    if (kIsWeb) return _webInsert('web_db_groups', {'name': name});
    final db = await database;
    return await db.insert('groups', {'name': name});
  }

  Future<List<Map<String, dynamic>>> getGroups() async {
    if (kIsWeb) return _webQuery('web_db_groups');
    final db = await database;
    return await db.query('groups');
  }

  Future<int> updateGroupName(int id, String newName) async {
    if (kIsWeb) return _webUpdate('web_db_groups', {'id': id, 'name': newName});
    final db = await database;
    return await db.update('groups', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGroup(int id) async {
    await updateGameGroupIdToNull(id);
    if (kIsWeb) return _webDelete('web_db_groups', id);
    final db = await database;
    return await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getGroupRanking(int groupId) async {
    final memberRows = await getMembers(groupId);
    final memberNames = memberRows.map((e) => e['name'] as String).toList();
    if (memberNames.isEmpty) return [];
    final memberNameSet = memberNames.toSet();

    List<Map<String, dynamic>> allRows = kIsWeb ? await _webQuery('web_db_games') : await (await database).query('games');
    final Map<String, Map<String, dynamic>> stats = { for (var name in memberNames) name: {
      'name': name, 'games': 0, 'totalPt': 0, 'totalChip': 0, 'rankSum': 0, 'topCount': 0, 'rentaiCount': 0, 'tobiCount': 0, 'totalMoney': 0, 'session_dates': <String>{},
    } };

    final sRows = kIsWeb ? await _webQuery('web_db_sessions') : await (await database).query('sessions');
    for (final s in sRows) {
      final names = [(s['p1_name']??''), (s['p2_name']??''), (s['p3_name']??''), (s['p4_name']??'')];
      final dateStr = (s['date'] as String?) ?? '';
      String day = dateStr.length >= 10 ? dateStr.substring(0, 10).replaceAll('-', '/') : dateStr;
      for (int i=0; i<4; i++) {
        final name = names[i].trim();
        if (name.isEmpty || !memberNameSet.contains(name)) continue;
        final stat = stats[name]!;
        stat['totalMoney'] = (stat['totalMoney'] as int) + ((s['p${i+1}_money'] as num?)?.toInt() ?? 0);
        if (day.isNotEmpty) (stat['session_dates'] as Set<String>).add(day);
      }
    }

    for (final row in allRows) {
      for (int i=1; i<=4; i++) {
        final name = (row['p$i\_name'] ?? '').toString().trim();
        if (name.isEmpty || !memberNameSet.contains(name)) continue;
        final s = stats[name]!;
        s['games'] = (s['games'] as int) + 1;
        s['totalPt'] = (s['totalPt'] as int) + ((row['p$i\_pt'] as num?)?.toInt() ?? 0);
        s['totalChip'] = (s['totalChip'] as int) + ((row['p$i\_ch'] as num?)?.toInt() ?? 0);
        final rank = (row['p$i\_rank'] as num?)?.toInt() ?? 1;
        s['rankSum'] = (s['rankSum'] as int) + rank;
        if (((row['p$i\_score'] as num?)?.toInt() ?? 0) < 0) s['tobiCount'] = (s['tobiCount'] as int) + 1;
        if (rank == 1) s['topCount'] = (s['topCount'] as int) + 1;
        if (rank <= 2) s['rentaiCount'] = (s['rentaiCount'] as int) + 1;
      }
    }

    return stats.values.map((s) {
      final games = s['games'] as int;
      return {
        'name': s['name'], 'games': games, 'matches': (s['session_dates'] as Set<String>).length,
        'totalPt': s['totalPt'], 'totalChip': s['totalChip'], 'totalScore': s['totalMoney'],
        'avgRank': games > 0 ? (s['rankSum'] as int) / games : 0.0,
        'topRate': games > 0 ? (s['topCount'] as int) / games * 100 : 0.0,
        'rentaiRate': games > 0 ? (s['rentaiCount'] as int) / games * 100 : 0.0,
        'tobiRate': games > 0 ? (s['tobiCount'] as int) / games * 100 : 0.0,
      };
    }).toList();
  }

  Future<int> insertMember(int groupId, String name) async {
    if (kIsWeb) return _webInsert('web_db_group_members', {'group_id': groupId, 'name': name});
    final db = await database;
    return await db.insert('group_members', {'group_id': groupId, 'name': name});
  }

  Future<List<Map<String, dynamic>>> getMembers(int groupId) async {
    if (kIsWeb) {
      final all = await _webQuery('web_db_group_members');
      return all.where((e) => e['group_id'] == groupId).toList();
    }
    final db = await database;
    return await db.query('group_members', where: 'group_id = ?', whereArgs: [groupId]);
  }

  Future<int> deleteMember(int id) async {
    if (kIsWeb) return _webDelete('web_db_group_members', id);
    final db = await database;
    return await db.delete('group_members', where: 'id = ?', whereArgs: [id]);
  }

  // Web Helpers
  Future<int> _webInsert(String key, Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    int lastId = prefs.getInt('web_db_last_id') ?? 1000;
    lastId++;
    await prefs.setInt('web_db_last_id', lastId);
    final newRow = Map<String, dynamic>.from(row);
    newRow['id'] = lastId; items.add(newRow);
    await prefs.setString(key, jsonEncode(items));
    return lastId;
  }

  Future<int> _webUpdate(String key, Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    final index = items.indexWhere((e) => e['id'] == row['id']);
    if (index != -1) { items[index] = row; await prefs.setString(key, jsonEncode(items)); return 1; }
    return 0;
  }

  Future<List<Map<String, dynamic>>> _webQuery(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }

  Future<int> _webDelete(String key, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    final index = items.indexWhere((e) => e['id'] == id);
    if (index != -1) { items.removeAt(index); await prefs.setString(key, jsonEncode(items)); return 1; }
    return 0;
  }
}

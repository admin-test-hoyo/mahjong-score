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
        await forceSyncSessionTotals();
      } else {
        await forceSyncSessionTotals(); 
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
      version: 6, 
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
        if (oldVersion < 3) await _upgradeToV3(db);
        if (oldVersion < 4) await _upgradeToV4(db);
        if (oldVersion < 5) await _upgradeToV5(db);
        if (oldVersion < 6) await _upgradeToV6(db);
      },
    );
  }

  Future<void> _upgradeToV6(Database db) async {
    try {
      await db.execute('ALTER TABLE games ADD COLUMN oya_index INTEGER DEFAULT 0');
    } catch (_) {}
  }

  Future<void> _upgradeToV2(Database db) async {
    try { await db.execute('ALTER TABLE games ADD COLUMN session_id INTEGER'); } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> _upgradeToV4(Database db) async {
    try {
      await db.execute('ALTER TABLE sessions ADD COLUMN global_chips_json TEXT');
      await db.execute('ALTER TABLE games ADD COLUMN p1_blown_by INTEGER');
      await db.execute('ALTER TABLE games ADD COLUMN p2_blown_by INTEGER');
      await db.execute('ALTER TABLE games ADD COLUMN p3_blown_by INTEGER');
      await db.execute('ALTER TABLE games ADD COLUMN p4_blown_by INTEGER');
    } catch (_) {}
  }

  Future<void> _upgradeToV5(Database db) async {
    try {
      await db.execute('ALTER TABLE games ADD COLUMN p1_yakuman INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE games ADD COLUMN p2_yakuman INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE games ADD COLUMN p3_yakuman INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE games ADD COLUMN p4_yakuman INTEGER DEFAULT 0');
    } catch (_) {}
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
        p1_yakuman INTEGER, p2_yakuman INTEGER, p3_yakuman INTEGER, p4_yakuman INTEGER,
        oya_index INTEGER,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE TABLE groups (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)');
    await db.execute('CREATE TABLE group_members (id INTEGER PRIMARY KEY AUTOINCREMENT, group_id INTEGER NOT NULL, name TEXT NOT NULL, FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE)');
  }

  Future<void> forceSyncSessionTotals() async {
    await recalculateAllSessionTotals();
  }

  Future<void> recalculateAllSessionTotals() async {
    // 厳守：収支 = (Pt * Rate) + (Chip * ChipRate)
    // 場代込 = 収支 - (Fee / 4)
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final games = await _webQuery('web_db_games');
      bool changed = false;
      for (var s in sessions) {
        final sid = s['id'];
        final sGames = games.where((g) => g['session_id'] == sid);
        final configJson = s['config_json'] as String?;
        int fee = 0; double rate = 0; int chipRate = 0;
        if (configJson != null) {
          final config = jsonDecode(configJson);
          fee = (config['gameFee'] as num?)?.toInt() ?? 0;
          rate = (config['rate'] as num?)?.toDouble() ?? 0;
          chipRate = (config['chipRate'] as num?)?.toInt() ?? 0;
        }

        final List<int> ptSums = [0, 0, 0, 0];
        final List<int> chipSums = [0, 0, 0, 0];
        for (var g in sGames) {
          for (int i=1; i<=4; i++) {
            ptSums[i-1] += (g['p${i}_pt'] as num?)?.toInt() ?? 0;
            chipSums[i-1] += (g['p${i}_ch'] as num?)?.toInt() ?? 0;
          }
        }
        for (int i=0; i<4; i++) {
          final income = (ptSums[i] * rate) + (chipSums[i] * chipRate);
          s['p${i+1}_money'] = (income - (fee / 4.0)).round();
        }
        changed = true;
      }
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('web_db_sessions', jsonEncode(sessions));
      }
      return;
    }
    final db = await database;
    final sessions = await db.query('sessions');
    for (var s in sessions) {
      final sid = s['id'];
      final games = await db.query('games', where: 'session_id = ?', whereArgs: [sid]);
      final configJson = s['config_json'] as String?;
      int fee = 0; double rate = 0; int chipRate = 0;
      if (configJson != null) {
        final config = jsonDecode(configJson);
        fee = (config['gameFee'] as num?)?.toInt() ?? 0;
        rate = (config['rate'] as num?)?.toDouble() ?? 0.0;
        chipRate = (config['chipRate'] as num?)?.toInt() ?? 0;
      }

      final List<int> ptSums = [0, 0, 0, 0];
      final List<int> chipSums = [0, 0, 0, 0];
      for (var g in games) {
        for (int i=1; i<=4; i++) {
          ptSums[i-1] += (g['p${i}_pt'] as num?)?.toInt() ?? 0;
          chipSums[i-1] += (g['p${i}_ch'] as num?)?.toInt() ?? 0;
        }
      }
      
      final Map<String, dynamic> updates = {};
      for (int i=0; i<4; i++) {
        final income = (ptSums[i] * rate) + (chipSums[i] * chipRate);
        updates['p${i+1}_money'] = (income - (fee / 4.0)).round();
      }
      await db.update('sessions', updates, where: 'id = ?', whereArgs: [sid]);
    }
  }

  Future<void> _migrateToHeaderDetail(Database db) async {
    final games = await db.query('games', where: 'session_id IS NULL');
    if (games.isEmpty) return;
    for (var game in games) {
      final dateStr = (game['date'] as String).substring(0, 10).replaceAll('-', '/');
      final rawNames = [(game['p1_name']??'').toString().trim(), (game['p2_name']??'').toString().trim(), (game['p3_name']??'').toString().trim(), (game['p4_name']??'').toString().trim()];
      final names = List<String>.from(rawNames)..sort();
      final sQuery = await db.query('sessions', where: 'date = ? AND group_id ${game['group_id'] == null ? 'IS NULL' : '= ?'}', whereArgs: [dateStr, if (game['group_id'] != null) game['group_id']]);
      int? sid;
      for (var s in sQuery) {
        final sNames = [s['p1_name'], s['p2_name'], s['p3_name'], s['p4_name']]..sort();
        if (names.join(',') == sNames.join(',')) { sid = s['id'] as int; break; }
      }
      if (sid == null) {
        sid = await db.insert('sessions', {'date': dateStr, 'group_id': game['group_id'], 'p1_name': rawNames[0], 'p2_name': rawNames[1], 'p3_name': rawNames[2], 'p4_name': rawNames[3]});
      }
      await db.update('games', {'session_id': sid}, where: 'id = ?', whereArgs: [game['id']]);
    }
  }

  // Games
  Future<int> insertGame(Map<String, dynamic> row) async {
    if (kIsWeb) return _webInsert('web_db_games', row);
    final db = await database;
    return await db.insert('games', row);
  }

  Future<List<Map<String, dynamic>>> getGames({int? groupId}) async {
    if (kIsWeb) {
      final all = await _webQuery('web_db_games');
      var filtered = groupId != null 
          ? all.where((e) => (e['group_id'] as num?)?.toInt() == groupId).toList() 
          : all.where((e) => e['group_id'] == null).toList();
      filtered.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String)); // 時系列昇順にソート（グラフ用）
      return filtered;
    }
    final db = await database;
    String? where; List<dynamic>? whereArgs;
    if (groupId != null) { where = 'group_id = ?'; whereArgs = [groupId]; }
    return await db.query('games', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
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

  Future<int> deleteGame(int id) async {
    if (kIsWeb) return _webDelete('web_db_games', id);
    final db = await database;
    return await db.delete('games', where: 'id = ?', whereArgs: [id]);
  }

  // Sessions
  Future<int> findOrCreateSession({required String date, required List<String> playerNames, int? groupId, String? configJson, String? globalChipsJson, List<int>? totalMoneys}) async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      for (var s in sessions) {
        if (s['date'] == date && s['p1_name'] == playerNames[0] && s['p2_name'] == playerNames[1] && s['p3_name'] == playerNames[2] && s['group_id'] == groupId) {
          return s['id'];
        }
      }
      return _webInsert('web_db_sessions', Session(date: date, playerNames: playerNames, groupId: groupId, configJson: configJson, globalChipsJson: globalChipsJson, totalMoneys: totalMoneys).toMap());
    }
    final db = await database;
    final results = await db.query('sessions', where: 'date = ? AND p1_name = ? AND p2_name = ? AND p3_name = ? AND group_id ${groupId == null ? "IS NULL" : "= ?"}',
        whereArgs: [date, playerNames[0], playerNames[1], playerNames[2], if (groupId != null) groupId]);
    if (results.isNotEmpty) return results.first['id'] as int;
    return await db.insert('sessions', Session(date: date, playerNames: playerNames, groupId: groupId, configJson: configJson, globalChipsJson: globalChipsJson, totalMoneys: totalMoneys).toMap());
  }

  Future<void> updateSession(Session session) async {
    if (kIsWeb) { await _webUpdate('web_db_sessions', session.toMap()); return; }
    final db = await database;
    await db.update('sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> updateSessionGroupId(int sessionId, int? groupId) async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final index = sessions.indexWhere((s) => s['id'] == sessionId);
      if (index != -1) { sessions[index]['group_id'] = groupId; await (await SharedPreferences.getInstance()).setString('web_db_sessions', jsonEncode(sessions)); }
      return;
    }
    final db = await database;
    await db.update('sessions', {'group_id': groupId}, where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<List<Map<String, dynamic>>> getSessions({int? groupId}) async {
    if (kIsWeb) {
      final list = await _webQuery('web_db_sessions');
      var filtered = groupId != null 
          ? list.where((s) => (s['group_id'] as num?)?.toInt() == groupId).toList() 
          : list.where((s) => s['group_id'] == null).toList();
      filtered.sort((a,b) => (b['date'] as String).compareTo(a['date'] as String));
      return filtered;
    }
    final db = await database;
    String? where; List<dynamic>? whereArgs;
    if (groupId != null) { where = 'group_id = ?'; whereArgs = [groupId]; }
    return await db.query('sessions', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
  }

  // Groups
  Future<Session?> getSessionById(int id) async {
    if (kIsWeb) {
      final rows = await _webQuery('web_db_sessions');
      final map = rows.firstWhere((e) => e['id'] == id, orElse: () => {});
      if (map.isEmpty) return null;
      return Session.fromMap(map);
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<List<Map<String, dynamic>>> getGroups() async {
    if (kIsWeb) return _webQuery('web_db_groups');
    final db = await database;
    return await db.query('groups');
  }

  Future<int> insertGroup(String name) async {
    if (kIsWeb) return _webInsert('web_db_groups', {'name': name});
    final db = await database;
    return await db.insert('groups', {'name': name});
  }

  Future<void> updateGroupName(int id, String name) async {
    if (kIsWeb) { await _webUpdate('web_db_groups', {'id': id, 'name': name}); return; }
    final db = await database;
    await db.update('groups', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGroup(int id) async {
    if (kIsWeb) { await _webDelete('web_db_groups', id); return; }
    final db = await database;
    await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // Members
  Future<List<Map<String, dynamic>>> getMembers(int groupId) async {
    if (kIsWeb) {
      final all = await _webQuery('web_db_members');
      return all.where((m) => m['group_id'] == groupId).toList();
    }
    final db = await database;
    return await db.query('group_members', where: 'group_id = ?', whereArgs: [groupId]);
  }

  Future<void> addMember(int groupId, String name) async {
    if (kIsWeb) { await _webInsert('web_db_members', {'group_id': groupId, 'name': name}); return; }
    final db = await database;
    await db.insert('group_members', {'group_id': groupId, 'name': name});
  }

  Future<void> insertMember(int groupId, String name) => addMember(groupId, name);

  Future<void> deleteMember(int id) async {
    if (kIsWeb) { await _webDelete('web_db_members', id); return; }
    final db = await database;
    await db.delete('group_members', where: 'group_id = ?', whereArgs: [id]);
  }

  // History Cleanup
  Future<void> deleteAllHistory() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_db_sessions');
      await prefs.remove('web_db_games');
      return;
    }
    final db = await database;
    await db.transaction((txn) async { await txn.delete('games'); await txn.delete('sessions'); });
  }

  Future<void> deleteHistoryBefore(String date) async {
    if (date.isEmpty) return; 
    if (kIsWeb) {
       final sessions = await _webQuery('web_db_sessions');
       final newSessions = sessions.where((s) => (s['date'] as String).compareTo(date) >= 0).toList();
       final sIds = newSessions.map((e) => e['id']).toSet();
       final games = await _webQuery('web_db_games');
       final newGames = games.where((g) => sIds.contains(g['session_id'])).toList();
       final prefs = await SharedPreferences.getInstance();
       await prefs.setString('web_db_sessions', jsonEncode(newSessions));
       await prefs.setString('web_db_games', jsonEncode(newGames));
       return;
    }
    final db = await database;
    await db.transaction((txn) async {
      final sIds = (await txn.query('sessions', columns: ['id'], where: 'date < ?', whereArgs: [date])).map((e) => e['id']);
      for (var sid in sIds) { await txn.delete('games', where: 'session_id = ?', whereArgs: [sid]); }
      await txn.delete('sessions', where: 'date < ?', whereArgs: [date]);
    });
  }

  Future<void> deleteSession(int sessionId) async {
    if (kIsWeb) {
      final sessions = await _webQuery('web_db_sessions');
      final newSessions = sessions.where((s) => s['id'] != sessionId).toList();
      final games = await _webQuery('web_db_games');
      final newGames = games.where((g) => g['session_id'] != sessionId).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_db_sessions', jsonEncode(newSessions));
      await prefs.setString('web_db_games', jsonEncode(newGames));
      return;
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('games', where: 'session_id = ?', whereArgs: [sessionId]);
      await txn.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    });
  }

  // Statistics
  Future<List<String>> getAllPlayerNames() async {
    if (kIsWeb) {
      final games = await _webQuery('web_db_games');
      final names = <String>{};
      for (var g in games) {
        for (int i=1; i<=4; i++) {
          final n = (g['p$i\_name'] ?? '').toString().trim();
          if (n.isNotEmpty) names.add(n);
        }
      }
      return names.toList()..sort();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT p1_name as name FROM games WHERE p1_name != ''
      UNION SELECT DISTINCT p2_name as name FROM games WHERE p2_name != ''
      UNION SELECT DISTINCT p3_name as name FROM games WHERE p3_name != ''
      UNION SELECT DISTINCT p4_name as name FROM games WHERE p4_name != ''
      ORDER BY name
    ''');
    return maps.map((e) => e['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupRanking(int groupId) async {
    final memberRows = await getMembers(groupId);
    final memberNames = memberRows.map((e) => e['name'] as String).toList();
    if (memberNames.isEmpty) return [];
    final memberNameSet = memberNames.toSet();

    List<Map<String, dynamic>> allRows = kIsWeb ? await _webQuery('web_db_games') : await (await database).query('games', where: 'group_id = ?', whereArgs: [groupId]);
    if (kIsWeb) {
      allRows = allRows.where((e) => e['group_id'] == groupId).toList();
    }
    
    final Map<String, Map<String, dynamic>> stats = { for (var name in memberNames) name: {
      'name': name, 'games': 0, 'totalPt': 0, 'totalChip': 0, 'rankSum': 0, 'topCount': 0, 'rentaiCount': 0, 'tobiCount': 0, 'totalMoney': 0, 'session_dates': <String>{},
    } };

    List<Map<String, dynamic>> sRows = kIsWeb ? await _webQuery('web_db_sessions') : await (await database).query('sessions', where: 'group_id = ?', whereArgs: [groupId]);
    if (kIsWeb) {
      sRows = sRows.where((e) => e['group_id'] == groupId).toList();
    }
    final sessionIds = sRows.map((s) => s['id'] as int).toSet();

    for (final s in sRows) {
      final names = [(s['p1_name']??''), (s['p2_name']??''), (s['p3_name']??''), (s['p4_name']??'')];
      final dateStr = (s['date'] as String?) ?? '';
      String day = dateStr.length >= 10 ? dateStr.substring(0, 10).replaceAll('-', '/') : dateStr;

      List<int> globalChips = [0, 0, 0, 0];
      if (s['global_chips_json'] != null) {
        try { globalChips = (jsonDecode(s['global_chips_json'] as String) as List).cast<int>(); } catch(_) {}
      }

      for (int i=0; i<4; i++) {
        final name = (names[i] as String? ?? '').trim();
        if (name.isEmpty || !memberNameSet.contains(name)) continue;
        final stat = stats[name]!;
        stat['totalMoney'] = (stat['totalMoney'] as int) + ((s['p${i+1}_money'] as num?)?.toInt() ?? 0);
        if (i < globalChips.length) {
           stat['totalChip'] = (stat['totalChip'] as int) + globalChips[i];
        }
        if (day.isNotEmpty) (stat['session_dates'] as Set<String>).add(day);
      }
    }

    for (final row in allRows) {
      if (row['group_id'] != groupId && !sessionIds.contains(row['session_id'])) continue;

      for (int i=1; i<=4; i++) {
        final name = (row['p$i\_name'] ?? '').toString().trim();
        if (name.isEmpty || !memberNameSet.contains(name)) continue;
        final s = stats[name]!;
        s['games'] = (s['games'] as int) + 1;
        s['totalPt'] = (s['totalPt'] as int) + ((row['p$i\_pt'] as num?)?.toInt() ?? 0);
        s['totalChip'] = (s['totalChip'] as int) + ((row['p$i\_ch'] as num?)?.toInt() ?? 0);
        final rank = (row['p$i\_rank'] as num?)?.toInt() ?? 1;
        s['rankSum'] = (s['rankSum'] as int) + rank;
        if (rank == 1) s['topCount'] = (s['topCount'] as int) + 1;
        if (rank <= 2) s['rentaiCount'] = (s['rentaiCount'] as int) + 1;
        if (((row['p$i\_score'] as num?)?.toInt() ?? 0) < 0) s['tobiCount'] = (s['tobiCount'] as int) + 1;
      }
    }
    for (final name in memberNames) {
      final s = stats[name]!;
      s['matches'] = (s['session_dates'] as Set<String>).length;
    }
    for (final s in stats.values) {
      final games = s['games'] as int? ?? 0;
      final rankSum = s['rankSum'] as int? ?? 0;
      s['avgRank'] = games > 0 ? rankSum / games : 0.0;
      s['totalScore'] = s['totalMoney'];
      s['topRate'] = games > 0 ? (s['topCount'] as int) / games * 100 : 0.0;
      s['rentaiRate'] = games > 0 ? (s['rentaiCount'] as int) / games * 100 : 0.0;
      s['tobiRate'] = games > 0 ? (s['tobiCount'] as int) / games * 100 : 0.0;
    }

    final result = stats.values.toList();
    result.sort((a, b) => (b['totalPt'] as num).compareTo(a['totalPt'] as num));
    return result;
  }

  Future<Map<String, dynamic>> getUserStats(String playerName, {int? groupId}) async {
    final sessionRows = await getSessions(groupId: groupId);
    final sessions = sessionRows.where((s) => 
      (s['p1_name'] == playerName) || (s['p2_name'] == playerName) || 
      (s['p3_name'] == playerName) || (s['p4_name'] == playerName)
    ).toList();
    final sessionIds = sessions.map((s) => s['id'] as int).toSet();

    final gameRows = await getGames(groupId: groupId);
    final games = gameRows.where((g) => sessionIds.contains(g['session_id'])).toList();

    int totalPt = 0;
    int totalChip = 0;
    int totalMoney = 0;
    int gamesCount = 0;
    int rankSum = 0;
    int topCount = 0;
    int rentaiCount = 0;
    int tobiCount = 0;

    for (var s in sessions) {
      int idx = -1;
      for (int i=1; i<=4; i++) { if (s['p$i\_name'] == playerName) { idx = i-1; break; } }
      if (idx == -1) continue;
      totalMoney += (s['p${idx+1}_money'] as num?)?.toInt() ?? 0;
      
      if (s['global_chips_json'] != null) {
        try {
          final List<dynamic> gc = jsonDecode(s['global_chips_json'] as String);
          if (idx < gc.length) totalChip += (gc[idx] as num).toInt();
        } catch (_) {}
      }
    }

    int currentPt = 0;
    final history = <Map<String, dynamic>>[];

    for (var g in games) {
      int idx = -1;
      for (int i=1; i<=4; i++) { if (g['p$i\_name'] == playerName) { idx = i-1; break; } }
      if (idx == -1) continue;

      gamesCount++;
      final pt = (g['p${idx+1}_pt'] as num?)?.toInt() ?? 0;
      totalPt += pt;
      currentPt += pt;
      
      totalChip += (g['p${idx+1}_ch'] as num?)?.toInt() ?? 0;
      final rank = (g['p${idx+1}_rank'] as num?)?.toInt() ?? 1;
      rankSum += rank;
      if (rank == 1) topCount++;
      if (rank <= 2) rentaiCount++;
      if (((g['p${idx+1}_score'] as num?)?.toInt() ?? 0) < 0) tobiCount++;

      history.add({
        'gameNo': gamesCount,
        'pt': pt,
        'cumulativePt': currentPt,
      });
    }

    return {
      'games': gamesCount,
      'totalPt': totalPt,
      'totalChip': totalChip,
      'totalMoney': totalMoney,
      'topRate': gamesCount > 0 ? (topCount / gamesCount * 100) : 0.0,
      'rentaiRate': gamesCount > 0 ? (rentaiCount / gamesCount * 100) : 0.0,
      'tobiRate': gamesCount > 0 ? (tobiCount / gamesCount * 100) : 0.0,
      'avgRank': gamesCount > 0 ? (rankSum / gamesCount) : 0.0,
      'pointHistory': history,
    };
  }

  Future<List<String>> getGroupMembers(int groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      columns: ['player1_name', 'player2_name', 'player3_name', 'player4_name'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    final Set<String> members = {};
    for (var m in maps) {
      if (m['player1_name'] != null && (m['player1_name'] as String).isNotEmpty) {
        members.add(m['player1_name'] as String);
      }
      if (m['player2_name'] != null && (m['player2_name'] as String).isNotEmpty) {
        members.add(m['player2_name'] as String);
      }
      if (m['player3_name'] != null && (m['player3_name'] as String).isNotEmpty) {
        members.add(m['player3_name'] as String);
      }
      if (m['player4_name'] != null && (m['player4_name'] as String).isNotEmpty) {
        members.add(m['player4_name'] as String);
      }
    }
    return members.toList()..sort();
  }

  // Web Helpers
  Future<int> _webInsert(String key, Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    int lastId = items.isEmpty ? 5000 : items.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b);
    lastId++;
    final newRow = Map<String, dynamic>.from(row);
    newRow['id'] = lastId;
    items.add(newRow);
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

  // --- Backup & Restore (Ver 3.0) ---
  Future<Map<String, dynamic>> exportAllData() async {
    final groups = await getGroups();
    final sessions = await getSessions();
    final games = await getGames();
    return {
      'version': '3.1.0',
      'export_date': DateTime.now().toIso8601String(),
      'groups': groups,
      'sessions': sessions,
      'games': games,
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    try {
      final groupsInJson = data['groups'] as List<dynamic>? ?? [];
      final hasGroupsInJson = groupsInJson.isNotEmpty;
      final sessionsList = data['sessions'] as List<dynamic>? ?? [];
      final gamesList = data['games'] as List<dynamic>? ?? [];

      // --- 孤児データの正規化 (フェイルセーフ) ---
      // 有効なグループIDの集合を作成
      Set<int> validGroupIds = {};
      if (hasGroupsInJson) {
        // JSON内のグループが優先される場合
        validGroupIds = groupsInJson.map((g) {
          final idRaw = g['id'];
          return (idRaw is num) ? idRaw.toInt() : (int.tryParse(idRaw.toString()) ?? 0);
        }).toSet();
      } else {
        // JSONにグループが含まれない場合、現在のDB内のグループを有効とする
        final currentGroups = await getGroups();
        validGroupIds = currentGroups.map((g) {
          final idRaw = g['id'];
          return (idRaw is num) ? idRaw.toInt() : (int.tryParse(idRaw.toString()) ?? 0);
        }).toSet();
      }
      
      // セッションの group_id が有効なグループを参照しているかチェックし、なければ null (フリー対局) に置換
      final normalizedSessions = sessionsList.map((s) {
        final session = Map<String, dynamic>.from(s);
        final gidRaw = session['group_id'];
        if (gidRaw != null) {
          final gid = (gidRaw is num) ? gidRaw.toInt() : (int.tryParse(gidRaw.toString()) ?? -1);
          if (gid == -1 || !validGroupIds.contains(gid)) {
            session['group_id'] = null;
          } else {
            session['group_id'] = gid; // 確実にintにする
          }
        }
        return session;
      }).toList();

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        if (hasGroupsInJson) {
          // 型安全なグループ保存（IDを確実に数値にする）
          final nGroups = groupsInJson.map((g) {
            final map = Map<String, dynamic>.from(g);
            final idRaw = map['id'];
            map['id'] = (idRaw is num) ? idRaw.toInt() : (int.tryParse(idRaw.toString()) ?? 0);
            return map;
          }).toList();
          await prefs.setString('web_db_groups', jsonEncode(nGroups));
        }
        await prefs.setString('web_db_sessions', jsonEncode(normalizedSessions));
        await prefs.setString('web_db_games', jsonEncode(gamesList));
        return;
      }

      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('games');
        await txn.delete('sessions');
        
        if (hasGroupsInJson) {
          await txn.delete('groups');
          for (var g in groupsInJson) {
            final map = Map<String, dynamic>.from(g);
            final idRaw = map['id'];
            map['id'] = (idRaw is num) ? idRaw.toInt() : (int.tryParse(idRaw.toString()) ?? 0);
            await txn.insert('groups', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        for (var s in normalizedSessions) {
          await txn.insert('sessions', Map<String, dynamic>.from(s), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        
        for (var g in gamesList) {
          await txn.insert('games', Map<String, dynamic>.from(g), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e, stackTrace) {
      // ユーザーの指示に従い、サイレント失敗を特定するための詳細ログを出力
      print('--- IMPORT FAIL --- \nError: $e\nStack: $stackTrace');
      // 再スローしてUI側でも検知可能にする
      rethrow;
    }
  }
}

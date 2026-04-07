import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // Games table
    await db.execute('''
      CREATE TABLE games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        group_id INTEGER,
        p1_name TEXT, p2_name TEXT, p3_name TEXT, p4_name TEXT,
        p1_score INTEGER, p2_score INTEGER, p3_score INTEGER, p4_score INTEGER,
        p1_ch INTEGER, p2_ch INTEGER, p3_ch INTEGER, p4_ch INTEGER,
        p1_tobi INTEGER, p2_tobi INTEGER, p3_tobi INTEGER, p4_tobi INTEGER,
        p1_pt INTEGER, p2_pt INTEGER, p3_pt INTEGER, p4_pt INTEGER,
        p1_rank INTEGER, p2_rank INTEGER, p3_rank INTEGER, p4_rank INTEGER,
        p1_money INTEGER, p2_money INTEGER, p3_money INTEGER, p4_money INTEGER
      )
    ''');

    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // Group Members table
    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');
  }

  // Basic CRUD for Games
  Future<int> insertGame(Map<String, dynamic> row) async {
    if (kIsWeb) return _webInsert('web_db_games', row);
    final db = await database;
    return await db.insert('games', row);
  }

  Future<int> upsertGame(Map<String, dynamic> row) async {
    if (kIsWeb) {
      if (row.containsKey('id') && row['id'] != null) {
        return _webUpdate('web_db_games', row);
      } else {
        return _webInsert('web_db_games', row);
      }
    }
    final db = await database;
    if (row.containsKey('id') && row['id'] != null) {
      return await db.update('games', row, where: 'id = ?', whereArgs: [row['id']]);
    } else {
      return await db.insert('games', row);
    }
  }

  Future<List<Map<String, dynamic>>> getGames({String? type, int? groupId}) async {
    if (kIsWeb) {
      final allGames = await _webQuery('web_db_games');
      var filtered = allGames;
      if (type != null) {
        filtered = filtered.where((e) => e['type'] == type).toList();
      }
      if (groupId != null) {
        filtered = filtered.where((e) => e['group_id'] == groupId).toList();
      }
      // Sort by date DESC natively like SQLite mapping
      filtered.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return filtered;
    }
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (type != null && groupId != null) {
      where = 'type = ? AND group_id = ?';
      whereArgs = [type, groupId];
    } else if (type != null) {
      where = 'type = ?';
      whereArgs = [type];
    } else if (groupId != null) {
      where = 'group_id = ?';
      whereArgs = [groupId];
    }

    return await db.query('games', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
  }

  Future<int> deleteGame(int id) async {
    if (kIsWeb) return _webDelete('web_db_games', id);
    final db = await database;
    return await db.delete('games', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateGameGroupIdToNull(int groupId) async {
    if (kIsWeb) {
      final allGames = await _webQuery('web_db_games');
      bool changed = false;
      for (var g in allGames) {
        if (g['group_id'] == groupId) {
          g['group_id'] = null;
          changed = true;
        }
      }
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('web_db_games', jsonEncode(allGames));
      }
      return;
    }
    final db = await database;
    await db.update('games', {'group_id': null}, where: 'group_id = ?', whereArgs: [groupId]);
  }

  // Basic CRUD for Groups
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
    // Ver 1.3: Dissociate games first instead of CASCADE or leaving broken IDs
    await updateGameGroupIdToNull(id);
    
    if (kIsWeb) return _webDelete('web_db_groups', id);
    final db = await database;
    return await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // Statistics helpers
  Future<List<String>> getAllPlayerNames() async {
    if (kIsWeb) {
      final games = await _webQuery('web_db_games');
      final Set<String> names = {};
      for (var g in games) {
        if (g['p1_name'] != null && g['p1_name'] != '') names.add(g['p1_name']);
        if (g['p2_name'] != null && g['p2_name'] != '') names.add(g['p2_name']);
        if (g['p3_name'] != null && g['p3_name'] != '') names.add(g['p3_name']);
        if (g['p4_name'] != null && g['p4_name'] != '') names.add(g['p4_name']);
      }
      return names.toList()..sort();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('games', columns: ['p1_name', 'p2_name', 'p3_name', 'p4_name']);
    final Set<String> names = {};
    for (var m in maps) {
      if (m['p1_name'] != null && m['p1_name'] != '') names.add(m['p1_name']);
      if (m['p2_name'] != null && m['p2_name'] != '') names.add(m['p2_name']);
      if (m['p3_name'] != null && m['p3_name'] != '') names.add(m['p3_name']);
      if (m['p4_name'] != null && m['p4_name'] != '') names.add(m['p4_name']);
    }
    return names.toList()..sort();
  }

  /// グループ内全メンバーのスタッツを集計して返す。
  /// 集計対象: group_idに依存せず、メンバー名が一致する全対局を対象とする。
  /// 返り値: メンバーごとの Map リスト（ソート前）
  Future<List<Map<String, dynamic>>> getGroupRanking(int groupId) async {
    // 1. メンバー名リストを取得
    final memberRows = await getMembers(groupId);
    final memberNames = memberRows.map((e) => e['name'] as String).toList();

    if (memberNames.isEmpty) return [];
    final memberNameSet = memberNames.toSet();

    // 2. 全対局を取得（group_idフィルタなし：名前で突き合わせる）
    List<Map<String, dynamic>> allRows;
    if (kIsWeb) {
      allRows = await _webQuery('web_db_games');
    } else {
      final db = await database;
      allRows = await db.query('games');
    }

    // 3. メンバーごとに集計マップを初期化
    final Map<String, Map<String, dynamic>> stats = {};
    for (final name in memberNames) {
      stats[name] = {
        'name': name,
        'games': 0,
        'totalPt': 0,
        'totalChip': 0,
        'rankSum': 0,
        'topCount': 0,
        'rentaiCount': 0,
        'tobiCount': 0,
        'totalMoney': 0,
      };
    }

    // 4. 各対局をスキャンし、メンバー名が一致するスロットを集計
    for (final row in allRows) {
      for (int i = 1; i <= 4; i++) {
        final rawName = (row['p${i}_name'] as Object?)?.toString() ?? '';
        final trimmedName = rawName.trim();
        if (trimmedName.isEmpty || !memberNameSet.contains(trimmedName)) continue;
        
        final s = stats[trimmedName]!;
        s['games'] = (s['games'] as int) + 1;
        s['totalPt'] = (s['totalPt'] as int) + ((row['p${i}_pt'] as num?)?.toInt() ?? 0);
        s['totalChip'] = (s['totalChip'] as int) + ((row['p${i}_ch'] as num?)?.toInt() ?? 0);
        
        // 収支 (マネー) の集計
        // 保存されていない旧データがある場合は、Ptとチップから概算（レート計算ロジックが必要だが、ここではDB値を優先）
        final money = (row['p${i}_money'] as num?)?.toInt() ?? 0;
        s['totalMoney'] = (s['totalMoney'] as int) + money;
        
        final rank = (row['p${i}_rank'] as num?)?.toInt() ?? 1;
        s['rankSum'] = (s['rankSum'] as int) + rank;
        if ((row['p${i}_tobi'] as num?)?.toInt() == 1) {
          s['tobiCount'] = (s['tobiCount'] as int) + 1;
        }
        if (rank == 1) s['topCount'] = (s['topCount'] as int) + 1;
        if (rank <= 2) s['rentaiCount'] = (s['rentaiCount'] as int) + 1;
      }
    }

    // 5. 派生値を計算して最終リストに変換
    return stats.values.map((s) {
      final games = s['games'] as int;
      final totalPt = s['totalPt'] as int;
      final totalChip = s['totalChip'] as int;
      return {
        'name': s['name'],
        'games': games,
        'totalPt': totalPt,
        'totalChip': totalChip,
        'totalScore': s['totalMoney'] as int, // これを正確な収支として扱う
        'avgRank': games > 0 ? (s['rankSum'] as int) / games : 0.0,
        'topRate': games > 0 ? (s['topCount'] as int) / games * 100 : 0.0,
        'rentaiRate': games > 0 ? (s['rentaiCount'] as int) / games * 100 : 0.0,
        'tobiRate': games > 0 ? (s['tobiCount'] as int) / games * 100 : 0.0,
      };
    }).toList();
  }

  // Basic CRUD for Members
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

  // --- Web SharedPreferences Proxy Helpers ---
  Future<int> _webInsert(String key, Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    
    // Auto Increment ID
    int lastId = prefs.getInt('web_db_last_id') ?? 1000;
    lastId++;
    await prefs.setInt('web_db_last_id', lastId);
    
    final newRow = Map<String, dynamic>.from(row);
    newRow['id'] = lastId;
    items.add(newRow);
    
    await prefs.setString(key, jsonEncode(items));
    return lastId;
  }

  Future<int> _webUpdate(String key, Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    final id = row['id'];
    
    final index = items.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      items[index] = row;
      await prefs.setString(key, jsonEncode(items));
      return 1;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> _webQuery(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> _webDelete(String key, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _webQuery(key);
    
    final index = items.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      items.removeAt(index);
      await prefs.setString(key, jsonEncode(items));
      return 1;
    }
    return 0;
  }
}

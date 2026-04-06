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
        p1_rank INTEGER, p2_rank INTEGER, p3_rank INTEGER, p4_rank INTEGER
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

  Future<int> deleteGroup(int id) async {
    if (kIsWeb) return _webDelete('web_db_groups', id);
    final db = await database;
    return await db.delete('groups', where: 'id = ?', whereArgs: [id]);
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

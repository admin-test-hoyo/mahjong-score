import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/database_service.dart';
import '../../core/database/database_providers.dart';
import '../stats/stats_providers.dart';
import '../../core/models/db_models.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  static void showAddGroup(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: Text('新規グループ作成', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.notoSansJp(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'グループ名を入力',
            hintStyle: GoogleFonts.notoSansJp(color: Colors.white24),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: GoogleFonts.notoSansJp(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                await DatabaseService().insertGroup(controller.text);
                ref.read(databaseVersionProvider.notifier).increment();
              }
            },
            child: Text('追加', style: GoogleFonts.notoSansJp(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {

  @override
  Widget build(BuildContext context) {
    final groupListAsync = ref.watch(groupListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF001F1A),
      appBar: AppBar(
        title: const Text('グループ管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00FFC2), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF00FFC2)),
            onPressed: () => GroupScreen.showAddGroup(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: groupListAsync.when(
        data: (allGroups) {
          final groups = allGroups.where((g) => g['id'] != systemGroupIdFreeMatch).toList();
          if (groups.isEmpty) {
            return Center(child: Text('グループが登録されていません', style: GoogleFonts.notoSansJp(color: Colors.white24)));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final groupId = group['id'] as int;

              return Card(
                color: Colors.black26,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.group, color: Colors.white54),
                  title: Text(group['name'], style: GoogleFonts.notoSansJp(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('タップしてメニューを表示', style: GoogleFonts.notoSansJp(color: Colors.white38, fontSize: 10)),
                  trailing: const Icon(Icons.expand_more, color: Colors.white24),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _actionIcon(Icons.person_outline, 'メンバー編集', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MemberEditScreen(groupId: groupId, groupName: group['name']),
                              ),
                            );
                          }),
                          _actionIcon(Icons.edit_outlined, '名前変更', () => _showEditGroupDialog(groupId, group['name'])),
                          _actionIcon(Icons.delete_outline, '削除', () => _confirmDeleteGroup(groupId, group['name']), color: Colors.redAccent.withValues(alpha: 0.8)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
        error: (e, s) => Center(child: Text('エラー: $e', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Future<void> _editGroupWrapper(int id, String name) async {
    await DatabaseService().updateGroupName(id, name);
    ref.read(databaseVersionProvider.notifier).increment();
  }

  Future<void> _deleteGroupWrapper(int id) async {
    await DatabaseService().deleteGroup(id);
    ref.read(databaseVersionProvider.notifier).increment();
  }

  void _showEditGroupDialog(int id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: Text('グループ名編集', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.notoSansJp(color: Colors.white),
          decoration: InputDecoration(
            hintText: '新しい名前を入力',
            hintStyle: GoogleFonts.notoSansJp(color: Colors.white24),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: GoogleFonts.notoSansJp(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editGroupWrapper(id, controller.text);
            },
            child: Text('保存', style: GoogleFonts.notoSansJp(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: Text('グループ削除', style: GoogleFonts.notoSansJp(color: Colors.white, fontSize: 16)),
        content: Text('「$name」を削除しますか？\n（注：対局履歴は削除されません）', style: GoogleFonts.notoSansJp(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル', style: GoogleFonts.notoSansJp(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroupWrapper(id);
            },
            child: Text('削除', style: GoogleFonts.notoSansJp(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.notoSansJp(color: color ?? Colors.white54, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class MemberEditScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const MemberEditScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final db = DatabaseService();
    _members = await db.getMembers(widget.groupId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addMember() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    
    final db = DatabaseService();
    await db.insertMember(widget.groupId, name);
    _controller.clear();
    _loadMembers();
  }

  Future<void> _deleteMember(int memberId) async {
    final db = DatabaseService();
    await db.deleteMember(memberId);
    _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('${widget.groupName} のメンバー'),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black12,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '新しいメンバーを入力',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFC2).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF00FFC2),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _addMember,
                  child: const Icon(Icons.person_add),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
              : _members.isEmpty
                ? const Center(child: Text('メンバーが登録されていません', style: TextStyle(color: Colors.white24)))
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.white54),
                        title: Text(member['name'], style: GoogleFonts.notoSansJp(color: Colors.white70, fontSize: 15)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteMember(member['id']),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

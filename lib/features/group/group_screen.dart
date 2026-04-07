import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/database_service.dart';
import '../calc/calc_state.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      _groups = await db.getGroups();
    } catch (e) {
      print('Group load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addGroup(String name) async {
    if (name.isEmpty) return;
    final db = DatabaseService();
    await db.insertGroup(name);
    _loadGroups();
  }

  Future<void> _editGroup(int id, String name) async {
    if (name.isEmpty) return;
    final db = DatabaseService();
    await db.updateGroupName(id, name);
    _loadGroups();
  }

  Future<void> _deleteGroup(int id) async {
    final db = DatabaseService();
    await db.deleteGroup(id);
    _loadGroups();
  }

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('新規グループ作成', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'グループ名を入力',
            hintStyle: TextStyle(color: Colors.white24),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addGroup(controller.text);
            },
            child: const Text('追加', style: TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog(int id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1A),
        title: const Text('グループ名編集', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '新しい名前を入力',
            hintStyle: TextStyle(color: Colors.white24),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editGroup(id, controller.text);
            },
            child: const Text('保存', style: TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
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
        title: const Text('グループ削除', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('「$name」を削除しますか？\n（注：対局履歴は削除されません）', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup(id);
            },
            child: const Text('削除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calcProvider);
    final notifier = ref.read(calcProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('グループ管理', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00FFC2),
        foregroundColor: const Color(0xFF004D40),
        onPressed: _showAddGroupDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
        : _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_add, color: Colors.white24, size: 64),
                  const SizedBox(height: 16),
                  const Text('グループが登録されていません。', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text('右下の「+」ボタンから、麻雀仲間などのグループを作成してください。', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                final groupId = group['id'] as int;
                final isSelected = state.selectedGroupId == groupId;

                return Card(
                  color: Colors.black26,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? const Color(0xFF00FFC2) : Colors.white10),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(Icons.group, color: isSelected ? const Color(0xFF00FFC2) : Colors.white54),
                    title: Text(group['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('タップしてメニューを表示', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF00FFC2), size: 18),
                        const Icon(Icons.expand_more, color: Colors.white24),
                      ],
                    ),
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
                              ).then((_) => _loadGroups());
                            }),
                            _actionIcon(Icons.edit_outlined, '名前変更', () => _showEditGroupDialog(groupId, group['name'])),
                            _actionIcon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, isSelected ? '選択解除' : 'グループ選択', () {
                              notifier.state = state.copyWith(selectedGroupId: isSelected ? null : groupId);
                            }, color: isSelected ? const Color(0xFF00FFC2) : null),
                            _actionIcon(Icons.delete_outline, '削除', () => _confirmDeleteGroup(groupId, group['name']), color: Colors.redAccent.withOpacity(0.8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
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
            Text(label, style: TextStyle(color: color ?? Colors.white54, fontSize: 9)),
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
        title: Text('${widget.groupName} のメンバー', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
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
                    backgroundColor: const Color(0xFF00FFC2).withOpacity(0.1),
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
                        title: Text(member['name'], style: const TextStyle(color: Colors.white70, fontSize: 15)),
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

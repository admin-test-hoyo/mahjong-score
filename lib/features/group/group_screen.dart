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

  Future<void> _addMember(int groupId, String name) async {
    if (name.isEmpty) return;
    final db = DatabaseService();
    await db.insertMember(groupId, name);
    setState(() {}); // Refresh list
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calcProvider);
    final notifier = ref.read(calcProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: Text('グループ管理', style: GoogleFonts.robotoMono(color: const Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildAddGroupField(),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView.builder(
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
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.group, color: isSelected ? const Color(0xFF00FFC2) : Colors.white54),
                            title: Text(group['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, color: isSelected ? const Color(0xFF00FFC2) : Colors.white24),
                              onPressed: () => notifier.state = state.copyWith(selectedGroupId: isSelected ? null : groupId),
                            ),
                          ),
                          const Divider(color: Colors.white12),
                          _MemberListWidget(groupId: groupId, onAddMember: (name) => _addMember(groupId, name)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildAddGroupField() {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '新しいグループ名を入力',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFC2).withOpacity(0.1),
            foregroundColor: const Color(0xFF00FFC2),
            padding: const EdgeInsets.all(12),
          ),
          onPressed: () {
            _addGroup(controller.text);
            controller.clear();
          },
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _MemberListWidget extends StatefulWidget {
  final int groupId;
  final Function(String) onAddMember;

  const _MemberListWidget({required this.groupId, required this.onAddMember});

  @override
  State<_MemberListWidget> createState() => _MemberListWidgetState();
}

class _MemberListWidgetState extends State<_MemberListWidget> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final db = DatabaseService();
    _members = await db.getMembers(widget.groupId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _members.map((m) => Chip(
              label: Text(m['name'], style: const TextStyle(fontSize: 10, color: Colors.white70)),
              backgroundColor: Colors.white.withOpacity(0.05),
              padding: EdgeInsets.zero,
            )).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'メンバー追加',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF00FFC2), size: 18),
                onPressed: () {
                  widget.onAddMember(_controller.text);
                  _controller.clear();
                  _loadMembers();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

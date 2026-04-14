import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_service.dart';
import '../calc/calc_providers.dart';
import '../stats/stats_providers.dart';
import 'member_selection_provider.dart';

class MemberSelectionScreen extends ConsumerStatefulWidget {
  final int initialGroupId;
  const MemberSelectionScreen({super.key, required this.initialGroupId});

  @override
  ConsumerState<MemberSelectionScreen> createState() => _MemberSelectionScreenState();
}

class _MemberSelectionScreenState extends ConsumerState<MemberSelectionScreen> {
  late int _currentGroupId;

  @override
  void initState() {
    super.initState();
    _currentGroupId = widget.initialGroupId;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupListProvider);
    final selectedNames = ref.watch(memberSelectionProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF001F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(selectedNames.length),
          Expanded(
            child: _buildMainContent(groupsAsync, selectedNames),
          ),
          _buildFooter(selectedNames),
        ],
      ),
    );
  }

  Widget _buildHeader(int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text(
            '対局メンバーを選択',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '選択順に 東・南・西・北 の座順となります',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
          ),
          const SizedBox(height: 12),
          Text(
            '選択済み：$selectedCount / 4人',
            style: TextStyle(
              color: selectedCount == 4 ? const Color(0xFF00FFC2) : Colors.white24,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AsyncValue<List<Map<String, dynamic>>> groupsAsync, List<String> selectedNames) {
    return groupsAsync.when(
      data: (groups) {
        // システムグループ(0)を先頭にするための処理
        final sortedGroups = List<Map<String, dynamic>>.from(groups);
        sortedGroups.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

        return Column(
          children: [
            _buildGroupSelector(sortedGroups),
            const Divider(color: Colors.white10, height: 1),
            Expanded(child: _buildMemberList(_currentGroupId, selectedNames)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2))),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildGroupSelector(List<Map<String, dynamic>> groups) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final g = groups[index];
          final groupId = g['id'] as int;
          final isSelected = _currentGroupId == groupId;
          final name = groupId == 0 ? '全員を表示' : g['name'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (val) {
                if (val && !isSelected) {
                  setState(() => _currentGroupId = groupId);
                  // グループ切り替え時に選択状態をリセット
                  ref.read(memberSelectionProvider.notifier).clear();
                }
              },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: const Color(0xFF00FFC2).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF00FFC2) : Colors.white60,
                fontSize: 12,
              ),
              shape: StadiumBorder(
                side: BorderSide(color: isSelected ? const Color(0xFF00FFC2) : Colors.transparent),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberList(int groupId, List<String> selectedNames) {
    final memberFuture = groupId == 0
        ? DatabaseService().getAllPlayerNames()
        : DatabaseService().getGroupMembers(groupId).timeout(const Duration(seconds: 3));

    return FutureBuilder<List<String>>(
      future: memberFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC2)));
        }
        if (snapshot.hasError) return const Center(child: Text('データ取得に失敗しました', style: TextStyle(color: Colors.redAccent, fontSize: 12)));
        
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('このグループにはメンバーがいません', style: TextStyle(color: Colors.white24, fontSize: 13)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final name = members[index];
            final order = ref.read(memberSelectionProvider.notifier).getSelectionOrder(name);
            final isSelected = order != null;

            return InkWell(
              onTap: () => ref.read(memberSelectionProvider.notifier).toggleMember(name),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00FFC2).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00FFC2) : Colors.white10,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00FFC2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            order.toString(),
                            style: const TextStyle(
                              color: Color(0xFF004D40),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(List<String> selectedNames) {
    final canConfirm = selectedNames.isNotEmpty && selectedNames.length <= 4;
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).padding.bottom + 20, top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFC2),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white10,
            disabledForegroundColor: Colors.white24,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: canConfirm ? () {
            ref.read(calcProvider.notifier).setPlayersFromGroup(_currentGroupId, selectedNames);
            Navigator.pop(context);
          } : null,
          child: Text(
            selectedNames.isEmpty ? 'メンバーを選択してください' : '確定して反映 (${selectedNames.length}名)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

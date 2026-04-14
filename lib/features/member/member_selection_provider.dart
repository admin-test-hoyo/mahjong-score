import 'package:flutter_riverpod/flutter_riverpod.dart';

/// メンバー追加・削除の履歴を保持し、座順（東南西北）を決定するプロバイダー
class MemberSelectionNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  /// メンバーの選択状態を切り替える
  /// 未選択なら末尾に追加(最大4人)、選択済みなら削除し、以降の順序を詰める
  void toggleMember(String name) {
    final current = List<String>.from(state);
    if (current.contains(name)) {
      current.remove(name);
    } else {
      if (current.length < 4) {
        current.add(name);
      }
    }
    state = current;
  }

  /// 選択状態をリセットする（グループ切り替え時などに使用）
  void clear() {
    state = [];
  }

  /// 指定した名前の選択順（1〜4）を取得する。未選択ならnull。
  int? getSelectionOrder(String name) {
    final index = state.indexOf(name);
    return index == -1 ? null : index + 1;
  }
}

final memberSelectionProvider = NotifierProvider.autoDispose<MemberSelectionNotifier, List<String>>(() {
  return MemberSelectionNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// データベースの更新状態を管理するNotifier
class DatabaseVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }
}

/// データベースの更新タイミングを通知するための Provider
final databaseVersionProvider = NotifierProvider<DatabaseVersionNotifier, int>(DatabaseVersionNotifier.new);

/// 現在選択されているグループIDを管理するNotifier (Ver 3.4.1で復旧)
class SelectedGroupIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void update(int? id) {
    state = id;
  }
}

/// 現在選択されているグループIDを管理するProvider
final selectedGroupIdProvider = NotifierProvider<SelectedGroupIdNotifier, int?>(SelectedGroupIdNotifier.new);

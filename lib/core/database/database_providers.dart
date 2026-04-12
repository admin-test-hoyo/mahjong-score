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

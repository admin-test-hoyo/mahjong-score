import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainTab { calc, history, stats, groups }

class NavigationNotifier extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.calc;
  void setTab(MainTab tab) => state = tab;
}

final navigationProvider = NotifierProvider<NavigationNotifier, MainTab>(NavigationNotifier.new);

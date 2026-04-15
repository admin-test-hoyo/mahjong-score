import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calc_state.dart';
import '../../core/models/app_config.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final calcProvider = NotifierProvider<CalcNotifier, CalcState>(() {
  return CalcNotifier();
});

final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(() {
  return ConfigNotifier();
});

class SanmaNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return prefs.getBool('isSanma') ?? false;
  }

  void toggle() {
    final newState = !state;
    state = newState;
    ref.read(sharedPrefsProvider).setBool('isSanma', newState);
  }
}

final sanmaProvider = NotifierProvider<SanmaNotifier, bool>(() {
  return SanmaNotifier();
});

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

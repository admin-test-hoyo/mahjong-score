import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'features/main/main_screen.dart';
import 'features/calc/calc_state.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  html.window.console.log('【AppStatus】: main() started');
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Flutterフレームワーク内のエラー捕捉
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final errorStr = '【FlutterError】: ${details.exceptionAsString()}\n${details.stack}';
    html.window.console.error(errorStr); // ブラウザコンソールに赤色で出力
  };

  // 2. 非同期・プラットフォーム例外の捕捉 (Dart 3.x以降の推奨)
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = '【PlatformError】: $error\n$stack';
    html.window.console.error(errorStr);
    return true; // ハンドル済みとして処理し、クラッシュダイアログを抑制
  };

  // 3. 全体を zone で囲み、漏れなくキャッチ
  runZonedGuarded(() async {
    final sharedPrefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(sharedPrefs),
        ],
        child: const MahjongApp(),
      ),
    );
  }, (error, stack) {
    final errorStr = '【ZonedError】: $error\n$stack';
    html.window.console.error(errorStr);
  });
}

class MahjongApp extends StatelessWidget {
  const MahjongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '麻雀スコア表',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'), // Japanese
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676), // Neon green
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF001F1A),
        textTheme: GoogleFonts.robotoMonoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

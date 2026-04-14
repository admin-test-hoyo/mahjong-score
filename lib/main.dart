import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/calc/calc_providers.dart';
import 'features/main/main_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:ui' as ui;
import 'package:universal_html/html.dart' as html;

void main() async {
  debugPrint('【AppStatus】: main() started');
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Flutterフレームワーク内のエラー捕捉
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final errorStr = '【FlutterError】: ${details.exceptionAsString()}\n${details.stack}';
    debugPrint(errorStr);
  };

  // 2. 非同期・プラットフォーム例外の捕捉 (Dart 3.x以降の推奨)
  ui.PlatformDispatcher.instance.onError = (error, stack) {
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
    debugPrint(errorStr);
  });
}

class MahjongApp extends StatelessWidget {
  const MahjongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '麻雀スコア表',
      locale: const Locale('ja', 'JP'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF001F1A),
        textTheme: GoogleFonts.notoSansJpTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black.withValues(alpha: 0.3),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.notoSansJp(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00FFC2),
          ),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

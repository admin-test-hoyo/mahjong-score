import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/calc/calc_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MahjongApp(),
    ),
  );
}

class MahjongApp extends StatelessWidget {
  const MahjongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mahjong Calc',
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
      home: const CalcScreen(),
    );
  }
}

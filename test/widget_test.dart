import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_calc/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahjong_calc/features/calc/calc_state.dart';

void main() {
  testWidgets('CalcScreen renders basic spreadsheet structure without errors', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MahjongApp(),
    ));

    // Verify title exists
    expect(find.text('麻雀スコア表'), findsWidgets);
    
    // Verify player names 'A', 'B', 'C' exist
    expect(find.text('A'), findsWidgets);
    expect(find.text('B'), findsWidgets);
    expect(find.text('C'), findsWidgets);
    
    // Verify add game button
    expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
    
    // Verify settings button
    expect(find.byIcon(Icons.settings), findsWidgets);
  });
}

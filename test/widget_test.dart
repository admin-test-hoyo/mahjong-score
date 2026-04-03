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

    // Verify header exists
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('場代'), findsOneWidget);
    
    // Verify columns exist
    expect(find.text('A'), findsWidgets);
    
    // Verify first row check mechanism (check_circle icon instead of OK text)
    expect(find.byIcon(Icons.add_circle), findsWidgets);
  });
}

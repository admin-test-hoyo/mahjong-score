import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_calc/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('CalcScreen renders basic spreadsheet structure without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MahjongApp()));

    // Verify header exists
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('場代 (1日の1卓総額)'), findsOneWidget);
    
    // Verify columns exist
    expect(find.text('Player 1'), findsWidgets);
    
    // Verify first row check mechanism
    expect(find.text('OK'), findsWidgets); // Due to 0x4 returning valid
  });
}

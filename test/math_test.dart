import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_calc/core/calculator.dart';
import 'package:mahjong_calc/core/models/app_config.dart';

void main() {
  test('Tobi explicit integration test', () {
    final p1 = PlayerInput(id: 1, score: 54000, tobiPt: 10, yakumanPt: 0);
    final p2 = PlayerInput(id: 2, score: 25000, tobiPt: 0, yakumanPt: 0);
    final p3 = PlayerInput(id: 3, score: 21000, tobiPt: 0, yakumanPt: 0);
    final p4 = PlayerInput(id: 4, score: 0, tobiPt: -10, yakumanPt: 0);

    final rule = MahjongRule(
      returnScore: 30000,
      uma: [30, 10, -10, -30],
      oka: 20,
    );
    
    final results = MahjongCalculator.calculate(
      inputs: [p1, p2, p3, p4], 
      rule: rule, 
      config: const AppConfig()
    );

    // p1 = +54, return = 30 => base = +24. uma = +30. oka = +20. tobi = +10. Total = +84.
    expect(results.firstWhere((r)=>r.id==1).finalPoint, 84);
  });
}

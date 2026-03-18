import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_calc/core/calculator.dart';
import 'package:mahjong_calc/core/models/app_config.dart';

void main() {
  group('MahjongCalculator', () {
    final defaultRule = const MahjongRule();
    
    test('calculateMissingScore computes correctly', () {
      final scores = [35000, 25000, 15000];
      final fourth = MahjongCalculator.calculateMissingScore(scores);
      expect(fourth, 25000); // 35k + 25k + 15k = 75k => 100k - 75k = 25k
    });

    test('calculate correctly applies gosha-rokunyu, uma, and oka', () {
      // Input scores:
      // Player 1: 45000 (+15.0 pts) => +15 + 20(uma) + 20(oka) = +55
      // Player 2: 25600 (-4.4 pts) => -4.4=>-4(gosharokunyu) + 10(uma) = +6
      // Player 3: 17500 (-12.5 pts) => -12.5=>-12(gosharokunyu) - 10(uma) = -22
      // Player 4: 11900 (-18.1 pts) => -18.1=>-18(gosharokunyu) - 20(uma) = -38
      // Sum = 45000 + 25600 + 17500 + 11900 = 100000 
      // Point sum = 55 + 6 - 22 - 38 = +1.. Wait, 45+25-17.5-12?
      // P1: 45.0-30.0 = 15.0 -> 15 => 15+20+20 = 55
      // P2: 25.6-30.0 = -4.4 -> -4 => -4+10 = +6
      // P3: 17.5-30.0 = -12.5 -> -12 (五捨) => -12-10 = -22
      // P4: 11.9-30.0 = -18.1 -> -18 => -18-20 = -38
      // Sum rounded = 15 - 4 - 12 - 18 = -19 -- discrepancy with actual sum (0).
      // Wait, 15.0 - 4.4 - 12.5 - 18.1 = -20.0
      // Let's recheck the test case points carefully.
      final p1 = PlayerInput(id: 1, score: 38600); // +8.6 => +9
      final p2 = PlayerInput(id: 2, score: 25500); // -4.5 => -4
      final p3 = PlayerInput(id: 3, score: 18500); // -11.5 => -11
      final p4 = PlayerInput(id: 4, score: 17400); // -12.6 => -13
      // Total score = 100000
      
      final results = MahjongCalculator.calculate(
        inputs: [p1, p2, p3, p4], 
        rule: defaultRule,
        config: const AppConfig(),
      );
      
      // Checking rounding precision
      final r1 = results.firstWhere((r) => r.id == 1);
      final r2 = results.firstWhere((r) => r.id == 2);
      final r3 = results.firstWhere((r) => r.id == 3);
      final r4 = results.firstWhere((r) => r.id == 4);
      
      expect(r1.roundedPoint, 9);
      expect(r2.roundedPoint, -4);
      expect(r3.roundedPoint, -11);
      expect(r4.roundedPoint, -13);
      
      // Point sum: 9 + -4 + -11 + -13 = -19. Which means top (p1) gets +19 instead of 9?
      // Wait, sum is -19. Therefore total sum -19 != 0. 
      // MahjongCalculator adjusts the top player to absorb the error. 
      // 9 - (-19) = 28 final modified rounded point? 
      // Actually, final points before adjust:
      // p1: 9 + 20(uma) + 20(oka) = 49
      // p2: -4 + 10 = 6
      // p3: -11 - 10 = -21
      // p4: -13 - 20 = -33
      // sum = 49 + 6 - 21 - 33 = +1 => Top adjusts by -1 => p1 becomes 48.
      
      expect(r1.finalPoint, 48);
      expect(r2.finalPoint, 6);
      expect(r3.finalPoint, -21);
      expect(r4.finalPoint, -33);
      
      // Total final points should always be exactly 0
      final totalFinal = results.fold(0, (sum, r) => sum + r.finalPoint);
      expect(totalFinal, 0);
    });

    test('calculate correctly computes money with ceil to 10 yen', () {
      final p1 = PlayerInput(id: 1, score: 38600, chip: 2); // 48pt => 48 * 50 = 2400. Chip=2*100=200. Total 2600.
      final p2 = PlayerInput(id: 2, score: 25500, chip: 1); // 6pt => 300. Chip=100. Total=400.
      final p3 = PlayerInput(id: 3, score: 18500, chip: -1); // -21pt => -1050. Chip=-100. Total=-1150.
      final p4 = PlayerInput(id: 4, score: 17400, chip: -2); // -33pt => -1650. Chip=-200. Total=-1850.
      
      // Rule has totalFee = 2000 => 500 per head
      final rule = defaultRule.copyWith(totalFee: 2000);
      
      final results = MahjongCalculator.calculate(
        inputs: [p1, p2, p3, p4], 
        rule: rule,
        config: const AppConfig(gameFee: 2000),
      );
      
      final r1 = results.firstWhere((r) => r.id == 1);
      final r2 = results.firstWhere((r) => r.id == 2);
      final r3 = results.firstWhere((r) => r.id == 3);
      final r4 = results.firstWhere((r) => r.id == 4);
      
      // r1 money before round: 2600 - 500 = 2100. /10 ceil * 10 => 2100
      expect(r1.money, 2100);
      // r2 money before round: 400 - 500 = -100 => -100
      expect(r2.money, -100);
      // r3 money before round: -1150 - 500 = -1650 => -1650
      expect(r3.money, -1650);
      // r4 money before: -1850 - 500 = -2350 => -2350
      expect(r4.money, -2350);
    });
    
    test('calculate rounding logic strictly ceil to multiples of 10', () {
      final rule = const MahjongRule(rate: 100, chipRate: 0, totalFee: 0); // 1pt = 100yen
      // Let's manually inject some irregular money to test rounding
      // For instance, a finalPoint of 1, rating to 22.1 -> impossible with ints.
      // But let's assume raw point was 10, total fee 333 (83.25 deduction)
      // Player 1: (10 * 100) - 83.25 = 916.75 => ceil to 10s => 920.
      // Since totalFee is int, deduction is totalFee/4 = 25 for totalFee100.
      // Let's make an arbitrary test to ensure the rounding step ceil() applies.
      
      // With rate=50(点5), fee=1500 => per head 375
      // 1pt = 50. 
      // 6pt = 300 => 300 - 375 = -75. Ceil of -75/10 is -7. -7 * 10 = -70.
      final p1 = PlayerInput(id: 1, score: 38600); // 48pt
      final p2 = PlayerInput(id: 2, score: 25500); // 6pt
      final p3 = PlayerInput(id: 3, score: 18500); // -21pt
      final p4 = PlayerInput(id: 4, score: 17400); // -33pt
      
      final customRule = defaultRule.copyWith(totalFee: 1500);
      final results = MahjongCalculator.calculate(inputs: [p1, p2, p3, p4], rule: customRule, config: const AppConfig(gameFee: 1500));
      
      // p1: 48 * 50 - 375 = 2400 - 375 = 2025. 2025/10 = 202.5. Ceil => 203 => 2030
      // p2: 6 * 50 - 375 = 300 - 375 = -75. /10 = -7.5. Ceil(-7.5) = -7 => -70
      // p3: -21 * 50 - 375 = -1050 - 375 = -1425. /10 = -142.5. Ceil(-142.5) = -142 => -1420
      // p4: -33 * 50 - 375 = -1650 - 375 = -2025. /10 = -202.5. Ceil(-202.5) = -202 => -2020
      expect(results.firstWhere((r)=>r.id==1).money, 2030);
      expect(results.firstWhere((r)=>r.id==2).money, -70);
      expect(results.firstWhere((r)=>r.id==3).money, -1420);
      expect(results.firstWhere((r)=>r.id==4).money, -2020);
    });

    test('Tie-break priority logic based on startingOyaIndex', () {
      final p1 = PlayerInput(id: 1, score: 30000);
      final p2 = PlayerInput(id: 2, score: 25000);
      final p3 = PlayerInput(id: 3, score: 25000); // Tied with p2
      final p4 = PlayerInput(id: 4, score: 20000);

      // Scenario 1: startingOyaIndex = 0 (Player 1 is East)
      // p1(E)=0, p2(S)=1, p3(W)=2, p4(N)=3
      // Tie between p2(1) and p3(2) -> p2 should be ranked higher (rank 1), p3 rank 2.
      // Uma: rank 1 gets 10, rank 2 gets -10.
      final results1 = MahjongCalculator.calculate(inputs: [p1, p2, p3, p4], rule: defaultRule, config: const AppConfig(), startingOyaIndex: 0);
      expect(results1.firstWhere((r) => r.id == 2).finalPoint, (25 - 30) + 10); // -5 + 10 = +5
      expect(results1.firstWhere((r) => r.id == 3).finalPoint, (25 - 30) - 10); // -5 - 10 = -15

      // Scenario 2: startingOyaIndex = 2 (Player 3 is East)
      // p1(W)=2, p2(N)=3, p3(E)=0, p4(S)=1
      // Tie between p2(3) and p3(0) -> p3 should be ranked higher.
      final results2 = MahjongCalculator.calculate(inputs: [p1, p2, p3, p4], rule: defaultRule, config: const AppConfig(), startingOyaIndex: 2);
      expect(results2.firstWhere((r) => r.id == 3).finalPoint, (25 - 30) + 10); // p3 gets 3rd place uma? No, p3 is rank 1, p2 is rank 2.
      expect(results2.firstWhere((r) => r.id == 2).finalPoint, (25 - 30) - 10);
    });

    test('Single Daily Game Fee subtraction independent of games', () {
      // Create a scenario matching the user's explicit check: 13,200 Game Fee
      // Total profit before fee: +5,600
      // Game Fee divided by 4: -3,300
      // Expected Final: +2,300
      final config = const AppConfig(rate: 100, chipRate: 500, gameFee: 13200);
      
      // Let's create a result with 56 pt and 0 chips to get +5,600 balance natively.
      final p1 = PlayerInput(id: 1, score: 66000); // base +36, +20(uma), +20(oka) = +76? No wait.
      // Easiest is to mock the calculation steps and verify output money directly.
      // But we must run MahjongCalculator.calculate.
      // rule: 100 yen per 1 pt. 5600 yen profit = 56 pt final point.
      // Score to get 56 finalPoint: 
      // 56 = ((score - 30000)/1000) + uma(10 or 20 or 30) + oka(20)
      // Let Top get 56 pt: uma=20, oka=20 => 40. => basePoint = 16 => score = 46000.
      final pTop = PlayerInput(id: 1, score: 46000); 
      final p2 = PlayerInput(id: 2, score: 24000); // 24000 -> -6 + 10 = +4
      final p3 = PlayerInput(id: 3, score: 20000); // 20000 -> -10 - 10 = -20
      final p4 = PlayerInput(id: 4, score: 10000); // 10000 -> -20 - 20 = -40
      
      final results = MahjongCalculator.calculate(inputs: [pTop, p2, p3, p4], rule: defaultRule, config: config);
      
      // Top FinalPoint = 16 + 20 + 20 = 56.
      // Money Before Fee: 56 * 100 = 5600.
      // GameFee Deduction: 13200 / 4 = 3300.
      // 5600 - 3300 = 2300!
      expect(results.firstWhere((r) => r.id == 1).money, 2300);
    });

  });
}

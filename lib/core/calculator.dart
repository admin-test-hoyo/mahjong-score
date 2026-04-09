import 'models/app_config.dart';

class MahjongRule {
  final int rate;
  final int chipRate;
  final int returnScore;
  final List<int> uma;
  final int oka;
  final int tobiPrize;
  final int yakumanRonPrize;
  final int yakumanTsumoPrize;
  final int yakumanPaoPrize;
  final int totalFee;

  const MahjongRule({
    this.rate = 50,
    this.chipRate = 100,
    this.returnScore = 30000,
    this.uma = const [20, 10, -10, -20],
    this.oka = 20,
    this.tobiPrize = 10,
    this.yakumanRonPrize = 10,
    this.yakumanTsumoPrize = 15,
    this.yakumanPaoPrize = 15,
    this.totalFee = 0,
  });

  MahjongRule copyWith({
    int? rate,
    int? chipRate,
    int? returnScore,
    List<int>? uma,
    int? oka,
    int? tobiPrize,
    int? yakumanRonPrize,
    int? yakumanTsumoPrize,
    int? yakumanPaoPrize,
    int? totalFee,
  }) {
    return MahjongRule(
      rate: rate ?? this.rate,
      chipRate: chipRate ?? this.chipRate,
      returnScore: returnScore ?? this.returnScore,
      uma: uma ?? this.uma,
      oka: oka ?? this.oka,
      tobiPrize: tobiPrize ?? this.tobiPrize,
      yakumanRonPrize: yakumanRonPrize ?? this.yakumanRonPrize,
      yakumanTsumoPrize: yakumanTsumoPrize ?? this.yakumanTsumoPrize,
      yakumanPaoPrize: yakumanPaoPrize ?? this.yakumanPaoPrize,
      totalFee: totalFee ?? this.totalFee,
    );
  }

  Map<String, dynamic> toJson() => {
    'rate': rate,
    'chipRate': chipRate,
    'returnScore': returnScore,
    'uma': uma,
    'oka': oka,
    'tobiPrize': tobiPrize,
    'yakumanRonPrize': yakumanRonPrize,
    'yakumanTsumoPrize': yakumanTsumoPrize,
    'yakumanPaoPrize': yakumanPaoPrize,
    'totalFee': totalFee,
  };

  factory MahjongRule.fromJson(Map<String, dynamic> json) {
    return MahjongRule(
      rate: json['rate'] as int? ?? 50,
      chipRate: json['chipRate'] as int? ?? 100,
      returnScore: json['returnScore'] as int? ?? 30000,
      uma: (json['uma'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [20, 10, -10, -20],
      oka: json['oka'] as int? ?? 20,
      tobiPrize: json['tobiPrize'] as int? ?? 10,
      yakumanRonPrize: json['yakumanRonPrize'] as int? ?? 10,
      yakumanTsumoPrize: json['yakumanTsumoPrize'] as int? ?? 15,
      yakumanPaoPrize: json['yakumanPaoPrize'] as int? ?? 15,
      totalFee: json['totalFee'] as int? ?? 0,
    );
  }
}

enum SpecialPrizeType {
  none,
  tobi,
  yakumanRon,
  yakumanTsumo,
  yakumanPao,
}

class PlayerInput {
  final int id;
  final int score;
  final int chip;
  final int tobiPt;
  final int yakumanPt;
  final int? blownByPlayerId;

  const PlayerInput({
    required this.id,
    this.score = 0,
    this.chip = 0,
    this.tobiPt = 0,
    this.yakumanPt = 0,
    this.blownByPlayerId,
  });

  PlayerInput copyWith({
    int? id,
    int? score,
    int? chip,
    int? tobiPt,
    int? yakumanPt,
    int? blownByPlayerId,
    bool clearBlownBy = false,
  }) {
    return PlayerInput(
      id: id ?? this.id,
      score: score ?? this.score,
      chip: chip ?? this.chip,
      tobiPt: tobiPt ?? this.tobiPt,
      yakumanPt: yakumanPt ?? this.yakumanPt,
      blownByPlayerId: clearBlownBy ? null : (blownByPlayerId ?? this.blownByPlayerId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'score': score,
    'chip': chip,
    'tobiPt': tobiPt,
    'yakumanPt': yakumanPt,
    'blownByPlayerId': blownByPlayerId,
  };

  factory PlayerInput.fromJson(Map<String, dynamic> json) {
    return PlayerInput(
      id: json['id'] as int,
      score: json['score'] as int? ?? 0,
      chip: json['chip'] as int? ?? 0,
      tobiPt: json['tobiPt'] as int? ?? 0,
      yakumanPt: json['yakumanPt'] as int? ?? 0,
      blownByPlayerId: json['blownByPlayerId'] as int?,
    );
  }
}

class PlayerResult {
  final int id;
  final double basePoint;
  final int roundedPoint;
  final int finalPoint;
  final int money;

  const PlayerResult({
    required this.id,
    required this.basePoint,
    required this.roundedPoint,
    required this.finalPoint,
    required this.money,
  });

  PlayerResult copyWith({
    int? id,
    double? basePoint,
    int? roundedPoint,
    int? finalPoint,
    int? money,
  }) {
    return PlayerResult(
      id: id ?? this.id,
      basePoint: basePoint ?? this.basePoint,
      roundedPoint: roundedPoint ?? this.roundedPoint,
      finalPoint: finalPoint ?? this.finalPoint,
      money: money ?? this.money,
    );
  }
}

/// 麻雀収支計算エンジン
class MahjongCalculator {
  /// 3人の素点から4人目の素点を自動計算する
  static int calculateMissingScore(List<int> threeScores) {
    if (threeScores.length != 3) {
      throw ArgumentError('Precisely 3 scores are required.');
    }
    final sum = threeScores.fold(0, (prev, curr) => prev + curr);
    return 100000 - sum;
  }

  static int _roundGoshaRokunyu(double value) {
    // 浮動小数点誤差を防ぐため、10倍して四捨五入した整数を基準にする
    final int scaled = (value * 10).round();
    final bool isNegative = scaled < 0;
    final int absScaled = scaled.abs();
    
    final int integerPart = absScaled ~/ 10;
    final int fractionalPart = absScaled % 10;
    
    int roundedAbs = integerPart;
    if (fractionalPart >= 6) {
      roundedAbs += 1;
    }
    
    return isNegative ? -roundedAbs : roundedAbs;
  }
  
  /// 全員の計算を実行する
  static List<PlayerResult> calculate({
    required List<PlayerInput> inputs,
    required MahjongRule rule,
    required AppConfig config,
    int startingOyaIndex = 0,
  }) {
    const expectedPlayers = 4;
    if (inputs.length != expectedPlayers) {
      throw ArgumentError('There must be exactly $expectedPlayers players.');
    }

    // 順位付け (スコアの降順でソート。同点の場合は起家からの順番(priority)でソート)
    final sortedInputs = List<PlayerInput>.from(inputs)
      ..sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        
        // 同点時のTie-break: 優先度が低い（数値が小さい）方が上位。
        // priority = (playerIndex - startingOyaIndex + 4) % 4
        // ※ player.id は 1〜4 なので、index は id - 1
        final priorityA = ((a.id - 1) - startingOyaIndex + 4) % 4;
        final priorityB = ((b.id - 1) - startingOyaIndex + 4) % 4;
        return priorityA.compareTo(priorityB);
      });
      
    final results = <PlayerResult>[];
    
    // スコア合計チェック
    final totalScore = inputs.fold(0, (sum, p) => sum + p.score);
    if (totalScore != config.targetTotalScore) {
      throw ArgumentError('Total score must be exactly ${config.targetTotalScore}.');
    }

    // Tobi Points Zero-Sum Validation
    final totalTobi = inputs.fold(0, (sum, p) => sum + p.tobiPt);
    if (totalTobi != 0) {
      throw ArgumentError('The sum of tobiPt across all players must be exactly 0 (current sum: $totalTobi).');
    }

    // Yakuman Points Zero-Sum Validation
    final totalYakuman = inputs.fold(0, (sum, p) => sum + p.yakumanPt);
    if (totalYakuman != 0) {
      throw ArgumentError('The sum of yakumanPt across all players must be exactly 0 (current sum: $totalYakuman).');
    }

    for (int i = 0; i < expectedPlayers; i++) {
      final player = sortedInputs[i];
      final rank = i; // 0=トップ, 1=2着, 2=3着, (3=ラス)
      
      // 1. ベースポイントの算出（(素点 - 返し点) / 1000）
      final basePoint = (player.score - rule.returnScore) / 1000.0;
      
      // 2. 五捨六入による端数処理
      int roundedPoint = _roundGoshaRokunyu(basePoint);
      
      // 3. ウマ・オカ・特殊賞の加算
      int finalPoint = roundedPoint + rule.uma[rank] + player.tobiPt + player.yakumanPt;
      
      // オカはトップ(rank 0)にのみ付与
      if (rank == 0) {
        finalPoint += rule.oka;
      }
      
      // 4. ポイント合計を調整（トップの丸め誤差吸収）
      // 四人全員のポイントが±0になるように、トップのポイントを逆算調整するケースがあるが、
      // 厳密な五捨六入の場合、合計が常に0になるとは限らない。
      // 麻雀の一般的な慣例として、トップのポイントで帳尻を合わせる。
      
      results.add(PlayerResult(
        id: player.id,
        basePoint: basePoint,
        roundedPoint: roundedPoint,
        finalPoint: finalPoint,
        money: 0, // あとで計算
      ));
    }
    
    // 帳尻合わせ（トップが全責任を負う）
    final totalRounded = results.fold(0, (sum, r) => sum + r.finalPoint);
    if (totalRounded != 0) {
      // トップ(sortedInputs[0].id)のfinalPointから合計のブレ分を引く
      final topIndex = results.indexWhere((r) => r.id == sortedInputs[0].id);
      final currentTop = results[topIndex];
      results[topIndex] = currentTop.copyWith(finalPoint: currentTop.finalPoint - totalRounded);
    }
    
    // 5. 金銭換算 (Strict Formula Implementation)
    // 厳守：収支（円） = (ポイント × レート) + (チップ数 × チップ単価)
    // 厳守：場代込（円） = 収支 - (場代 / 4)
    final finalResults = results.map((r) {
      final input = inputs.firstWhere((i) => i.id == r.id);
      
      final income = (r.finalPoint * config.rate) + (input.chip * config.chipRate);
      
      // ユーザー指示：場代はセッション合計で1回だけ引く。ここでは引かない。
      return r.copyWith(money: income.round());
    }).toList();
    
    // ID順に戻して返す
    finalResults.sort((a, b) => a.id.compareTo(b.id));
    return finalResults;
  }
}

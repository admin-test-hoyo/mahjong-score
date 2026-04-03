class AppConfig {
  final double rate;
  final int chipRate;
  final int gameFee;
  final bool roundingTenYen;
  final String umaText;
  final int oka;
  final bool isThreePlayer;
  final int targetTotalScore;
  final int startingPoints;
  final int tobiPrize;
  final int yakumanPrize;

  const AppConfig({
    this.rate = 100.0,
    this.chipRate = 100,
    this.gameFee = 0,
    this.roundingTenYen = true,
    this.umaText = '10-30',
    this.oka = 20,
    this.isThreePlayer = false,
    this.targetTotalScore = 100000,
    this.startingPoints = 25000,
    this.tobiPrize = 10,
    this.yakumanPrize = 10,
  });

  AppConfig copyWith({
    double? rate,
    int? chipRate,
    int? gameFee,
    bool? roundingTenYen,
    String? umaText,
    int? oka,
    bool? isThreePlayer,
    int? targetTotalScore,
    int? startingPoints,
    int? tobiPrize,
    int? yakumanPrize,
  }) {
    return AppConfig(
      rate: rate ?? this.rate,
      chipRate: chipRate ?? this.chipRate,
      gameFee: gameFee ?? this.gameFee,
      roundingTenYen: roundingTenYen ?? this.roundingTenYen,
      umaText: umaText ?? this.umaText,
      oka: oka ?? this.oka,
      isThreePlayer: isThreePlayer ?? this.isThreePlayer,
      targetTotalScore: targetTotalScore ?? this.targetTotalScore,
      startingPoints: startingPoints ?? this.startingPoints,
      tobiPrize: tobiPrize ?? this.tobiPrize,
      yakumanPrize: yakumanPrize ?? this.yakumanPrize,
    );
  }

  Map<String, dynamic> toJson() => {
    'rate': rate,
    'chipRate': chipRate,
    'gameFee': gameFee,
    'roundingTenYen': roundingTenYen,
    'umaText': umaText,
    'oka': oka,
    'isThreePlayer': isThreePlayer,
    'targetTotalScore': targetTotalScore,
    'startingPoints': startingPoints,
    'tobiPrize': tobiPrize,
    'yakumanPrize': yakumanPrize,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      rate: (json['rate'] as num?)?.toDouble() ?? 100.0,
      chipRate: json['chipRate'] as int? ?? 100,
      gameFee: json['gameFee'] as int? ?? 0,
      roundingTenYen: json['roundingTenYen'] as bool? ?? true,
      umaText: json['umaText'] as String? ?? '10-30',
      oka: json['oka'] as int? ?? 20,
      isThreePlayer: json['isThreePlayer'] as bool? ?? false,
      targetTotalScore: json['targetTotalScore'] as int? ?? 100000,
      startingPoints: json['startingPoints'] as int? ?? 25000,
      tobiPrize: json['tobiPrize'] as int? ?? 10,
      yakumanPrize: json['yakumanPrize'] as int? ?? 10,
    );
  }
}

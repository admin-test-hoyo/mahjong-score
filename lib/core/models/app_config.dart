class AppConfig {
  final double rate;
  final int chipRate;
  final int gameFee;
  final bool roundingTenYen;
  final String umaText;
  final int oka;

  const AppConfig({
    this.rate = 100.0,
    this.chipRate = 100,
    this.gameFee = 0,
    this.roundingTenYen = true,
    this.umaText = '10-30',
    this.oka = 20,
  });

  AppConfig copyWith({
    double? rate,
    int? chipRate,
    int? gameFee,
    bool? roundingTenYen,
    String? umaText,
    int? oka,
  }) {
    return AppConfig(
      rate: rate ?? this.rate,
      chipRate: chipRate ?? this.chipRate,
      gameFee: gameFee ?? this.gameFee,
      roundingTenYen: roundingTenYen ?? this.roundingTenYen,
      umaText: umaText ?? this.umaText,
      oka: oka ?? this.oka,
    );
  }
}

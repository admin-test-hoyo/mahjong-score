class MahjongCalculator {
  /// 収支計算の統一ロジック
  /// Formula: (Total Pt * rate) + (Total Chips * chipRate) - (Fee / playerCount)
  /// 全て引数で渡されたローカル設定(Session Config)に基づいて計算すること。
  static int calculateMoney({
    required int totalPt,
    required double rate,
    required int totalChips,
    required int chipRate,
    required double totalFee,
    int playerCount = 4,
  }) {
    final double ptIncome = totalPt * rate;
    final double chipIncome = totalChips * chipRate.toDouble();
    final double individualFee = totalFee / playerCount;
    
    // (Pt収支 + チップ収支 - 一人あたりの場代)
    return (ptIncome + chipIncome - individualFee).round();
  }
}

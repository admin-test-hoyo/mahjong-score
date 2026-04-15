import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F1A),
      appBar: AppBar(
        title: const Text('ヘルプ / 使い方'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00FFC2), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildHelpSection(
            context,
            icon: Icons.explore_outlined,
            title: '1. アプリの構成とナビゲーション',
            content: 'スコア計算（Calc）: 対局結果の入力とPt・収支の算出を行います。\n\n'
                '対局履歴（History）: 過去データの閲覧、特定グループでの絞り込み、CSV出力を行います。\n\n'
                '成績統計（Stats）: 蓄積データから平均順位や収支推移を分析します。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.functions,
            title: '2. ルール設定と計算ロジック',
            content: '原点と返し点: 設定された配給原点と返し点に基づき、トップ賞（オカ）を自動算出します。\n\n'
                '順位馬（ウマ）: 指定された順位Pt授受（10-30等）が、最終的なPtに反映されます。\n\n'
                '特殊加算（トビ・役満賞）: 設定されたトビ賞や役満祝儀は、各プレイヤーの最終Ptおよび収支に直接加算・減算されます。\n\n'
                '検算機能（合計欄）: 入力画面下部の「合計」は、4人の合計点が100,000点、チップ合計が0枚、Pt合計が理論値と一致しているかをリアルタイムで判定します。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.edit_note_outlined,
            title: '3. 対局記録の操作手順',
            content: 'トビ賞の入力: 飛ばされたプレイヤーのアイコンを選択し、続けて「誰に飛ばされたか」を選択します。これにより設定されたトビ賞がPtに反映されます。\n\n'
                '役満賞の入力: 役満を和了したプレイヤーのアイコンを選択し、「ツモあがり」か「放銃者」を選択します。\n\n'
                '計算の仕組み: アプリ設定で指定した「ウマ・オカ・各種祝儀」のPtは、スコア入力時にリアルタイムで計算され、最終的なPt・収支に自動で反映されます。\n\n'
                'クリーンアイコン (リセット): 入力中のスコアイメージを一括消去し、初期状態に戻します。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.settings_suggest_outlined,
            title: '4. データ管理と保守',
            content: 'グループフィルタ: 履歴画面のチップを選択し、特定のメンバー構成での戦績のみを抽出・比較できます。\n\n'
                'CSVエクスポート: 表示中のデータをCSV形式で出力可能です。Excel等での詳細なポートフォリオ分析に活用いただけます。\n\n'
                'バックアップと移行: 設定画面より全データをJSON形式で書き出し/読み込み可能です。機種変更時の移行やデータの保護にご利用ください。\n\n'
                'クリーンアップ: 蓄積された全データをリセットし、初期状態に戻すことができます。\n\n'
                'スコアの修正: 履歴一覧から対局を選択し、アクションメニューの「詳細を見る」または編集ボタンから、点数・チップ・プレイヤー名の修正が可能です。保存後、Ptおよび収支は新しいルール・数値に基づいて即座に再計算されます。',
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Ver 2.2.9',
              style: GoogleFonts.notoSansJp(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHelpSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    bool isImportant = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isImportant 
              ? Colors.orangeAccent.withValues(alpha: 0.3) 
              : Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: isImportant ? Colors.orangeAccent : const Color(0xFF00FFC2),
          iconColor: isImportant ? Colors.orangeAccent : const Color(0xFF00FFC2),
          leading: Icon(
            icon, 
            color: isImportant ? Colors.orangeAccent : const Color(0xFF00FFC2),
            size: 24,
          ),
          title: Text(
            title,
            style: GoogleFonts.notoSansJp(
              color: isImportant ? Colors.orangeAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 4),
              child: Text(
                content,
                style: GoogleFonts.notoSansJp(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

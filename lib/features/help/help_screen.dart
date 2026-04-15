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
            title: '1. アプリの基本構成とナビゲーション',
            content: 'スコア計算（Calc）: 対局結果の入力とPt・収支の算出を行います。\n\n'
                '対局履歴（History）: 過去データの閲覧、特定グループでの絞り込み、CSV出力を行います。\n\n'
                '成績統計（Stats）: 蓄積データから平均順位や収支推移を分析します。\n\n'
                'リアルタイム計算: 設定画面で指定した「配給原点・返し点・ウマ・各種祝儀」が、スコア入力時にリアルタイムで最終Ptおよび収支に反映される仕組みとなっています。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.edit_note_outlined,
            title: '2. 対局の記録（操作ガイド）',
            content: '座順: メンバーを選択した順番で「東・南・西・北」として扱われます。\n\n'
                '自動補完: 3名分の点数を入力すると、100,000点から逆算して4名目の点数が自動補完されます。\n\n'
                'チップ: 現場での現物確認のため、4名全員分のチップ枚数は手入力が必要となります。\n\n'
                'トビ賞(箱下)入力: 飛ばされたプレイヤーのアイコンを選択し、続けて「誰に飛ばされたか」を選択します。これにより設定されたトビ賞が精算に反映されます。\n\n'
                '役満賞入力: 役満を和了したプレイヤーのアイコンを選択し、「ツモあがり」か「放銃者」を選択します。\n\n'
                'クリーン機能: 画面上部のゴミ箱アイコンで、現在入力中のスコア・チップを一括リセット（初期化）できます。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.history,
            title: '3. 履歴の管理と修正',
            content: 'グループフィルタ: 履歴画面上のチップを選択することで、特定のメンバーグループでの戦績のみに絞り込めます。\n\n'
                '連動型CSVエクスポート: 現在表示・絞り込み中の内容をそのままCSV形式で出力可能です。Excel等での詳細な分析に活用いただけます。\n\n'
                'スコアの修正: 履歴一覧から対局を選択し、アクションメニューの「詳細を見る」または直接の編集ボタンから、後から全ての数値（点数・チップ・プレイヤー名）を修正して再計算させることが可能です。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.settings_suggest_outlined,
            title: '4. データ保守とシステム',
            content: '端末内保存: アプリの記録はすべて端末内部（SQLite）に保存され、オフラインでも安全に利用できます。\n\n'
                'バックアップ・復元 (機種変更対応): 設定メニューより全データをJSON形式で外部保存（エクスポート）、および復元（インポート）可能です。\n\n'
                'クリーンアップ: 指定された期間分、あるいは全データを端末から一括削除し、初期状態に戻すことができます。',
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Ver 2.3.0',
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

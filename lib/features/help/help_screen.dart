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
            icon: Icons.play_circle_outline,
            title: '対局の始め方とグループについて',
            content: '本アプリでは、まず「グループ管理」タブで一緒に打つ頻度の高いメンバーを事前に登録することをお勧めします。\n\n'
                'グループを作成してメンバーを追加しておけば、「スコア計算」画面の右上にある「メンバー選択」ボタンから、ワンタップで対局メンバーを呼び出すことができます。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.person_add_outlined,
            title: 'ゲスト参戦（助っ人）について',
            content: '普段のグループに登録されていないメンバーが参加する場合は、メンバー選択モーダルの最上部にある「全員から選択」を使用してください。\n\n'
                '過去に対局したことのある全メンバーから選択できるほか、リストにない新しい名前を直接編集して、ゲストとして参加させることが可能です。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.analytics_outlined,
            title: '統計・分析について',
            content: '保存された対局記録は、プレイヤー名ごとに自動集計されます。\n\n'
                '「統計・分析」タブでは、通算成績、平均順位、1位率、連対率といった実力を示す指標を様々な角度から確認できます。グループ絞り込み機能を併用することで、特定の対局集団における詳細な戦績を把握できます。',
          ),
          _buildHelpSection(
            context,
            icon: Icons.warning_amber_rounded,
            title: 'データの保存について【重要】',
            isImportant: true,
            content: '本アプリはオンラインサーバーではなく、お使いの端末（ブラウザのローカルストレージやアプリ内データベース）に直接データを保存する仕様です。\n\n'
                'そのため、ブラウザのキャッシュ削除やシークレットモードでの利用、端末の初期化などを行うとデータが完全に消失します。\n\n'
                '万が一の事態に備え、ドロワーメニューにある「バックアップ保存（JSON書き出し）」機能を活用し、定期的にデータを保存しておくことを強くお勧めします。',
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Ver 2.1.5',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
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
            style: TextStyle(
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
                style: const TextStyle(
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

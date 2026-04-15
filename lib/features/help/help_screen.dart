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
            title: '対局の記録（スコア入力）',
            content: 'メンバー選択について：\n\n'
                '座順の自動設定: メンバーを選択した順番（1番目、2番目…）が、そのまま対局の座順（東、南、西、北）として自動的に割り当てられます。起家から順番にタップしてください。\n\n'
                'グループのロック: 選択画面を開く際に指定したグループのメンバーのみが表示されます。他のグループのメンバーを混在させることはできません。',
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
            title: '履歴の確認と分析（NEW）',
            content: 'データのフィルタリング: 履歴画面の上部にあるチップをタップすると、特定のグループ（いつめん等）の対局のみを瞬時に絞り込んで表示できます。\n\n'
                '履歴の編集: 各履歴をタップ（またはアクションメニューを開く）すると、対局日や所属グループを後から修正できます。\n\n'
                'CSVエクスポート: 画面右上のダウンロードアイコンから、現在表示されている（フィルタリングされた）履歴データをCSV形式で書き出せます。出力データには各プレイヤーの順位・Pt・チップ・収支がすべて含まれており、Excel等での高度な分析に最適です。',
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
              'Ver 2.2.5',
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

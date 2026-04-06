class SavedGame {
  final int? id;
  final String type; // '3-player' / '4-player'
  final DateTime date;
  final int? groupId;
  final List<String> playerNames;
  final List<int> scores;
  final List<int> points; // Final Pt
  final List<int> chips;  // Final Chip money or just count? User said 'p1_ch'
  final List<bool> tobis;
  final List<int> ranks;

  SavedGame({
    this.id,
    required this.type,
    required this.date,
    this.groupId,
    required this.playerNames,
    required this.scores,
    required this.points,
    required this.chips,
    required this.tobis,
    required this.ranks,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'date': date.toIso8601String(),
      'group_id': groupId,
      'p1_name': playerNames[0],
      'p2_name': playerNames[1],
      'p3_name': playerNames[2],
      'p4_name': playerNames.length > 3 ? playerNames[3] : '',
      'p1_score': scores[0],
      'p2_score': scores[1],
      'p3_score': scores[2],
      'p4_score': scores.length > 3 ? scores[3] : 0,
      'p1_pt': points[0],
      'p2_pt': points[1],
      'p3_pt': points[2],
      'p4_pt': points.length > 3 ? points[3] : 0,
      'p1_ch': chips[0],
      'p2_ch': chips[1],
      'p3_ch': chips[2],
      'p4_ch': chips.length > 3 ? chips[3] : 0,
      'p1_tobi': tobis[0] ? 1 : 0,
      'p2_tobi': tobis[1] ? 1 : 0,
      'p3_tobi': tobis[2] ? 1 : 0,
      'p4_tobi': (tobis.length > 3 && tobis[3]) ? 1 : 0,
      'p1_rank': ranks[0],
      'p2_rank': ranks[1],
      'p3_rank': ranks[2],
      'p4_rank': ranks.length > 3 ? ranks[3] : 4,
    };
  }

  factory SavedGame.fromMap(Map<String, dynamic> map) {
    return SavedGame(
      id: map['id'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      groupId: map['group_id'],
      playerNames: [
        map['p1_name'] ?? '',
        map['p2_name'] ?? '',
        map['p3_name'] ?? '',
        if (map['type'] == '4-player') map['p4_name'] ?? '',
      ],
      scores: [
        map['p1_score'] ?? 0,
        map['p2_score'] ?? 0,
        map['p3_score'] ?? 0,
        if (map['type'] == '4-player') map['p4_score'] ?? 0,
      ],
      points: [
        map['p1_pt'] ?? 0,
        map['p2_pt'] ?? 0,
        map['p3_pt'] ?? 0,
        if (map['type'] == '4-player') map['p4_pt'] ?? 0,
      ],
      chips: [
        map['p1_ch'] ?? 0,
        map['p2_ch'] ?? 0,
        map['p3_ch'] ?? 0,
        if (map['type'] == '4-player') map['p4_ch'] ?? 0,
      ],
      tobis: [
        map['p1_tobi'] == 1,
        map['p2_tobi'] == 1,
        map['p3_tobi'] == 1,
        if (map['type'] == '4-player') map['p4_tobi'] == 1,
      ],
      ranks: [
        map['p1_rank'] ?? 1,
        map['p2_rank'] ?? 2,
        map['p3_rank'] ?? 3,
        if (map['type'] == '4-player') map['p4_rank'] ?? 4,
      ],
    );
  }
}

class Group {
  final int? id;
  final String name;

  Group({this.id, required this.name});
}

class GroupMember {
  final int? id;
  final int groupId;
  final String name;

  GroupMember({this.id, required this.groupId, required this.name});
}

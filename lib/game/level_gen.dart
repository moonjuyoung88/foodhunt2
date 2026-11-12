import 'dart:math';

import 'engine.dart';
import 'models.dart';

/// 레벨별 난이도 설정.
class Difficulty {
  const Difficulty({
    required this.columns,
    required this.openLimit,
    required this.mergeChance,
    required this.mysteryChance,
    this.maxRun = 1,
  });

  /// 대기 줄 수.
  final int columns;

  /// 풀이 도중 대기석에 동시에 앉아 있어야 하는 냠냠이 수의 상한.
  final int openLimit;

  /// 새 냠냠이가 한 바퀴에 먹을 수 있는 양보다 더 많이 들고 나올 확률.
  /// (남은 양은 대기석에서 기다렸다가, 자기 색이 다시 드러나면 마저 먹어야 합니다.)
  final double mergeChance;
  final double mysteryChance;

  /// 한 줄에 연달아 담는 최대 마릿수.
  final int maxRun;

  static Difficulty forLevel(int level) {
    if (level <= 3) {
      return const Difficulty(
        columns: 2,
        openLimit: 0,
        mergeChance: 0,
        mysteryChance: 0,
      );
    }
    if (level <= 8) {
      return const Difficulty(
        columns: 3,
        openLimit: 1,
        mergeChance: 0.4,
        mysteryChance: 0,
        maxRun: 2,
      );
    }
    if (level <= 20) {
      return const Difficulty(
        columns: 3,
        openLimit: 2,
        mergeChance: 0.55,
        mysteryChance: 0,
        maxRun: 3,
      );
    }
    if (level <= 45) {
      return const Difficulty(
        columns: 3,
        openLimit: 3,
        mergeChance: 0.7,
        mysteryChance: 0.08,
        maxRun: 4,
      );
    }
    if (level <= 90) {
      return const Difficulty(
        columns: 4,
        openLimit: 3,
        mergeChance: 0.8,
        mysteryChance: 0.12,
        maxRun: 5,
      );
    }
    return Difficulty(
      columns: 4,
      openLimit: 4,
      mergeChance: 0.95,
      mysteryChance: min(0.25, 0.12 + (level - 90) * 0.0006),
      maxRun: 6,
    );
  }
}

class _Plan {
  _Plan(this.id, this.color, this.left);
  final int id;
  final int color;
  int left;
}

/// 테마 그림에서 반드시 풀리는 레벨을 만듭니다.
///
/// 실제 규칙 그대로 "한 번에 하나씩 보내는" 플레이를 가상으로 진행하면서 냠냠이를 만들어 냅니다.
/// - 새 냠냠이는 지금 드러난 색 중에서 고르고, 식사량은 그 색의 남은 블록 수를 넘지 않게 정합니다.
/// - 일부는 한 바퀴에 먹을 수 있는 양보다 많이 들려 보냅니다. 남은 양은 대기석에서 기다리다가
///   자기 색이 다시 드러났을 때 재출발해 먹습니다. 이 "대기석 관리"가 퍼즐의 핵심입니다.
/// - 가상 플레이 동안 대기석 인원이 [Difficulty.openLimit]을 넘지 않으므로, 기록된 출발 순서가
///   곧 대기석이 넘치지 않는 풀이입니다.
/// - 줄에는 처음 출발한 순서를 지키며 나눠 담아, 풀이에 필요한 냠냠이가 항상 맨 앞에 있게 합니다.
LevelDef generateLevel(int level, List<ArtTheme> themes) {
  final theme = themes[(level - 1) % themes.length];
  final round = (level - 1) ~/ themes.length;
  final diff = Difficulty.forLevel(level);
  final rng = Random(level * 7919 + round * 104729 + 17);

  final board = Board(theme.w, theme.h, theme.cells);
  final nColors = theme.palette.length;
  final uncommitted = List<int>.filled(nColors, 0);
  for (final c in theme.cells) {
    if (c >= 0) uncommitted[c]++;
  }
  // 냠냠이 한 마리의 기준 식사량: 레벨이 오를수록 마릿수가 늘어납니다.
  final targetCount = 12 + min(30, level * 0.3);
  final base = max(3.0, board.remaining / targetCount);

  // 대기석과 벨트 정원: 초반은 넉넉하고, 뒤로 갈수록 실수할 여유가 줄어듭니다.
  // 10레벨마다 대기석이 한 칸 더 적은 "매운맛" 판이 나옵니다.
  final hard = level > 40 && level % 10 == 0;
  final traySize = (level <= 20 ? 5 : 4) - (hard ? 1 : 0);
  final beltCap = level <= 20 ? 5 : (level <= 45 ? 4 : 3);

  final tray = <_Plan>[];
  final critters = <Critter>[];
  final solution = <int>[];
  var lastColor = -1;

  while (board.remaining > 0) {
    final eats = List<int>.generate(
      nColors,
      (c) => board.copy().runLap(c, 1 << 30),
    );
    final relaunch = [
      for (final p in tray)
        if (eats[p.color] > 0) p,
    ];
    final fresh = [
      for (var c = 0; c < nColors; c++)
        if (eats[c] > 0 && uncommitted[c] > 0) c,
    ];

    final anyLeft = uncommitted.any((u) => u > 0);
    if (relaunch.isNotEmpty && (!anyLeft || rng.nextDouble() < 0.25)) {
      // 대기석에서 재출발
      final p = relaunch[rng.nextInt(relaunch.length)];
      p.left -= board.runLap(p.color, p.left);
      if (p.left == 0) tray.remove(p);
      solution.add(p.id);
      lastColor = p.color;
      continue;
    }

    final room = tray.length < min(diff.openLimit, traySize);
    final int color;
    var ammo = (base * (0.6 + rng.nextDouble())).round();
    if (room && rng.nextDouble() < diff.mergeChance) {
      // 길막이: 아직 덜 드러난(또는 전혀 안 드러난) 색을 들고 나와 대기석에서 오래 기다려야 합니다.
      // 줄을 비우려면 먼저 보내 둘 수밖에 없어서, 대기석을 아껴 써야 하는 이유가 됩니다.
      final cands = [
        for (var c = 0; c < nColors; c++)
          if (uncommitted[c] > 0) c,
      ];
      var total = 0.0;
      final weights = [
        for (final c in cands)
          () {
            final w = 1.0 / (1 + eats[c]) * (c == lastColor ? 0.3 : 1.0);
            total += w;
            return w;
          }(),
      ];
      var r = rng.nextDouble() * total;
      var pick = cands.last;
      for (var i = 0; i < cands.length; i++) {
        r -= weights[i];
        if (r <= 0) {
          pick = cands[i];
          break;
        }
      }
      color = pick;
      ammo = min(ammo, uncommitted[color]);
      final rest = uncommitted[color] - ammo;
      if (rest > 0 && rest < 3) ammo += rest;
    } else {
      // 알뜰이: 지금 드러난 색 중에서 골라 한 바퀴에 깔끔하게 다 먹습니다.
      if (fresh.isEmpty) {
        // 드러난 색이 모두 대기석 냠냠이 몫이면 재출발로 넘어갑니다.
        final p = relaunch[rng.nextInt(relaunch.length)];
        p.left -= board.runLap(p.color, p.left);
        if (p.left == 0) tray.remove(p);
        solution.add(p.id);
        lastColor = p.color;
        continue;
      }
      var total = 0.0;
      final weights = [
        for (final c in fresh)
          () {
            final e = eats[c].toDouble();
            final w = e * e * (c == lastColor ? 0.3 : 1.0);
            total += w;
            return w;
          }(),
      ];
      var r = rng.nextDouble() * total;
      var pick = fresh.last;
      for (var i = 0; i < fresh.length; i++) {
        r -= weights[i];
        if (r <= 0) {
          pick = fresh[i];
          break;
        }
      }
      color = pick;
      final e = eats[color];
      ammo = min(min(ammo, e), uncommitted[color]);
      final rest = uncommitted[color] - ammo;
      if (rest > 0 && rest < 3 && ammo + rest <= e) ammo += rest;
    }
    if (ammo > 99) ammo = 99;

    uncommitted[color] -= ammo;
    final id = critters.length;
    critters.add(Critter(id: id, color: color, ammo: ammo));
    final left = ammo - board.runLap(color, ammo);
    if (left > 0) tray.add(_Plan(id, color, left));
    solution.add(id);
    lastColor = color;
  }

  // 줄 배치: 처음 출발한 순서를 지키며 나눠 담습니다 (풀이에 필요한 냠냠이가 항상 맨 앞에 있음).
  // 한 줄에 여러 마리를 연달아 담을수록 다른 줄 맨 앞에는 "한참 뒤에야 쓸모 있는" 냠냠이가
  // 서게 되어, 아무 줄이나 누르면 대기석이 금방 차고 순서를 읽어야 풀립니다.
  final columns = List.generate(diff.columns, (_) => <Critter>[]);
  final perColumn = (critters.length / diff.columns).ceil() + 1;
  var col = rng.nextInt(diff.columns);
  var run = 0;
  for (final k in critters) {
    if (run <= 0 || columns[col].length >= perColumn) {
      final cands = [
        for (var i = 0; i < columns.length; i++)
          if (i != col && columns[i].length < perColumn) i,
      ];
      if (cands.isNotEmpty) col = cands[rng.nextInt(cands.length)];
      run = 1 + rng.nextInt(diff.maxRun);
    }
    run--;
    k.mystery =
        columns[col].isNotEmpty && rng.nextDouble() < diff.mysteryChance;
    columns[col].add(k);
  }

  return LevelDef(
    level: level,
    theme: theme,
    columns: columns,
    traySize: traySize,
    beltCap: beltCap,
    solution: solution,
  );
}

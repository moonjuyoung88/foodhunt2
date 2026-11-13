import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_nibblers/game/engine.dart';
import 'package:pixel_nibblers/game/level_gen.dart';
import 'package:pixel_nibblers/game/models.dart';

List<ArtTheme> loadThemes() {
  final j =
      jsonDecode(File('assets/art/themes.json').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final t in j['themes'] as List)
      ArtTheme.fromJson(t as Map<String, dynamic>),
  ];
}

/// 아무 생각 없이 마구 누르는 플레이. 이긴 비율을 돌려줍니다.
double spamWinRate(
  List<ArtTheme> themes, {
  required bool hard,
  int from = 100,
  int to = 360,
  int step = 13,
}) {
  var wins = 0, n = 0;
  for (var lv = from; lv <= to; lv += step) {
    for (var trial = 0; trial < 3; trial++) {
      final rng = Random(lv * 100 + trial);
      final e = GameEngine(generateLevel(lv, themes, hard: hard));
      var t = 0.0, next = 0.0;
      while (e.status == GameStatus.playing && t < 900) {
        e.update(1 / 30);
        t += 1 / 30;
        if (t >= next && e.canLaunch) {
          next = t + 0.35;
          final opts = <void Function()>[
            for (var c = 0; c < e.columns.length; c++)
              if (e.columns[c].isNotEmpty) () => e.tapColumn(c),
            for (var s = 0; s < e.tray.length; s++)
              if (e.tray[s] != null) () => e.tapTray(s),
          ];
          if (opts.isNotEmpty) opts[rng.nextInt(opts.length)]();
        }
      }
      n++;
      if (e.status == GameStatus.won) wins++;
    }
  }
  return wins / n;
}

void main() {
  final themes = loadThemes();
  final lastLevel = themes.length + 20;

  test('테마가 100개 이상이고 id가 겹치지 않는다', () {
    expect(themes.length, greaterThan(100));
    expect(themes.map((t) => t.id).toSet().length, themes.length);
    for (final t in themes) {
      expect(t.cells.length, t.w * t.h);
      expect(t.palette.length, greaterThanOrEqualTo(2));
    }
  });

  for (final hard in [false, true]) {
    final mode = hard ? '어려움' : '노멀';

    test('$mode: 모든 레벨의 식사량 합 = 색별 블록 수', () {
      for (var lv = 1; lv <= lastLevel; lv++) {
        final def = generateLevel(lv, themes, hard: hard);
        final need = <int, int>{};
        for (final c in def.theme.cells) {
          if (c >= 0) need[c] = (need[c] ?? 0) + 1;
        }
        final have = <int, int>{};
        for (final col in def.columns) {
          for (final k in col) {
            have[k.color] = (have[k.color] ?? 0) + k.ammo;
          }
        }
        expect(have, need, reason: 'level $lv');
        expect(def.sides, inInclusiveRange(1, 15), reason: 'level $lv');
        expect(def.hearts, hard ? 2 : 3);
      }
    });

    test('$mode: 모든 레벨이 풀린다 (대기석 안 넘치고 하트도 안 잃는 풀이 존재)', () {
      for (var lv = 1; lv <= lastLevel; lv++) {
        final def = generateLevel(lv, themes, hard: hard);
        final e = GameEngine(def);
        for (final id in def.solution) {
          if (e.status != GameStatus.playing) break;
          expect(e.launchById(id), isTrue, reason: 'level $lv: $id 출발 불가');
          var guard = 0;
          while (!e.idle &&
              e.status == GameStatus.playing &&
              guard++ < 100000) {
            e.update(1 / 60);
          }
        }
        expect(e.status, GameStatus.won, reason: 'level $lv');
        expect(e.hearts, def.hearts, reason: 'level $lv: 풀이가 하트를 잃음');
      }
    });
  }

  test('같은 레벨은 언제 만들어도 같은 배치가 나온다', () {
    for (final lv in [1, 50, 200]) {
      final a = generateLevel(lv, themes, hard: true);
      final b = generateLevel(lv, themes, hard: true);
      expect(a.solution, b.solution);
      expect(a.sides, b.sides);
    }
  });

  test('난이도: 마구 누르면 후반 레벨은 대부분 실패한다', () {
    final normal = spamWinRate(themes, hard: false);
    final hard = spamWinRate(themes, hard: true);
    // ignore: avoid_print
    print(
      '마구 누르기 승률 (레벨 100~360) 노멀 ${(normal * 100).round()}% / 어려움 ${(hard * 100).round()}%',
    );
    expect(normal, lessThan(0.45));
    expect(hard, lessThan(0.15));
    expect(hard, lessThan(normal));
    // 어려움 모드는 연습 구간이 없어 초반부터 어렵다
    final hardEarly = spamWinRate(themes, hard: true, from: 1, to: 30, step: 1);
    // ignore: avoid_print
    print('어려움 초반(레벨 1~30) 마구 누르기 승률 ${(hardEarly * 100).round()}%');
    expect(hardEarly, lessThan(0.2));
  });

  test('터널 면에서는 먹지 못한다', () {
    // 2x2 한 색 그림, 아래쪽 면만 열림
    final b = Board(2, 2, [0, 0, 0, 0], sides: Board.bottom);
    expect(b.runLap(0, 99), 2);
    expect(b.cells, [-1, -1, 0, 0].reversed.toList());
  });

  test('헛걸음하면 하트를 잃고, 다 잃으면 실패한다', () {
    final theme = ArtTheme(
      id: 't',
      cat: 'c',
      ko: 't',
      en: 't',
      w: 3,
      h: 3,
      palette: const [],
      // 가운데(1)가 0으로 둘러싸여 있어 1번 색은 처음엔 먹을 수 없음
      cells: [0, 0, 0, 0, 1, 0, 0, 0, 0],
    );
    final def = LevelDef(
      level: 1,
      theme: theme,
      columns: [
        [Critter(id: 0, color: 1, ammo: 1)],
        [Critter(id: 1, color: 0, ammo: 8)],
      ],
      traySize: 3,
      beltCap: 3,
      solution: const [1, 0],
      hearts: 1,
    );
    final e = GameEngine(def);
    e.tapColumn(0);
    for (var i = 0; i < 2000 && e.status == GameStatus.playing; i++) {
      e.update(1 / 60);
    }
    expect(e.status, GameStatus.failed);
    expect(e.failReason, FailReason.noHearts);
    expect(e.addHeart(), isTrue);
    expect(e.status, GameStatus.playing);
  });

  test('부스터: 대기석 비우기는 블록과 식사량의 균형을 유지한다', () {
    final def = generateLevel(30, themes);
    final e = GameEngine(def)..hearts = 999;
    for (var i = 0; i < 400 && e.status == GameStatus.playing; i++) {
      e.tapColumn(i % e.columns.length);
      for (var k = 0; k < 30; k++) {
        e.update(1 / 60);
      }
    }
    e.clearTray();
    var ammo = 0;
    for (final c in e.columns) {
      for (final k in c) {
        ammo += k.ammo;
      }
    }
    for (final b in e.belt) {
      ammo += b.critter.ammo;
    }
    for (final p in e.pending) {
      ammo += p.critter.ammo;
    }
    expect(e.tray.every((c) => c == null), isTrue);
    expect(ammo, e.board.remaining);
  });
}

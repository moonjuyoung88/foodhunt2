import 'dart:convert';
import 'dart:io';

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

void main() {
  final themes = loadThemes();

  test('테마가 100개 이상이고 id가 겹치지 않는다', () {
    expect(themes.length, greaterThan(100));
    expect(themes.map((t) => t.id).toSet().length, themes.length);
    for (final t in themes) {
      expect(t.cells.length, t.w * t.h);
      expect(t.palette.length, greaterThanOrEqualTo(2));
    }
  });

  test('모든 레벨: 식사량 합 = 색별 블록 수', () {
    for (var lv = 1; lv <= themes.length + 20; lv++) {
      final def = generateLevel(lv, themes);
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
    }
  });

  test('모든 레벨: 생성기 풀이를 실제 엔진으로 돌리면 대기석이 넘치지 않고 클리어된다', () {
    var maxCritters = 0;
    final counts = <int>[];
    for (var lv = 1; lv <= themes.length + 20; lv++) {
      final def = generateLevel(lv, themes);
      final e = GameEngine(def);
      var count = 0;
      for (final c in def.columns) {
        count += c.length;
      }
      if (count > maxCritters) maxCritters = count;
      counts.add(count);
      for (final id in def.solution) {
        if (e.status != GameStatus.playing) break;
        expect(e.launchById(id), isTrue, reason: 'level $lv: $id 출발 불가');
        var guard = 0;
        while (!e.idle && e.status == GameStatus.playing && guard++ < 100000) {
          e.update(1 / 60);
        }
      }
      expect(e.status, GameStatus.won, reason: 'level $lv');
    }
    // ignore: avoid_print
    print(
      'max critters: $maxCritters; by level: ${[for (var i = 0; i < counts.length; i += 15) counts[i]]}',
    );
  });

  test('부스터: 대기석 비우기는 균형을 유지한다', () {
    final def = generateLevel(30, themes);
    final e = GameEngine(def);
    // 일부러 아무거나 보내 대기석을 채운다
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

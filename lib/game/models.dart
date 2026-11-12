import 'dart:ui' show Color;

/// 한 장의 픽셀 그림(테마).
class ArtTheme {
  ArtTheme({
    required this.id,
    required this.cat,
    required this.ko,
    required this.en,
    required this.w,
    required this.h,
    required this.palette,
    required this.cells,
  });

  final String id;
  final String cat;
  final String ko;
  final String en;
  final int w;
  final int h;
  final List<Color> palette;

  /// 행 우선 색 인덱스. 빈 칸은 -1.
  final List<int> cells;

  factory ArtTheme.fromJson(Map<String, dynamic> j) {
    final rows = (j['rows'] as List).cast<String>();
    final cells = <int>[];
    for (final r in rows) {
      for (final c in r.codeUnits) {
        cells.add(c == 0x2e ? -1 : c - 0x61);
      }
    }
    return ArtTheme(
      id: j['id'] as String,
      cat: j['cat'] as String,
      ko: j['ko'] as String,
      en: j['en'] as String,
      w: j['w'] as int,
      h: j['h'] as int,
      palette: [
        for (final p in (j['pal'] as List).cast<String>())
          Color(0xFF000000 | int.parse(p, radix: 16)),
      ],
      cells: cells,
    );
  }
}

class ArtCategory {
  ArtCategory(this.id, this.ko, this.en);
  final String id;
  final String ko;
  final String en;
}

/// 벨트 위를 돌며 자기 색 블록을 먹는 꼬마 "냠냠이".
class Critter {
  Critter({
    required this.id,
    required this.color,
    required this.ammo,
    this.mystery = false,
  });

  final int id;
  final int color;
  int ammo;

  /// 줄 맨 앞에 설 때까지 색을 숨기는 깜짝 냠냠이.
  bool mystery;
}

class LevelDef {
  LevelDef({
    required this.level,
    required this.theme,
    required this.columns,
    required this.traySize,
    required this.beltCap,
    required this.solution,
  });

  final int level;
  final ArtTheme theme;

  /// 대기 줄. 각 줄의 0번이 맨 앞.
  final List<List<Critter>> columns;
  final int traySize;
  final int beltCap;

  /// 생성기가 보장하는 풀이: 순서대로 출발시킬 냠냠이 id.
  final List<int> solution;
}

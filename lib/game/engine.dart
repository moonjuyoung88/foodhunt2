import 'models.dart';

/// 그림 격자와 벨트 정류장 계산.
///
/// 벨트는 그림을 시계 방향으로 감쌉니다. 왼쪽 아래 모서리에서 출발해
/// 왼쪽 면(아래→위), 위쪽 면(왼→오), 오른쪽 면(위→아래), 아래쪽 면(오→왼)을 지납니다.
/// 정류장마다 그림 안쪽을 바라보고, 가장 바깥에 드러난 블록 하나만 먹을 수 있습니다.
class Board {
  Board(this.w, this.h, List<int> cells) : cells = List<int>.of(cells) {
    remaining = this.cells.where((c) => c >= 0).length;
  }

  final int w;
  final int h;
  final List<int> cells;
  late int remaining;

  int get stations => 2 * (w + h);

  Board copy() => Board(w, h, cells);

  /// 정류장 [s]에서 보이는 첫 블록의 인덱스. 없으면 -1.
  int targetAt(int s) {
    if (s < h) {
      final row = h - 1 - s;
      for (var x = 0; x < w; x++) {
        if (cells[row * w + x] >= 0) return row * w + x;
      }
    } else if (s < h + w) {
      final col = s - h;
      for (var y = 0; y < h; y++) {
        if (cells[y * w + col] >= 0) return y * w + col;
      }
    } else if (s < 2 * h + w) {
      final row = s - h - w;
      for (var x = w - 1; x >= 0; x--) {
        if (cells[row * w + x] >= 0) return row * w + x;
      }
    } else {
      final col = w - 1 - (s - 2 * h - w);
      for (var y = h - 1; y >= 0; y--) {
        if (cells[y * w + col] >= 0) return y * w + col;
      }
    }
    return -1;
  }

  void removeAt(int index) {
    if (cells[index] >= 0) {
      cells[index] = -1;
      remaining--;
    }
  }

  /// [color] 냠냠이가 [ammo]만큼 들고 한 바퀴 돌았을 때 먹는 양. 격자를 실제로 바꿉니다.
  int runLap(
    int color,
    int ammo, {
    void Function(int cell, int station)? onEat,
  }) {
    var eaten = 0;
    for (var s = 0; s < stations && eaten < ammo; s++) {
      final t = targetAt(s);
      if (t >= 0 && cells[t] == color) {
        removeAt(t);
        eaten++;
        onEat?.call(t, s);
      }
    }
    return eaten;
  }
}

/// 벨트 경로 기하. 단위는 "블록 한 칸".
class BeltGeometry {
  BeltGeometry(this.w, this.h);
  final int w;
  final int h;

  /// 그림과 벨트 중심선 사이 간격.
  static const double margin = 1.25;

  double get length => 2.0 * (w + h) + 8 * margin;

  /// 정류장 [s]를 지나는 지점까지의 이동 거리.
  double stationDistance(int s) {
    final side = s < h ? 0 : (s < h + w ? 1 : (s < 2 * h + w ? 2 : 3));
    return s + 0.5 + margin * (1 + 2 * side);
  }

  /// 이동 거리 [d]의 좌표 (그림 왼쪽 위가 원점).
  (double, double) positionAt(double d) {
    const m = margin;
    final a = h + 2 * m;
    final b = w + 2 * m;
    if (d < 0) return (-m, h + m - d);
    if (d < a) return (-m, h + m - d);
    d -= a;
    if (d < b) return (-m + d, -m);
    d -= b;
    if (d < a) return (w + m, -m + d);
    d -= a;
    if (d > b) d = b;
    return (w + m - d, h + m);
  }
}

enum GameStatus { playing, won, failed }

class BeltCritter {
  BeltCritter(this.critter);
  final Critter critter;
  double d = 0;
  int nextStation = 0;
}

class PendingCritter {
  PendingCritter(this.critter, this.wait);
  final Critter critter;
  double wait;
}

sealed class GameEvent {}

class EatEvent extends GameEvent {
  EatEvent(this.cell, this.color, this.station, this.critterId);
  final int cell;
  final int color;

  /// 먹은 정류장. 부스터로 지운 경우 -1.
  final int station;
  final int critterId;
}

class CritterFullEvent extends GameEvent {
  CritterFullEvent(this.critter, this.d);
  final Critter critter;
  final double d;
}

class ToTrayEvent extends GameEvent {
  ToTrayEvent(this.critter, this.slot);
  final Critter critter;
  final int slot;
}

class LaunchEvent extends GameEvent {
  LaunchEvent(this.critter, {this.fromColumn = -1, this.fromSlot = -1});
  final Critter critter;
  final int fromColumn;
  final int fromSlot;
}

class WinEvent extends GameEvent {}

class FailEvent extends GameEvent {}

/// 한 판의 규칙 전체. Flutter에 의존하지 않아 단위 테스트로 검증합니다.
class GameEngine {
  GameEngine(LevelDef def)
    : level = def,
      board = Board(def.theme.w, def.theme.h, def.theme.cells),
      geo = BeltGeometry(def.theme.w, def.theme.h),
      columns = [
        for (final c in def.columns)
          [
            for (final k in c)
              Critter(
                id: k.id,
                color: k.color,
                ammo: k.ammo,
                mystery: k.mystery,
              ),
          ],
      ],
      tray = List<Critter?>.filled(def.traySize, null, growable: true),
      beltCap = def.beltCap {
    _revealFronts();
  }

  final LevelDef level;
  final Board board;
  final BeltGeometry geo;
  final List<List<Critter>> columns;
  final List<Critter?> tray;
  final int beltCap;

  final List<BeltCritter> belt = [];
  final List<PendingCritter> pending = [];
  final List<GameEvent> events = [];

  /// 실패 순간 자리가 없어 넘친 냠냠이.
  Critter? overflow;
  GameStatus status = GameStatus.playing;
  int launches = 0;

  static const double enterDelay = 0.24;
  static const double gateGap = 1.7;

  /// 초당 이동 칸 수. 판 크기와 상관없이 한 바퀴가 비슷한 시간에 끝나게 합니다.
  double get speed {
    final v = geo.length / 5.2;
    return v < 9 ? 9 : v;
  }

  bool get canLaunch =>
      status == GameStatus.playing && belt.length + pending.length < beltCap;

  int get freeTraySlots => tray.where((c) => c == null).length;

  bool get idle => belt.isEmpty && pending.isEmpty;

  void _revealFronts() {
    for (final c in columns) {
      if (c.isNotEmpty) c.first.mystery = false;
    }
  }

  bool tapColumn(int col) {
    if (!canLaunch ||
        col < 0 ||
        col >= columns.length ||
        columns[col].isEmpty) {
      return false;
    }
    final c = columns[col].removeAt(0);
    _revealFronts();
    _launch(c, fromColumn: col);
    return true;
  }

  bool tapTray(int slot) {
    if (!canLaunch || slot < 0 || slot >= tray.length || tray[slot] == null) {
      return false;
    }
    final c = tray[slot]!;
    tray[slot] = null;
    _launch(c, fromSlot: slot);
    return true;
  }

  /// id로 출발 (테스트/자동 풀이용).
  bool launchById(int id) {
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].isNotEmpty && columns[i].first.id == id) {
        return tapColumn(i);
      }
    }
    for (var i = 0; i < tray.length; i++) {
      if (tray[i]?.id == id) return tapTray(i);
    }
    return false;
  }

  void _launch(Critter c, {int fromColumn = -1, int fromSlot = -1}) {
    launches++;
    pending.add(PendingCritter(c, enterDelay));
    events.add(LaunchEvent(c, fromColumn: fromColumn, fromSlot: fromSlot));
  }

  void update(double dt) {
    if (status != GameStatus.playing) return;
    // 출발 대기 → 벨트 입장 (앞 냠냠이와 간격 유지)
    for (final p in pending) {
      p.wait -= dt;
    }
    while (pending.isNotEmpty && pending.first.wait <= 0) {
      final clear = belt.every((b) => b.d >= gateGap);
      if (!clear) break;
      belt.add(BeltCritter(pending.removeAt(0).critter));
    }
    final v = speed;
    final done = <BeltCritter>[];
    for (final b in belt) {
      b.d += v * dt;
      while (b.nextStation < board.stations &&
          b.critter.ammo > 0 &&
          b.d >= geo.stationDistance(b.nextStation)) {
        final t = board.targetAt(b.nextStation);
        if (t >= 0 && board.cells[t] == b.critter.color) {
          board.removeAt(t);
          b.critter.ammo--;
          events.add(EatEvent(t, b.critter.color, b.nextStation, b.critter.id));
        }
        b.nextStation++;
      }
      if (b.critter.ammo <= 0) {
        done.add(b);
        events.add(CritterFullEvent(b.critter, b.d));
      } else if (b.d >= geo.length) {
        done.add(b);
        final slot = tray.indexOf(null);
        if (slot < 0) {
          overflow = b.critter;
          status = GameStatus.failed;
          events.add(FailEvent());
        } else {
          tray[slot] = b.critter;
          events.add(ToTrayEvent(b.critter, slot));
        }
      }
      if (status == GameStatus.failed) break;
    }
    belt.removeWhere(done.contains);
    _checkWin();
  }

  void _checkWin() {
    if (status == GameStatus.playing && board.remaining == 0) {
      status = GameStatus.won;
      events.add(WinEvent());
    }
  }

  /// 냠냠이 하나를 통째로 정리: 들고 있던 양만큼 같은 색 블록을 지웁니다.
  /// (남은 블록 수 = 남은 냠냠이 식사량 균형을 유지해 판이 막히지 않습니다.)
  void _zap(Critter c) {
    var guard = 0;
    while (c.ammo > 0 && guard++ < 200) {
      final eaten = board.runLap(
        c.color,
        c.ammo,
        onEat: (cell, _) => events.add(EatEvent(cell, c.color, -1, c.id)),
      );
      c.ammo -= eaten;
      if (eaten == 0) {
        final i = board.cells.indexOf(c.color);
        if (i < 0) break;
        board.removeAt(i);
        c.ammo--;
        events.add(EatEvent(i, c.color, -1, c.id));
      }
    }
    c.ammo = 0;
  }

  /// 부스터: 대기석(과 넘친 냠냠이)을 싹 비웁니다. 실패 상태면 이어서 진행됩니다.
  bool clearTray() {
    if (status == GameStatus.won) return false;
    var any = false;
    for (var i = 0; i < tray.length; i++) {
      final c = tray[i];
      if (c != null) {
        _zap(c);
        tray[i] = null;
        any = true;
      }
    }
    if (overflow != null) {
      _zap(overflow!);
      overflow = null;
      any = true;
    }
    if (!any) return false;
    status = GameStatus.playing;
    _checkWin();
    return true;
  }

  /// 부스터: 대기석 한 칸 추가.
  bool addTraySlot() {
    if (status == GameStatus.won || tray.length >= level.traySize + 2) {
      return false;
    }
    tray.add(null);
    if (status == GameStatus.failed && overflow != null) {
      tray[tray.length - 1] = overflow;
      overflow = null;
      status = GameStatus.playing;
    }
    return true;
  }

  /// 힌트: 지금 보내면 가장 알차게 먹는 냠냠이의 id. 없으면 null.
  int? hint() {
    Critter? best;
    var bestScore = 0.0;
    final cands = <Critter>[
      for (final c in columns)
        if (c.isNotEmpty) c.first,
      for (final c in tray)
        if (c != null) c,
    ];
    for (final c in cands) {
      final eaten = board.copy().runLap(c.color, c.ammo);
      if (eaten == 0) continue;
      final score = eaten / c.ammo + eaten * 0.001 + (eaten == c.ammo ? 1 : 0);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best?.id;
  }
}

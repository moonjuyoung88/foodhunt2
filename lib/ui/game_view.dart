import 'dart:math';

import 'package:flutter/material.dart';

import '../game/engine.dart';
import '../game/models.dart';
import 'painters.dart';
import 'style.dart';

/// 게임 화면 안 요소들의 좌표 계산 (그리기와 터치 판정이 같은 값을 씁니다).
class GameLayout {
  GameLayout(this.size, this.w, this.h, this.cols, this.slots) {
    const pad = 10.0;
    const bo = BeltGeometry.margin + 0.95;
    final regionH = size.height * 0.56;
    cell = min(
      (size.width - 2 * pad) / (w + 2 * bo),
      (regionH - pad) / (h + 2 * bo),
    );
    cell = min(cell, 30);
    origin = Offset(
      size.width / 2 - w * cell / 2,
      pad / 2 + regionH / 2 - h * cell / 2,
    );
    panel = Rect.fromLTRB(
      origin.dx - bo * cell,
      origin.dy - bo * cell,
      origin.dx + (w + bo) * cell,
      origin.dy + (h + bo) * cell,
    );
    final trayH = (size.height * 0.11).clamp(46.0, 72.0);
    slotSize = min(trayH - 10, (size.width - 2 * pad - 24) / slots - 6);
    trayRect = Rect.fromLTWH(pad, regionH + 4, size.width - 2 * pad, trayH);
    queueTop = trayRect.bottom + 10;
    final qh = size.height - queueTop - 4;
    qSize = min(min(62.0, (size.width - 2 * pad) / (cols * 1.3)), qh / 2.6);
    rowStep = qSize * 1.04;
    visibleRows = max(1, ((qh - qSize * 0.2) / rowStep).floor());
    beltCritter = max(cell * 1.75, min(20.0, cell * 2.3));
  }

  final Size size;
  final int w;
  final int h;
  final int cols;
  final int slots;
  late double cell;
  late Offset origin;
  late Rect panel;
  late Rect trayRect;
  late double slotSize;
  late double queueTop;
  late double qSize;
  late double rowStep;
  late int visibleRows;
  late double beltCritter;

  Offset grid(double x, double y) => origin + Offset(x * cell, y * cell);

  Offset cellCenter(int index) => grid(index % w + 0.5, index ~/ w + 0.5);

  Offset slotCenter(int i) {
    final step = slotSize + 6;
    final x0 = size.width / 2 - step * (slots - 1) / 2;
    return Offset(x0 + step * i, trayRect.center.dy);
  }

  double columnX(int col) {
    final step = min(qSize * 1.42, (size.width - 20) / cols);
    return size.width / 2 + (col - (cols - 1) / 2) * step;
  }

  Offset queuePos(int col, double row) =>
      Offset(columnX(col), queueTop + qSize * 0.62 + row * rowStep);

  Rect columnRect(int col) {
    final x = columnX(col);
    final hw = qSize * 0.66;
    return Rect.fromLTRB(x - hw, queueTop, x + hw, size.height - 2);
  }

  int columnAt(Offset p) {
    for (var i = 0; i < cols; i++) {
      if (columnRect(i).contains(p)) return i;
    }
    return -1;
  }

  int slotAt(Offset p) {
    for (var i = 0; i < slots; i++) {
      if ((slotCenter(i) - p).distance < slotSize * 0.62) return i;
    }
    return -1;
  }
}

class Pop {
  Pop(this.cell, this.color);
  final int cell;
  final Color color;
  double t = 0;
}

class Beam {
  Beam(this.from, this.to, this.color);
  final Offset from;
  final Offset to;
  final Color color;
  double t = 0;
}

class Spark {
  Spark(this.pos, this.vel, this.color, this.life, this.size);
  Offset pos;
  Offset vel;
  final Color color;
  final double life;
  final double size;
  double t = 0;
}

/// 화면 연출 상태 (규칙과 무관한 눈요기).
class GameFx {
  final List<Pop> pops = [];
  final List<Beam> beams = [];
  final List<Spark> sparks = [];
  final Map<int, Offset> launchFrom = {};
  final Map<int, (Offset, double)> trayAnim = {};
  final Map<int, double> munch = {};
  List<double> colShift = [];
  int? hintId;
  double hintT = 0;
  double time = 0;
  double shake = 0;

  void update(double dt) {
    time += dt;
    for (final p in pops) {
      p.t += dt / 0.28;
    }
    pops.removeWhere((p) => p.t >= 1);
    for (final b in beams) {
      b.t += dt / 0.13;
    }
    beams.removeWhere((b) => b.t >= 1);
    for (final s in sparks) {
      s.t += dt / s.life;
      s.pos += s.vel * dt;
      s.vel = Offset(s.vel.dx * 0.985, s.vel.dy + 520 * dt);
    }
    sparks.removeWhere((s) => s.t >= 1);
    for (final k in trayAnim.keys.toList()) {
      final (o, t) = trayAnim[k]!;
      if (t + dt / 0.22 >= 1) {
        trayAnim.remove(k);
      } else {
        trayAnim[k] = (o, t + dt / 0.22);
      }
    }
    for (final k in munch.keys.toList()) {
      final v = munch[k]! - dt / 0.18;
      if (v <= 0) {
        munch.remove(k);
      } else {
        munch[k] = v;
      }
    }
    for (var i = 0; i < colShift.length; i++) {
      colShift[i] = max(0, colShift[i] - dt / 0.16);
    }
    if (hintId != null) {
      hintT -= dt;
      if (hintT <= 0) hintId = null;
    }
    shake = max(0, shake - dt / 0.4);
  }

  void burst(
    Offset at,
    Color color,
    Random rng, {
    int n = 8,
    double power = 160,
  }) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * pi * 2;
      final v = power * (0.4 + rng.nextDouble() * 0.8);
      sparks.add(
        Spark(
          at,
          Offset(cos(a) * v, sin(a) * v - power * 0.5),
          color,
          0.45 + rng.nextDouble() * 0.35,
          3 + rng.nextDouble() * 4,
        ),
      );
    }
  }
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.engine,
    required this.fx,
    required this.layout,
    required this.trayLabel,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameEngine engine;
  final GameFx fx;
  final GameLayout layout;
  final String trayLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final theme = engine.level.theme;
    final geo = engine.geo;
    final paint = Paint()..isAntiAlias = true;
    final cell = l.cell;

    canvas.save();
    if (fx.shake > 0) {
      canvas.translate(sin(fx.time * 70) * 6 * fx.shake, 0);
    }

    // 판
    paint.color = Colors.black.withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        l.panel.translate(0, 5),
        Radius.circular(cell * 1.6),
      ),
      paint,
    );
    paint.color = Ui.panel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(l.panel, Radius.circular(cell * 1.6)),
      paint,
    );

    // 벨트
    const m = BeltGeometry.margin;
    final beltRect = Rect.fromPoints(
      l.grid(-m, -m),
      l.grid(theme.w + m, theme.h + m),
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 1.75
      ..color = Ui.belt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(beltRect, Radius.circular(cell * 0.9)),
      paint,
    );
    paint.style = PaintingStyle.fill;
    paint.color = Ui.beltDot;
    final off = (fx.time * engine.speed) % 2.0;
    for (var d = off; d < geo.length; d += 2.0) {
      final (x, y) = geo.positionAt(d);
      canvas.drawCircle(l.grid(x, y), cell * 0.16, paint);
    }
    // 출발 지점 표시
    final (sx, sy) = geo.positionAt(0);
    paint.color = Ui.yellow.withValues(alpha: 0.9);
    final sp = l.grid(sx, sy);
    final arrow = Path()
      ..moveTo(sp.dx, sp.dy - cell * 0.55)
      ..lineTo(sp.dx - cell * 0.5, sp.dy + cell * 0.3)
      ..lineTo(sp.dx + cell * 0.5, sp.dy + cell * 0.3)
      ..close();
    canvas.drawPath(arrow, paint);

    // 그림 바탕
    final inner = Rect.fromPoints(
      l.grid(-0.3, -0.3),
      l.grid(theme.w + 0.3, theme.h + 0.3),
    );
    paint.color = Ui.boardBg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.5)),
      paint,
    );

    // 블록
    final cells = engine.board.cells;
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      if (c < 0) continue;
      final x = i % theme.w, y = i ~/ theme.w;
      drawBlock(
        canvas,
        Rect.fromLTWH(
          l.origin.dx + x * cell,
          l.origin.dy + y * cell,
          cell,
          cell,
        ),
        theme.palette[c],
        paint,
      );
    }
    // 먹힌 블록 팝
    for (final p in fx.pops) {
      final c = l.cellCenter(p.cell);
      final s = cell * (1 + p.t * 0.9);
      paint.color = Color.lerp(
        p.color,
        Colors.white,
        0.4 + 0.6 * p.t,
      )!.withValues(alpha: 1 - p.t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s, height: s),
          Radius.circular(s * 0.25),
        ),
        paint,
      );
    }
    // 혀(빔)
    for (final b in fx.beams) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.34 * (1 - b.t)
        ..color = Ui.lighten(b.color, 0.5).withValues(alpha: 0.9 * (1 - b.t));
      canvas.drawLine(b.from, b.to, paint);
    }
    paint.style = PaintingStyle.fill;

    // 벨트 위 냠냠이
    final center = l.grid(theme.w / 2, theme.h / 2);
    for (final b in engine.belt) {
      final (x, y) = geo.positionAt(b.d);
      final p = l.grid(x, y);
      final dir = center - p;
      final look = dir.distance > 0 ? dir / dir.distance : Offset.zero;
      drawCritter(
        canvas,
        p,
        l.beltCritter,
        theme.palette[b.critter.color],
        ammo: b.critter.ammo,
        look: look,
        munch: fx.munch[b.critter.id] ?? 0,
        bob: fx.time * 16 + b.critter.id,
      );
    }
    canvas.restore();

    // 대기석
    final danger = engine.freeTraySlots <= 1;
    final pulse = danger ? (0.5 + 0.5 * sin(fx.time * 9)) : 0.0;
    paint.color = Color.lerp(
      Colors.black.withValues(alpha: 0.26),
      const Color(0xFFFF3B5C).withValues(alpha: 0.4),
      pulse,
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(l.trayRect, const Radius.circular(18)),
      paint,
    );
    final lt = textPainterFor(trayLabel, 10, Ui.textDim);
    lt.paint(canvas, Offset(l.trayRect.left + 10, l.trayRect.top + 3));
    // 벨트 정원 표시
    for (var i = 0; i < engine.beltCap; i++) {
      final used = i < engine.belt.length + engine.pending.length;
      paint.color = used ? Ui.yellow : Colors.white.withValues(alpha: 0.18);
      canvas.drawCircle(
        Offset(l.trayRect.right - 12 - i * 9.0, l.trayRect.top + 8),
        3,
        paint,
      );
    }
    for (var i = 0; i < engine.tray.length; i++) {
      final c = l.slotCenter(i);
      paint.color = Colors.white.withValues(alpha: 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: l.slotSize, height: l.slotSize),
          Radius.circular(l.slotSize * 0.24),
        ),
        paint,
      );
    }
    for (var i = 0; i < engine.tray.length; i++) {
      final k = engine.tray[i];
      if (k == null) continue;
      var c = l.slotCenter(i);
      final anim = fx.trayAnim[k.id];
      if (anim != null) {
        final t = Curves.easeOut.transform(anim.$2);
        c = Offset.lerp(anim.$1, c, t)!;
      }
      drawCritter(
        canvas,
        c,
        l.slotSize * 0.86,
        theme.palette[k.color],
        ammo: k.ammo,
        glow: fx.hintId == k.id && sin(fx.time * 10) > -0.3,
      );
    }

    // 대기 줄
    for (var col = 0; col < engine.columns.length; col++) {
      final r = l.columnRect(col);
      paint.color = Colors.black.withValues(alpha: 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(l.qSize * 0.36)),
        paint,
      );
      final list = engine.columns[col];
      final shift = col < fx.colShift.length
          ? Curves.easeIn.transform(fx.colShift[col])
          : 0.0;
      final n = min(list.length, l.visibleRows + 1);
      for (var row = n - 1; row >= 0; row--) {
        final k = list[row];
        final rr = row + shift;
        final p = l.queuePos(col, rr);
        if (p.dy + l.qSize * 0.5 > size.height + l.qSize * 0.4) continue;
        final front = row == 0;
        final fade =
            (1 - (rr - (l.visibleRows - 1)).clamp(0.0, 1.0)) *
            (front ? 1 : 0.92);
        drawCritter(
          canvas,
          p,
          l.qSize * (front ? 1.0 - 0.1 * shift : 0.84),
          theme.palette[k.color],
          ammo: k.ammo,
          mystery: k.mystery,
          alpha: fade * (front && !engine.canLaunch ? 0.6 : 1),
          bob: front ? fx.time * 5 + col * 1.7 : 0,
          look: front ? const Offset(0, -0.8) : Offset.zero,
          glow: fx.hintId == k.id && sin(fx.time * 10) > -0.3,
        );
      }
      if (list.length > l.visibleRows) {
        final more = list.length - l.visibleRows;
        final tp = textPainterFor('+$more', 11, Ui.textDim);
        tp.paint(
          canvas,
          Offset(r.center.dx - tp.width / 2, r.bottom - tp.height - 3),
        );
      }
    }

    // 출발 중인 냠냠이 (줄/대기석 → 벨트 입구)
    final gate = l.grid(sx, sy);
    for (final p in engine.pending) {
      final from = fx.launchFrom[p.critter.id] ?? gate;
      final t = (1 - p.wait / GameEngine.enterDelay).clamp(0.0, 1.0);
      final e = Curves.easeInOut.transform(t);
      final pos = Offset.lerp(from, gate, e)!.translate(0, -sin(e * pi) * 26);
      final s = l.qSize + (l.beltCritter - l.qSize) * e;
      drawCritter(
        canvas,
        pos,
        s,
        theme.palette[p.critter.color],
        ammo: p.critter.ammo,
      );
    }

    // 불꽃/색종이
    for (final s in fx.sparks) {
      paint.color = s.color.withValues(alpha: (1 - s.t).clamp(0.0, 1.0));
      canvas.drawRect(
        Rect.fromCenter(center: s.pos, width: s.size, height: s.size),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}

/// 엔진 이벤트 → 연출 변환에 필요한 좌표 헬퍼.
Offset stationPoint(GameLayout l, BeltGeometry geo, int station) {
  final (x, y) = geo.positionAt(geo.stationDistance(station));
  return l.grid(x, y);
}

Color critterColor(ArtTheme t, Critter c) => t.palette[c.color];

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/models.dart';
import 'style.dart';

final Map<String, TextPainter> _textCache = {};

TextPainter textPainterFor(String s, double size, Color color) {
  final key = '$s|${(size * 2).round()}|${color.toARGB32()}';
  return _textCache.putIfAbsent(key, () {
    if (_textCache.length > 600) _textCache.clear();
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });
}

void drawCenteredText(
  Canvas canvas,
  String s,
  Offset c,
  double size,
  Color color,
) {
  final tp = textPainterFor(s, size, color);
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

/// 블록 한 칸 (위쪽 하이라이트 + 아래쪽 그림자로 도톰하게).
void drawBlock(Canvas canvas, Rect r, Color color, Paint paint) {
  final gap = r.width * 0.06;
  final rr = r.deflate(gap);
  final rad = Radius.circular(r.width * 0.2);
  paint
    ..style = PaintingStyle.fill
    ..color = Ui.darken(color, 0.28);
  canvas.drawRRect(RRect.fromRectAndRadius(rr, rad), paint);
  final top = Rect.fromLTRB(
    rr.left,
    rr.top,
    rr.right,
    rr.bottom - r.width * 0.14,
  );
  paint.color = color;
  canvas.drawRRect(RRect.fromRectAndRadius(top, rad), paint);
  if (r.width >= 7) {
    paint.color = Colors.white.withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rr.left + r.width * 0.14,
          rr.top + r.width * 0.12,
          r.width * 0.3,
          r.width * 0.16,
        ),
        Radius.circular(r.width * 0.1),
      ),
      paint,
    );
  }
}

/// 냠냠이 한 마리.
///
/// [look]은 눈동자가 향하는 방향(단위 벡터 정도), [munch]는 0..1 (방금 먹었을 때 입 벌림),
/// [bob]은 걸음 위상.
void drawCritter(
  Canvas canvas,
  Offset c,
  double s,
  Color color, {
  int? ammo,
  bool mystery = false,
  Offset look = Offset.zero,
  double munch = 0,
  double bob = 0,
  double alpha = 1,
  bool glow = false,
}) {
  final paint = Paint()..isAntiAlias = true;
  final body = mystery ? const Color(0xFF7C7FA8) : color;
  final dark = Ui.darken(body, 0.42);
  final a = alpha.clamp(0.0, 1.0);
  Color f(Color x) => x.withValues(alpha: x.a * a);
  final hop = sin(bob) * s * 0.04;
  final cc = c.translate(0, -hop.abs());

  if (glow) {
    paint
      ..color = Colors.white.withValues(alpha: 0.55 * a)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.22);
    canvas.drawCircle(cc, s * 0.62, paint);
    paint.maskFilter = null;
  }
  // 그림자
  paint.color = Colors.black.withValues(alpha: 0.22 * a);
  canvas.drawOval(
    Rect.fromCenter(
      center: c.translate(0, s * 0.5),
      width: s * 0.8,
      height: s * 0.2,
    ),
    paint,
  );
  // 발
  paint.color = f(dark);
  final footY = cc.dy + s * 0.44;
  final step = sin(bob) * s * 0.05;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cc.dx - s * 0.2, footY + step),
        width: s * 0.24,
        height: s * 0.16,
      ),
      Radius.circular(s * 0.07),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cc.dx + s * 0.2, footY - step),
        width: s * 0.24,
        height: s * 0.16,
      ),
      Radius.circular(s * 0.07),
    ),
    paint,
  );
  // 귀
  for (final dx in [-0.27, 0.27]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cc.dx + s * dx, cc.dy - s * 0.42),
          width: s * 0.24,
          height: s * 0.26,
        ),
        Radius.circular(s * 0.09),
      ),
      paint,
    );
  }
  // 몸통 (테두리 → 면 → 하이라이트)
  final bodyRect = Rect.fromCenter(
    center: cc,
    width: s * 0.92,
    height: s * 0.86,
  );
  final rad = Radius.circular(s * 0.26);
  canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, rad), paint);
  paint.color = f(body);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      bodyRect.deflate(s * 0.06),
      Radius.circular(s * 0.2),
    ),
    paint,
  );
  paint.color = Colors.white.withValues(alpha: 0.25 * a);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyRect.left + s * 0.14,
        bodyRect.top + s * 0.11,
        s * 0.3,
        s * 0.1,
      ),
      Radius.circular(s * 0.05),
    ),
    paint,
  );

  if (mystery) {
    drawCenteredText(
      canvas,
      '?',
      cc,
      s * 0.56,
      Colors.white.withValues(alpha: a),
    );
    return;
  }
  // 눈
  final showNumber = ammo != null;
  final eyeY = cc.dy - (showNumber ? s * 0.16 : s * 0.06);
  final er = s * 0.125;
  for (final dx in [-0.19, 0.19]) {
    final e = Offset(cc.dx + s * dx, eyeY);
    paint.color = Colors.white.withValues(alpha: a);
    canvas.drawCircle(e, er, paint);
    paint.color = const Color(0xFF1B1730).withValues(alpha: a);
    canvas.drawCircle(e + look * (er * 0.45), er * 0.55, paint);
  }
  if (showNumber) {
    final txt = '$ammo';
    final size = s * (txt.length >= 3 ? 0.3 : 0.38);
    final pos = Offset(cc.dx, cc.dy + s * 0.2);
    final light = Ui.isLight(body);
    final fg = (light ? const Color(0xFF241B3A) : Colors.white).withValues(
      alpha: a,
    );
    if (munch > 0.05) {
      paint.color = const Color(0xFF1B1730).withValues(alpha: 0.35 * munch * a);
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: s * 0.5, height: s * 0.36 * munch),
        paint,
      );
    }
    drawCenteredText(canvas, txt, pos, size, fg);
  } else {
    paint.color = const Color(0xFF1B1730).withValues(alpha: a);
    final mh = s * (0.05 + 0.16 * munch);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cc.dx, cc.dy + s * 0.17),
        width: s * 0.22,
        height: mh,
      ),
      paint,
    );
  }
}

/// 완성 그림 미리보기. [silhouette]이면 아직 못 본 그림처럼 어둡게 가립니다.
class ArtPainter extends CustomPainter {
  ArtPainter(this.theme, {this.silhouette = false, this.chunky = true});
  final ArtTheme theme;
  final bool silhouette;
  final bool chunky;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = min(size.width / theme.w, size.height / theme.h);
    final ox = (size.width - cell * theme.w) / 2;
    final oy = (size.height - cell * theme.h) / 2;
    final paint = Paint();
    for (var y = 0; y < theme.h; y++) {
      for (var x = 0; x < theme.w; x++) {
        final c = theme.cells[y * theme.w + x];
        if (c < 0) continue;
        final r = Rect.fromLTWH(ox + x * cell, oy + y * cell, cell, cell);
        if (silhouette) {
          paint.color = const Color(0xFF4A4D8C);
          canvas.drawRect(r.inflate(0.3), paint);
        } else if (chunky && cell >= 5) {
          drawBlock(canvas, r, theme.palette[c], paint);
        } else {
          paint.color = theme.palette[c];
          canvas.drawRect(r.inflate(0.3), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(ArtPainter old) =>
      old.theme != theme || old.silhouette != silhouette;
}

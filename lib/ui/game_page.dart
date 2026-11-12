import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/engine.dart';
import '../game/level_gen.dart';
import '../game/models.dart';
import '../services/app_state.dart';
import 'game_view.dart';
import 'painters.dart';
import 'style.dart';

enum _Overlay { none, win, fail, pause }

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.app, required this.level});
  final AppState app;
  final int level;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late GameEngine engine;
  late GameFx fx;
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  final Random _rng = Random();
  GameLayout? _layout;
  Duration _last = Duration.zero;
  _Overlay _overlay = _Overlay.none;
  int _reward = 0;
  int _total = 1;
  double _endTimer = -1;

  AppState get app => widget.app;
  ArtTheme get theme => engine.level.theme;

  @override
  void initState() {
    super.initState();
    _start();
    _ticker = createTicker(_tick)..start();
  }

  void _start() {
    engine = GameEngine(generateLevel(widget.level, app.themes));
    fx = GameFx()..colShift = List<double>.filled(engine.columns.length, 0);
    _total = engine.board.remaining;
    _overlay = _Overlay.none;
    _endTimer = -1;
    _layout = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt > 0.05) dt = 0.05;
    if (dt <= 0) return;
    final l = _layout;
    if (_overlay != _Overlay.pause) {
      // 큰 프레임 간격도 정류장을 건너뛰지 않도록 잘게 나눠 진행
      engine.update(dt / 2);
      engine.update(dt / 2);
    }
    if (l != null) _consumeEvents(l);
    engine.events.clear();
    fx.update(dt);
    if (_endTimer > 0) {
      _endTimer -= dt;
      if (engine.status == GameStatus.won &&
          _rng.nextDouble() < 0.5 &&
          l != null) {
        _confetti(l);
      }
      if (_endTimer <= 0) {
        setState(() {
          _overlay = engine.status == GameStatus.won
              ? _Overlay.win
              : _Overlay.fail;
        });
      }
    }
    _repaint.value++;
  }

  void _confetti(GameLayout l) {
    final colors = theme.palette;
    for (var i = 0; i < 3; i++) {
      fx.sparks.add(
        Spark(
          Offset(_rng.nextDouble() * l.size.width, -8),
          Offset((_rng.nextDouble() - 0.5) * 160, 40 + _rng.nextDouble() * 120),
          colors[_rng.nextInt(colors.length)],
          1.6,
          5 + _rng.nextDouble() * 5,
        ),
      );
    }
  }

  void _consumeEvents(GameLayout l) {
    var statusChanged = false;
    for (final e in engine.events) {
      switch (e) {
        case LaunchEvent():
          if (e.fromColumn >= 0) {
            fx.launchFrom[e.critter.id] = l.queuePos(e.fromColumn, 0);
            fx.colShift[e.fromColumn] = 1;
          } else if (e.fromSlot >= 0) {
            fx.launchFrom[e.critter.id] = l.slotCenter(e.fromSlot);
          }
          app.sfx.play('launch', volume: 0.55);
          app.buzz();
        case EatEvent():
          final color = theme.palette[e.color];
          fx.pops.add(Pop(e.cell, color));
          if (e.station >= 0) {
            fx.beams.add(
              Beam(
                stationPoint(l, engine.geo, e.station),
                l.cellCenter(e.cell),
                color,
              ),
            );
            fx.munch[e.critterId] = 1;
          }
          if (fx.sparks.length < 160) {
            fx.burst(l.cellCenter(e.cell), color, _rng, n: 2, power: 90);
          }
          app.sfx.pop();
        case CritterFullEvent():
          final (x, y) = engine.geo.positionAt(e.d);
          fx.burst(l.grid(x, y), theme.palette[e.critter.color], _rng, n: 12);
          fx.burst(l.grid(x, y), Colors.white, _rng, n: 5, power: 110);
          app.sfx.play('full', volume: 0.6);
        case ToTrayEvent():
          final (x, y) = engine.geo.positionAt(engine.geo.length);
          fx.trayAnim[e.critter.id] = (l.grid(x, y), 0.0);
          app.sfx.play('tray', volume: 0.5);
        case WinEvent():
          _reward = app.completeLevel(widget.level);
          app.sfx.play('win');
          app.buzz(strong: true);
          _endTimer = 1.3;
          statusChanged = true;
        case FailEvent():
          fx.shake = 1;
          app.sfx.play('fail');
          app.buzz(strong: true);
          _endTimer = 0.7;
          statusChanged = true;
      }
    }
    if (statusChanged) setState(() {});
  }

  void _onTap(Offset p) {
    final l = _layout;
    if (l == null ||
        _overlay != _Overlay.none ||
        engine.status != GameStatus.playing) {
      return;
    }
    final slot = l.slotAt(p);
    final col = slot < 0 ? l.columnAt(p) : -1;
    if (slot < 0 && col < 0) return;
    final ok = slot >= 0 ? engine.tapTray(slot) : engine.tapColumn(col);
    if (ok) {
      fx.hintId = null;
    } else if ((slot >= 0 && engine.tray[slot] != null) ||
        (col >= 0 && engine.columns[col].isNotEmpty)) {
      app.sfx.play('nope', volume: 0.5);
    }
  }

  void _booster(int cost, bool Function() action) {
    if (engine.status == GameStatus.won) return;
    if (app.coins < cost) {
      app.sfx.play('nope', volume: 0.5);
      _toast(app.t('코인이 부족해요', 'Not enough coins'));
      return;
    }
    if (!action()) {
      app.sfx.play('nope', volume: 0.5);
      return;
    }
    app.spend(cost);
    app.sfx.play('boost');
    setState(() {
      if (engine.status == GameStatus.playing) {
        _overlay = _Overlay.none;
        _endTimer = -1;
      }
    });
  }

  void _hint() => _booster(AppState.hintCost, () {
    final id = engine.hint();
    if (id == null) {
      _toast(app.t('지금은 먹을 수 있는 냠냠이가 없어요', 'Nobody can eat right now'));
      return false;
    }
    fx.hintId = id;
    fx.hintT = 4;
    return true;
  });

  void _addSlot() => _booster(AppState.slotCost, () {
    final ok = engine.addTraySlot();
    if (ok) {
      _layout = null;
    } else {
      _toast(app.t('더 늘릴 수 없어요', 'Tray is at max size'));
    }
    return ok;
  });

  void _clearTray() => _booster(AppState.clearCost, () {
    final ok = engine.clearTray();
    if (!ok) _toast(app.t('대기석이 비어 있어요', 'Tray is empty'));
    return ok;
  });

  void _toast(String s) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(s, textAlign: TextAlign.center),
          duration: const Duration(milliseconds: 1300),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(60, 0, 60, 120),
        ),
      );
  }

  void _restart() => setState(_start);

  void _next() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GamePage(app: app, level: widget.level + 1),
      ),
    );
  }

  String? get _tip {
    switch (widget.level) {
      case 1:
        return app.t(
          '맨 앞 냠냠이를 톡! 벨트를 돌며 같은 색 블록을 먹어요',
          'Tap a front nibbler! It circles the belt eating blocks of its color',
        );
      case 2:
        return app.t(
          '바깥에 드러난 블록만 먹을 수 있어요. 숫자는 먹을 수 있는 양!',
          'Only exposed blocks can be eaten. The number is how many it can eat',
        );
      case 3:
        return app.t(
          '다 못 먹으면 대기석으로 돌아와요. 대기석이 넘치면 실패!',
          'Leftover nibblers wait in the tray. If the tray overflows, you lose!',
        );
      case 4:
        return app.t(
          '대기석의 냠냠이도 톡 하면 다시 출발해요',
          'Tap a nibbler in the tray to send it again',
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: Ui.background,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _repaint,
                      builder: (_, __, ___) => _ProgressBar(
                        value: 1 - engine.board.remaining / _total,
                        color: Ui.green,
                      ),
                    ),
                  ),
                  if (_tip != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: Text(
                        _tip!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Ui.yellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = Size(box.maxWidth, box.maxHeight);
                        var l = _layout;
                        if (l == null ||
                            l.size != size ||
                            l.slots != engine.tray.length) {
                          l = GameLayout(
                            size,
                            theme.w,
                            theme.h,
                            engine.columns.length,
                            engine.tray.length,
                          );
                          _layout = l;
                        }
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _onTap(d.localPosition),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: size,
                              painter: GamePainter(
                                engine: engine,
                                fx: fx,
                                layout: l,
                                trayLabel: app.t('대기석', 'TRAY'),
                                repaint: _repaint,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _boosterBar(),
                ],
              ),
              if (_overlay == _Overlay.win) _winOverlay(),
              if (_overlay == _Overlay.fail) _failOverlay(),
              if (_overlay == _Overlay.pause) _pauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _overlay = _Overlay.pause),
            icon: const Icon(Icons.pause_rounded, color: Ui.text, size: 30),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  app.t('레벨 ${widget.level}', 'Level ${widget.level}'),
                  style: const TextStyle(
                    color: Ui.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  app.themeName(theme),
                  style: const TextStyle(
                    color: Ui.textDim,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: app,
            builder: (_, __) => CoinPill(coins: app.coins),
          ),
        ],
      ),
    );
  }

  Widget _boosterBar() {
    Widget b(
      IconData icon,
      String label,
      int cost,
      VoidCallback onTap,
      Color color,
    ) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ChunkyButton(
            color: color,
            padding: const EdgeInsets.symmetric(vertical: 7),
            radius: 14,
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon(size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '$cost',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 12),
      child: Row(
        children: [
          b(
            Icons.lightbulb_rounded,
            app.t('힌트', 'Hint'),
            AppState.hintCost,
            _hint,
            const Color(0xFF5B8DEF),
          ),
          b(
            Icons.add_box_rounded,
            app.t('자리 +1', 'Slot +1'),
            AppState.slotCost,
            _addSlot,
            const Color(0xFF9B6BF2),
          ),
          b(
            Icons.cleaning_services_rounded,
            app.t('싹 비우기', 'Clear tray'),
            AppState.clearCost,
            _clearTray,
            Ui.pink,
          ),
        ],
      ),
    );
  }

  Widget _scrim(Widget child) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (_, v, c) => Transform.scale(scale: v, child: c),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: Ui.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Ui.panelLight, width: 3),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _title(String s, Color c) => Text(
    s,
    textAlign: TextAlign.center,
    style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 28),
  );

  Widget _winOverlay() {
    final frontier = widget.level + 1 == app.level;
    return _scrim(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(app.t('냠냠 완료!', 'All eaten!'), Ui.yellow),
          const SizedBox(height: 14),
          Container(
            width: 170,
            height: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Ui.boardBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: CustomPaint(painter: ArtPainter(theme)),
          ),
          const SizedBox(height: 10),
          Text(
            app.themeName(theme),
            style: const TextStyle(
              color: Ui.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            app.t('도감에 추가됐어요', 'Added to your album'),
            style: const TextStyle(color: Ui.textDim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinIcon(size: 22),
              const SizedBox(width: 6),
              Text(
                '+$_reward',
                style: const TextStyle(
                  color: Ui.yellow,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              ChunkyButton(
                color: Ui.panelLight,
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.home_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChunkyButton(
                  color: Ui.green,
                  onTap: frontier ? _next : () => Navigator.of(context).pop(),
                  child: Center(
                    child: Text(
                      frontier
                          ? app.t('다음 레벨', 'Next level')
                          : app.t('확인', 'OK'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _failOverlay() {
    Widget costRow(String label, int cost) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 8),
        const CoinIcon(size: 16),
        const SizedBox(width: 3),
        Text('$cost', style: const TextStyle(color: Colors.white)),
      ],
    );
    return _scrim(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(app.t('대기석이 꽉 찼어요', 'Tray overflow!'), Ui.pink),
          const SizedBox(height: 8),
          Text(
            app.t(
              '부스터로 이어서 하거나 다시 도전해 보세요',
              'Use a booster to continue, or retry',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Ui.textDim, fontSize: 14),
          ),
          const SizedBox(height: 18),
          ChunkyButton(
            color: Ui.pink,
            onTap: _clearTray,
            child: costRow(
              app.t('싹 비우고 계속', 'Clear tray & continue'),
              AppState.clearCost,
            ),
          ),
          const SizedBox(height: 14),
          ChunkyButton(
            color: const Color(0xFF9B6BF2),
            onTap: _addSlot,
            child: costRow(
              app.t('자리 +1 하고 계속', 'Slot +1 & continue'),
              AppState.slotCost,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ChunkyButton(
                color: Ui.panelLight,
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.home_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChunkyButton(
                  onTap: _restart,
                  child: Center(child: Text(app.t('다시 하기', 'Retry'))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pauseOverlay() {
    return _scrim(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(app.t('잠깐 쉬는 중', 'Paused'), Ui.text),
          const SizedBox(height: 18),
          ChunkyButton(
            color: Ui.green,
            onTap: () => setState(() => _overlay = _Overlay.none),
            child: Center(child: Text(app.t('계속하기', 'Resume'))),
          ),
          const SizedBox(height: 14),
          ChunkyButton(
            onTap: _restart,
            child: Center(child: Text(app.t('처음부터 다시', 'Restart'))),
          ),
          const SizedBox(height: 14),
          ChunkyButton(
            color: Ui.panelLight,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Text(
                app.t('홈으로', 'Home'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

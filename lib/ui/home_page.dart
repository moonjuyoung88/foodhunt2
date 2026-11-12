import 'dart:math';

import 'package:flutter/material.dart';

import '../services/app_state.dart';
import 'album_page.dart';
import 'game_page.dart';
import 'painters.dart';
import 'style.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.app});
  final AppState app;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  AppState get app => widget.app;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _play() {
    app.sfx.play('tap');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePage(app: app, level: app.level, hard: app.hard),
      ),
    );
  }

  void _settings() {
    showDialog<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => AlertDialog(
          backgroundColor: Ui.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            app.t('설정', 'Settings'),
            style: const TextStyle(color: Ui.text, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: app.soundOn,
                onChanged: app.setSound,
                activeColor: Ui.yellow,
                title: Text(
                  app.t('효과음', 'Sound'),
                  style: const TextStyle(color: Ui.text),
                ),
              ),
              SwitchListTile(
                value: app.hapticOn,
                onChanged: app.setHaptic,
                activeColor: Ui.yellow,
                title: Text(
                  app.t('진동', 'Vibration'),
                  style: const TextStyle(color: Ui.text),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                app.t(
                  '광고·결제 없음. 그림은 Noto Emoji(OFL 1.1)를 픽셀화했습니다.',
                  'No ads, no purchases. Art is pixelated from Noto Emoji (OFL 1.1).',
                ),
                style: const TextStyle(color: Ui.textDim, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                app.t('닫기', 'Close'),
                style: const TextStyle(
                  color: Ui.yellow,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: Ui.background,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final theme = app.themeForLevel(app.level);
              // 화면이 낮은 기기에서는 미리보기를 줄여 버튼이 잘리지 않게 합니다.
              final previewSize = MediaQuery.of(context).size.height < 740
                  ? 130.0
                  : 190.0;
              final cleared = min(app.level - 1, app.themes.length);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _settings,
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Ui.text,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        CoinPill(coins: app.coins),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 84,
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (_, __) => CustomPaint(
                        size: const Size(double.infinity, 84),
                        painter: _ParadePainter(_anim.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app.t('픽셀 냠냠', 'Pixel Nibblers'),
                    style: const TextStyle(
                      color: Ui.yellow,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(color: Color(0xFFB8502A), offset: Offset(0, 5)),
                      ],
                    ),
                  ),
                  Text(
                    app.t(
                      '톡 보내서 그림을 다 먹어 치우자!',
                      'Tap, munch, clear the picture!',
                    ),
                    style: const TextStyle(
                      color: Ui.textDim,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: previewSize,
                    height: previewSize,
                    padding: EdgeInsets.all(previewSize * 0.115),
                    decoration: BoxDecoration(
                      color: Ui.boardBg,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Ui.panelLight, width: 4),
                    ),
                    child: CustomPaint(
                      painter: ArtPainter(theme, silhouette: true),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    app.t('다음 그림은 무엇일까요?', 'What will the next picture be?'),
                    style: const TextStyle(color: Ui.textDim, fontSize: 13),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: ChunkyButton(
                      color: Ui.green,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      radius: 24,
                      onTap: _play,
                      child: Center(
                        child: Text(
                          app.t(
                            '레벨 ${app.level} 시작',
                            'Play level ${app.level}',
                          ),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DifficultyToggle(app: app),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: ChunkyButton(
                      color: Ui.panelLight,
                      onTap: () {
                        app.sfx.play('tap');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlbumPage(app: app),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.collections_bookmark_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            app.t(
                              '그림 도감  $cleared / ${app.themes.length}',
                              'Album  $cleared / ${app.themes.length}',
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParadePainter extends CustomPainter {
  _ParadePainter(this.t);
  final double t;

  static const _colors = [
    Color(0xFFFF5D5D),
    Color(0xFFFFC93C),
    Color(0xFF4ADE80),
    Color(0xFF5B8DEF),
    Color(0xFFFF8ACB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const s = 54.0;
    final gap = s * 1.25;
    final x0 = size.width / 2 - gap * 2;
    for (var i = 0; i < 5; i++) {
      final phase = t * 2 * pi * 2 + i * 0.9;
      final y = size.height - s * 0.6 - max(0, sin(phase)) * 14;
      drawCritter(
        canvas,
        Offset(x0 + gap * i, y),
        s,
        _colors[i],
        bob: phase,
        look: Offset(cos(phase) * 0.6, -0.3),
        munch: max(0, sin(phase * 2)),
      );
    }
  }

  @override
  bool shouldRepaint(_ParadePainter old) => old.t != t;
}

/// 노멀 / 어려움 선택. 다음에 시작하는 판부터 적용됩니다.
class _DifficultyToggle extends StatelessWidget {
  const _DifficultyToggle({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    Widget seg(bool hard, String label, String sub, Color color) {
      final on = app.hard == hard;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            app.sfx.play('tap');
            app.setHard(hard);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: on ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: on ? const Color(0xFF2A2140) : Ui.textDim,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: on ? const Color(0xAA2A2140) : Ui.textDim,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 44),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          seg(
            false,
            app.t('노멀', 'Normal'),
            app.t('하트 3 · 코인 +25', '3 hearts · +25'),
            Ui.yellow,
          ),
          seg(
            true,
            app.t('어려움', 'Hard'),
            app.t('하트 2 · 터널 많음 · 코인 +45', '2 hearts · more tunnels · +45'),
            Ui.pink,
          ),
        ],
      ),
    );
  }
}

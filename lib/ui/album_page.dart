import 'package:flutter/material.dart';

import '../game/models.dart';
import '../services/app_state.dart';
import 'game_page.dart';
import 'painters.dart';
import 'style.dart';

/// 지금까지 먹어 치운 그림 모음. 클리어한 그림은 눌러서 다시 할 수 있습니다.
class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: Ui.background,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final byCat = <String, List<int>>{};
              for (var i = 0; i < app.themes.length; i++) {
                byCat.putIfAbsent(app.themes[i].cat, () => []).add(i);
              }
              final cats = [
                for (final c in app.categories)
                  if (byCat.containsKey(c.id)) c,
              ];
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Ui.text,
                              size: 28,
                            ),
                          ),
                          Text(
                            app.t('그림 도감', 'Album'),
                            style: const TextStyle(
                              color: Ui.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(app.level - 1).clamp(0, app.themes.length)} / ${app.themes.length}',
                            style: const TextStyle(
                              color: Ui.yellow,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final c in cats) ...[
                    SliverToBoxAdapter(child: _header(c, byCat[c.id]!)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 92,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.82,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, k) => _tile(context, byCat[c.id]![k]),
                          childCount: byCat[c.id]!.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(ArtCategory c, List<int> idx) {
    final done = idx.where((i) => i + 1 < app.level).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        children: [
          Text(
            app.korean ? c.ko : c.en,
            style: const TextStyle(
              color: Ui.text,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$done/${idx.length}',
            style: const TextStyle(
              color: Ui.textDim,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int i) {
    final theme = app.themes[i];
    final lv = i + 1;
    final cleared = lv < app.level;
    final current = lv == app.level;
    return GestureDetector(
      onTap: (cleared || current)
          ? () {
              app.sfx.play('tap');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GamePage(app: app, level: lv),
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Ui.boardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: current ? Ui.yellow : Ui.panelLight,
            width: current ? 3 : 1.5,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: ArtPainter(theme, silhouette: !cleared, chunky: false),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cleared ? app.themeName(theme) : 'Lv.$lv',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cleared ? Ui.text : Ui.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

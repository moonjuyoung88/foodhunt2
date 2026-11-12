import 'package:audioplayers/audioplayers.dart';

/// 짧은 효과음 재생기. 재생 실패는 게임 진행에 영향을 주지 않도록 모두 무시합니다.
class Sfx {
  bool enabled = true;
  bool _ready = false;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  int _popStep = 0;
  DateTime _lastPop = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      // 사용자가 듣던 음악을 끊지 않도록 다른 소리와 섞어서 재생합니다.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
    } catch (_) {}
    for (var i = 0; i < 6; i++) {
      final p = AudioPlayer();
      try {
        await p.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
      _pool.add(p);
    }
  }

  Future<void> play(String name, {double volume = 0.8}) async {
    if (!enabled) return;
    try {
      await _init();
      if (_pool.isEmpty) return;
      final p = _pool[_next++ % _pool.length];
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (_) {}
  }

  /// 먹는 소리: 너무 촘촘히 겹치지 않게 간격을 두고 음정을 번갈아 냅니다.
  void pop() {
    final now = DateTime.now();
    if (now.difference(_lastPop).inMilliseconds < 55) return;
    _lastPop = now;
    play('pop${1 + (_popStep++ % 3)}', volume: 0.5);
  }
}

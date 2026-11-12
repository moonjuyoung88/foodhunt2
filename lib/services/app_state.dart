import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';
import 'sfx.dart';

/// 진행 상황·코인·설정을 보관하고 기기에 저장합니다.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.themes, this.categories)
    : level = _prefs?.getInt('level') ?? 1,
      coins = _prefs?.getInt('coins') ?? 200,
      soundOn = _prefs?.getBool('sound') ?? true,
      hapticOn = _prefs?.getBool('haptic') ?? true {
    sfx.enabled = soundOn;
  }

  final SharedPreferences? _prefs;
  final List<ArtTheme> themes;
  final List<ArtCategory> categories;
  final Sfx sfx = Sfx();

  /// 지금 도전할 레벨 (1부터). 이보다 작은 레벨은 모두 클리어한 상태.
  int level;
  int coins;
  bool soundOn;
  bool hapticOn;

  static const int hintCost = 20;
  static const int slotCost = 60;
  static const int clearCost = 100;
  static const int winReward = 25;
  static const int replayReward = 5;

  bool get korean => PlatformDispatcher.instance.locale.languageCode == 'ko';

  String t(String ko, String en) => korean ? ko : en;

  String themeName(ArtTheme t) => korean ? t.ko : t.en;

  ArtTheme themeForLevel(int lv) => themes[(lv - 1) % themes.length];

  static Future<AppState> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final raw = await rootBundle.loadString('assets/art/themes.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return AppState(
      prefs,
      [
        for (final t in j['themes'] as List)
          ArtTheme.fromJson(t as Map<String, dynamic>),
      ],
      [
        for (final c in j['cats'] as List)
          ArtCategory(c['id'] as String, c['ko'] as String, c['en'] as String),
      ],
    );
  }

  bool spend(int cost) {
    if (coins < cost) return false;
    coins -= cost;
    _prefs?.setInt('coins', coins);
    notifyListeners();
    return true;
  }

  /// 레벨 클리어 처리. 받은 코인을 돌려줍니다.
  int completeLevel(int lv) {
    final reward = lv >= level ? winReward : replayReward;
    coins += reward;
    if (lv >= level) level = lv + 1;
    _prefs?.setInt('coins', coins);
    _prefs?.setInt('level', level);
    notifyListeners();
    return reward;
  }

  void setSound(bool v) {
    soundOn = v;
    sfx.enabled = v;
    _prefs?.setBool('sound', v);
    notifyListeners();
  }

  void setHaptic(bool v) {
    hapticOn = v;
    _prefs?.setBool('haptic', v);
    notifyListeners();
  }

  void buzz({bool strong = false}) {
    if (!hapticOn) return;
    if (strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }
}

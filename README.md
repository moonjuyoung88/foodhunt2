# 픽셀 냠냠 (Pixel Nibblers)

광고와 결제가 전혀 없는 픽셀 아트 퍼즐 게임입니다. 꼬마 "냠냠이"를 벨트에 올려 보내면 그림 둘레를 한 바퀴 돌면서 자기와 같은 색 블록을 먹어 치웁니다. 그림을 전부 먹으면 클리어입니다.

## APK 내려받기

`main` 브랜치에 푸시할 때마다 GitHub Actions가 APK를 빌드해서 릴리스에 올립니다.

- 최신 APK: <https://github.com/moonjuyoung88/foodhunt2/releases/latest/download/pixel-nibblers.apk>
- 전체 목록: <https://github.com/moonjuyoung88/foodhunt2/releases>

안드로이드 기기에서 위 링크를 열어 내려받은 뒤 설치하시면 됩니다. 처음 설치할 때는 "출처를 알 수 없는 앱 설치"를 허용해야 합니다.

서명 키는 저장소에 넣지 않았습니다. 그래서 기본 설정으로는 빌드할 때마다 서명이 달라져, 새 버전을 설치하려면 기존 앱을 지워야 하고 이때 진행 상황도 함께 지워집니다. 진행 상황을 유지하며 업데이트하고 싶으시면 저장소 Secrets에 `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` 네 가지를 등록해 주세요. 등록해 두면 항상 같은 키로 서명됩니다.

## 게임 규칙

1. 화면 아래 대기 줄의 **맨 앞 냠냠이**를 누르면 벨트로 출발합니다.
2. 냠냠이는 그림 둘레를 시계 방향으로 한 바퀴 돕니다. 지나가는 줄마다 **가장 바깥에 드러난 블록**이 자기 색이면 하나씩 먹습니다.
3. 몸에 적힌 숫자가 먹을 수 있는 양입니다. 다 먹으면 사라지고, 한 바퀴를 돌고도 남으면 **대기석**으로 갑니다.
4. 대기석의 냠냠이도 눌러서 다시 보낼 수 있습니다. 대기석이 가득 찬 상태에서 또 들어오면 실패입니다.
5. `?` 냠냠이는 줄 맨 앞에 올 때까지 색을 알 수 없습니다.

막힐 때는 게임에서 모은 코인으로 부스터(힌트, 자리 +1, 싹 비우기)를 쓸 수 있습니다. 코인은 레벨을 깨면 받으며, 돈으로 살 수 없습니다.

## 구성

| 항목 | 내용 |
|------|------|
| 테마(그림) | 366개, 20개 카테고리 (과일, 식사, 동물, 탈것, 우주, 판타지 등) |
| 레벨 | 테마마다 1레벨, 이후에는 배치를 바꿔 계속 이어집니다 |
| 풀이 보장 | 모든 레벨은 대기석이 넘치지 않는 풀이가 있도록 생성되며, 테스트가 전 레벨을 실제 엔진으로 풀어 확인합니다 |
| 저장 | 진행 레벨, 코인, 설정을 기기에 저장합니다 |

```
lib/
├── game/      # 규칙 엔진, 레벨 생성기 (Flutter 비의존, 단위 테스트 대상)
├── services/  # 저장, 효과음
└── ui/        # 홈, 게임, 도감 화면과 그리기 코드
tool/
├── gen_art.py # 픽셀 그림 생성기 → assets/art/themes.json
└── gen_sfx.py # 효과음 합성기 → assets/sfx/*.wav
```

## 개발

```bash
flutter pub get
```

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter build apk --release
```

그림이나 효과음을 다시 만들려면 Python 3와 Pillow, NumPy, 그리고 Noto Color Emoji 글꼴이 필요합니다.

```bash
python3 tool/gen_art.py
```

```bash
python3 tool/gen_sfx.py
```

## 라이선스 안내

- 픽셀 그림은 [Noto Emoji](https://github.com/googlefonts/noto-emoji) 글꼴(SIL Open Font License 1.1)의 글리프를 저해상도로 줄이고 색을 다시 입혀 만들었습니다.
- 효과음은 `tool/gen_sfx.py`가 직접 합성한 것입니다.
- 캐릭터, UI, 레벨은 모두 이 프로젝트에서 새로 만든 것입니다.

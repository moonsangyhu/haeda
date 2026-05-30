# 카테고리별 emoji preset 추천

- **Date**: 2026-05-30
- **Worktree (수행)**: main 직접
- **Worktree (영향)**: front
- **Role**: feature

## Request

> 다음 작업 뭘 할지 정리해줘 → B. 이어서 이모지 polish → 1. 카테고리별 preset 추천 (추천)

## Root cause / Context

직전 작업 (`2026-05-30-feature-challenge-icon-followups.md`) 에서 emoji 선택 UX 를 12개 universal preset chip + 직접 입력 토글로 통일했지만, 사용자가 "공부" 카테고리를 입력 중일 때도 `🎯💪📚🏃🧘🍎💧😴📝🎨🎵🌱` 같은 일반 preset 이 노출되어 컨텍스트 부적합. Step1 카테고리 입력 + 챌린지방 sheet 양쪽에서 카테고리에 맞는 preset (예: 공부 → `📚📝🧠💡✏️🎓…`) 으로 즉시 갱신되도록.

## Referenced Reports

- `docs/reports/2026-05-30-feature-challenge-icon-followups.md` — 본 작업의 직접 전제. Follow-ups §1 "카테고리별 preset 추천" 에 대응.
- `docs/reports/2026-04-28-feature-challenge-pill-recent.md` — challenge.category 가 freeform string 이라는 결정 ($§Step1 의 TextFormField`).

검색 키워드: `emoji_picker`, `preset`, `category`, `resolvePresets`, `kEmojiPresetsByCategory`.

## Actions

### 1. core — 매핑 + resolvePresets (commit 다음 step)

| 변경 | 위치 |
|------|------|
| `kEmojiPresetCount = 12` 상수 도입 | `app/lib/core/constants/emoji_presets.dart:2` |
| `kEmojiPresetsByCategory` Map<String, List<String>> 9개 카테고리 (운동/공부/독서/학습/건강/습관/취미/명상/다이어트) × 12개 emoji | 같은 파일 :13-50 |
| `resolvePresets(String?)` — exact key → partial (양방향 contains) → universal fallback | :63-75 |
| unit 테스트 6개 (null/빈 → universal / exact / 공부·독서·학습 동일 group / 부분 일치 / 미매칭 → universal / 모든 group 길이 일관) | `app/test/core/constants/emoji_presets_test.dart` (신규) |

### 2. EmojiPicker 위젯 — `category` prop

| 변경 | 위치 |
|------|------|
| `category: String?` 옵셔널 prop 추가 | `app/lib/features/challenge_create/widgets/emoji_picker.dart:5-19` |
| `build()` 마다 `resolvePresets(widget.category)` 호출해 preset 그리드 결정. `_selected` state 는 유지 (preset 이 바뀌어도 선택 emoji 보존) | 같은 파일 :60-83 |
| `initState` 의 customMode 판단도 `resolvePresets(widget.category)` 기준 | :27-38 |

### 3. Step1 화면 — 카테고리 입력 watch

| 변경 | 위치 |
|------|------|
| `_categoryController.addListener(_onCategoryChanged)` 에서 setState 트리거 → EmojiPicker rebuild | `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart:23-30` |
| `EmojiPicker(category: _categoryController.text)` 전달 | :74-78 |
| 위젯 테스트 1개 — '운동' 입력 후 `emoji_preset_🏋️` 가 노출 (universal preset 에는 없는 키) | `step1_screen_test.dart` 신규 |

### 4. 챌린지방 sheet — detail.category 전달

| 변경 | 위치 |
|------|------|
| `ChallengeIconEditSheet.category: String?` prop 추가 | `challenge_icon_edit_sheet.dart:11-21` |
| `EmojiPicker(category: widget.category)` 전달 | :87 |
| `_showIconEditSheet(context, icon, category)` 시그니처 확장 + `detail.category` 전달 | `challenge_space_screen.dart:76-90, 118-122` |

## Verification

### 프론트엔드 — 회귀 + 신규

```
$ flutter test test/core/constants/emoji_presets_test.dart 2>&1 | tail -3
00:00 +6: All tests passed!

$ flutter test test/features/challenge_create/screens/challenge_create_step1_screen_test.dart 2>&1 | tail -3
00:01 +11: All tests passed!   # 직전 10 + 신규 1

$ flutter test test/features/challenge_space/screens/challenge_space_screen_test.dart 2>&1 | tail -3
00:00 +3: All tests passed!   # 회귀 0

$ flutter test 2>&1 | tail -3
00:15 +168: All tests passed!   # 직전 baseline 161 + 본 작업 net +7 (resolvePresets 6 + step1 1)
```

### iOS 시뮬레이터 — clean install + launch

iPhone 17 (iOS 26.4) terminate → uninstall → flutter clean → pub get → build ios --simulator (✓ Built in 32.2s) → install → launch (PID 35562). my-page 정상 진입 + ChallengeCard 두 건 default 🎯 노출 유지 (회귀 0).

| # | 시나리오 | 스크린샷 |
|---|---------|---------|
| 1 | 박지민 my-page 진입 (회귀 baseline 유지) | `2026-05-30-feature-category-aware-presets-01-launch.png` |

idb HID tap 의 Flutter GestureDetector 미인식 한계는 직전 보고서와 동일 — 카테고리 입력 → preset 갱신 시각 검증은 위젯 테스트로 갈음.

## Follow-ups

- **이모지 변경 이력 표시** (Polish 메뉴 #2) — backend audit log 필요. 다음 작업 후보.
- **patrol/integration_test 도입** (Polish 메뉴 #3) — Flutter GestureDetector ↔ idb HID 우회. 다음 작업 후보.
- **카테고리 매핑 확장** — 영어 (exercise, study, health) 또는 더 fine-grained 한국어 (요가, 명상, 산책 등) 추가는 사용자 데이터 누적 후 P2.
- **챌린지방 sheet 의 "현재 이모지" 미리보기** — 현재는 EmojiPicker 의 selected chip 만 highlight. 헤더에 표시되는 이모지 자체를 sheet 상단에 미리보기 강화 가능 (UX 보조).

## Related

- 직전 보고서: `docs/reports/2026-05-30-feature-challenge-icon-followups.md`
- 신규 함수/매핑: `resolvePresets`, `kEmojiPresetsByCategory`, `kEmojiPresetCount` (`app/lib/core/constants/emoji_presets.dart`)
- 확장된 위젯: `EmojiPicker.category`, `ChallengeIconEditSheet.category`

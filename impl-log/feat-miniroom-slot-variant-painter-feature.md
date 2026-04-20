# feat: Miniroom Slot Variant Painter

- **Date**: 2026-04-21
- **Type**: feat
- **Area**: frontend
- **Worktree**: feature

## Requirement

`MiniroomScene` 의 wall/floor painter 에 `mr/` 접두사 버그를 수정하고, design spec `docs/design/specs/miniroom-cyworld.md` §Future 에 명시된 6개 슬롯(ceiling/window/shelf/plant/desk/rug) variant painter 를 구현. 8개 슬롯 전체가 assetKey 분기를 갖도록 확장.

## Plan Source

Design spec: `docs/design/specs/miniroom-cyworld.md` (§Future "Slot 별 variant painter 확장")

수락 기준:
1. wall: `mr/wall_lavender` / `mr/wall_mint` painter + legacy(`wall/pink`, `wall/blue` 등) 보존
2. floor: `mr/floor_wood` / `mr/floor_tile` painter + legacy 보존
3~8. 6개 슬롯(ceiling/window/shelf/plant/desk/rug) × 2 variant helper + painter switch 분기
9. equip==null 기본 case 는 기존 로직 그대로 (회귀 없음)
10. 36개 helper 단위 테스트 (null / 2 시드 / unknown 커버)
11. `flutter analyze`: 0 issues
12. `flutter build ios --simulator`: PASS
13. 파일 600줄 이내 (583줄)
14. TDD RED → GREEN 증거 인용

## Implementation

### Backend

N/A — 서버 파일 변경 없음.

### Frontend

| 파일 | 유형 | 설명 |
|------|------|------|
| `app/lib/core/widgets/miniroom_scene.dart` | MOD | 360줄 → 583줄. `_wallColorFor`/`_floorColorsFor` prefix 버그 수정(stale `wall/`, `floor/` → `mr/wall_`, `mr/floor_`). 6개 슬롯 helper + painter 추가. helper visibility를 private → `@visibleForTesting` public(`miniroomSceneXxxFor`)으로 변경. |
| `app/test/core/widgets/miniroom_scene_test.dart` | NEW | 186줄, 36개 단위 테스트. 8개 슬롯 × (null / 2 known seeds / unknown seed) 커버. |

## TDD Evidence

**RED (production 변경 전, wall prefix 버그 재현):**
```
00:00 +0 -1: miniroom_scene wall variant painter lavender
Expected: Color(0xffede5f5)
  Actual: <null>
00:00 +1 -1: Some tests failed.
```

**GREEN (production 변경 후):**
```
00:00 +36: All tests passed!
```

## Tests Added

- `app/test/core/widgets/miniroom_scene_test.dart`
  - 8개 슬롯 각각: null → default color, `mr/xxx_variant1` → variant1 color, `mr/xxx_variant2` → variant2 color, unknown → default color
  - 총 36개 테스트 (8슬롯 × 4케이스 + 4개 공통 null case)

## QA Verdict

complete — targeted 36 passed. Full suite 134 passed, 2 pre-existing failures (`profile_setup_screen_test` — mock out-of-sync, 기존 결함; `my_room_screen_equip_wiring_test` 와 무관). `flutter analyze`: No issues found. `flutter build ios --simulator`: PASS (25.4s).

## Deploy Verification

- Backend health: N/A (서버 변경 없음)
- Simulator: running — device `463EC4CF-2080-47FE-8F26-530FFB713C06`, PID 89770, 로그인 화면 정상 렌더
- iOS build: `✓ Built build/ios/iphonesimulator/Runner.app` (25.4s)
- Clean install 순서 준수: terminate → uninstall → clean → build → install → launch
- Screenshots:
  - `docs/reports/screenshots/2026-04-21-feature-miniroom-variant-painter-01.png`
  - `docs/reports/screenshots/2026-04-21-feature-miniroom-variant-painter-02.png`

## Rollback Hints

- Files to revert:
  - `app/lib/core/widgets/miniroom_scene.dart` — 360줄 이전 버전으로 복원 (prefix 변경 및 슬롯 helper 6개 제거)
  - `app/test/core/widgets/miniroom_scene_test.dart` — 삭제
- Migrations to reverse: none

## Referenced Reports

- `docs/reports/2026-04-19-feature-room-decoration.md` — 부모 slice (migration 017, `mr/` 시드 출처)
- `docs/reports/2026-04-20-feature-miniroom-cyworld-wiring.md` — equip wiring slice (`wall/blue` legacy prefix 보존 근거)
- `docs/reports/2026-04-20-feature-miniroom-equip-wiring-tdd.md` — TDD 패턴 참고
- `docs/reports/2026-04-20-design-miniroom-cyworld-revise.md` — 디자인 스펙 개정 context

## Related

- `docs/reports/2026-04-21-feature-miniroom-slot-variant-painter.md` — end-of-slice feature report
- `test-reports/miniroom-slot-variant-painter-feature-test-report.md` — test execution evidence
- Design spec: `docs/design/specs/miniroom-cyworld.md`

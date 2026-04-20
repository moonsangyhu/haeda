# feat: Miniroom Cyworld Wiring Fix

- **Date**: 2026-04-20
- **Type**: fix
- **Area**: frontend
- **Worktree**: feature

## Requirement

`MyRoomScreen` 이 `myMiniroomProvider` 를 watch 하지 않고 `MiniroomScene` 에 `equip` 을 전달하지 않아, `RoomDecoratorScreen` 에서 저장한 벽/바닥 데코레이션이 내 방 탭에 렌더링되지 않는 버그 수정.

## Plan Source

Design spec: `docs/design/specs/miniroom-cyworld.md` (status: in-progress, `/implement-design` lock 보유)

수락 기준:
- `myMiniroomProvider` → `MiniroomScene.equip` 연결 완료
- widget test 2개: wiring 검증 + empty 회귀
- `flutter build ios --simulator` 성공
- 전체 flutter test 사이클 regression 없음

## Implementation

### Backend

N/A — 서버 파일 변경 없음.

### Frontend

| 파일 | 유형 | 설명 |
|------|------|------|
| `app/lib/features/character/screens/my_room_screen.dart` | MOD | Line 13: import 추가; Line 63: `ref.watch(myMiniroomProvider).valueOrNull`; Line 113: `equip: equip,` 전달 — 총 3줄 추가 |
| `app/test/features/character/screens/my_room_screen_equip_wiring_test.dart` | NEW | wiring test + empty-equip regression test (2개 위젯 테스트) |

## TDD Evidence

**RED (production 변경 전):**
```
00:00 +0 -1: MyRoomScreen equip wiring wiring test: MiniroomScene receives equip from myMiniroomProvider
Expected: 'wall/blue'
  Actual: <null>
00:00 +1 -1: Some tests failed.
```

**GREEN (production 변경 후):**
```
00:00 +1: MyRoomScreen equip wiring wiring test: MiniroomScene receives equip from myMiniroomProvider
00:00 +2: All tests passed!
```

## Tests Added

- `app/test/features/character/screens/my_room_screen_equip_wiring_test.dart`
  - `wiring test` — `myMiniroomProvider` 에 `wall/blue` equip 주입 → `MiniroomScene.equip?.wall?.assetKey == 'wall/blue'` 검증
  - `regression test` — `MiniroomEquip.empty()` 주입 → `wall == null`, `floor == null` 검증

## QA Verdict

complete — 전체 suite 98 passed, 1 pre-existing failure (`profile_setup_screen_test`, base commit `dc40541` 기준 기존 결함, 이번 변경과 무관). static analysis: 9 pre-existing issues, 0 new.

## Deploy Verification

- Backend health: N/A (서버 변경 없음)
- Simulator: running — device `463EC4CF-2080-47FE-8F26-530FFB713C06`, app installed + launched
- iOS build: `✓ Built build/ios/iphonesimulator/Runner.app`
- Screenshots:
  - `docs/reports/screenshots/2026-04-20-feature-miniroom-cyworld-wiring-01.png`
  - `docs/reports/screenshots/2026-04-20-feature-miniroom-cyworld-wiring-02.png`

## Rollback Hints

- Files to revert:
  - `app/lib/features/character/screens/my_room_screen.dart` — 3줄 되돌리기 (import + watch + equip 파라미터)
  - `app/test/features/character/screens/my_room_screen_equip_wiring_test.dart` — 삭제
- Migrations to reverse: none

## Related

- `docs/reports/2026-04-20-feature-miniroom-cyworld-wiring.md` — end-of-slice feature report
- `test-reports/miniroom-cyworld-wiring-feature-test-report.md` — test execution evidence
- `docs/reports/2026-04-20-feature-miniroom-equip-wiring-tdd.md` — builder's interim TDD-detail record
- `impl-log/feat-room-decoration-feature.md` — parent slice (MiniroomScene equip 파라미터가 여기서 추가됨)

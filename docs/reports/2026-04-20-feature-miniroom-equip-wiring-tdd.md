---
Date: 2026-04-20
Worktree (performed): feature
Worktree (affected): feature
Role: feature
---

# Miniroom Equip Wiring TDD Fix

## Request

Wire `myMiniroomProvider` into `MyRoomScreen.build()` and pass the resulting `MiniroomEquip` to `MiniroomScene(equip:)`. Validate the fix with a RED→GREEN widget test cycle.

## Root cause / Context

`MiniroomScene` already accepts an `equip` parameter (added during the miniroom-cyworld design spec implementation), but `MyRoomScreen` was never updated to read `myMiniroomProvider` and pass the value through. The connection was silently missing — no compile error, no runtime crash, just a null `equip` at runtime, so wall/floor asset overrides never activated.

A prior fix attempt produced a broken test file (invalid constructor calls, private method overrides) and was rolled back. This is the clean re-implementation from scratch.

## Actions

### Test file created (RED first)
`app/test/features/character/screens/my_room_screen_equip_wiring_test.dart`

Strategy:
- `_FakeRoomEquipApi` implements `RoomEquipApi` in the test file — returns a fixed `MiniroomEquip` without any network call.
- `dioProvider.overrideWithValue(_buildFakeDio())` — a `Dio` with 1ms timeout pointing at 127.0.0.1:1, causes `MyCharacterNotifier._load()` to throw immediately, falling back to the built-in `_mockCharacter`.
- `myMiniroomProvider.overrideWith((ref) => MyMiniroomNotifier(_FakeRoomEquipApi(equip)))` — real notifier, fake API.
- `authStateProvider` left un-overridden — `AuthState.build()` confirmed to return `const AsyncData(null)` with no side effects.

Two tests:
1. **Wiring test** — pumps with `MiniroomEquip(wall: EquippedItemBrief(..., assetKey: 'wall/blue'))`, asserts `MiniroomScene.equip?.wall?.assetKey == 'wall/blue'`. Initially RED.
2. **Regression test** — pumps with `MiniroomEquip.empty()`, asserts `wall` and `floor` are null. Initially passing.

### Production change (3 lines in `my_room_screen.dart`)

1. Added import: `import '../../room_decoration/providers/room_equip_provider.dart';`
2. Added in `build()`: `final equip = ref.watch(myMiniroomProvider).valueOrNull;`
3. Added `equip: equip,` to the `MiniroomScene(...)` call.

## Verification

**RED (before production change):**
```
00:00 +0 -1: MyRoomScreen equip wiring wiring test: MiniroomScene receives equip from myMiniroomProvider
Expected: 'wall/blue'
  Actual: <null>
00:00 +1 -1: Some tests failed.
```

**GREEN (after production change):**
```
00:00 +1: MyRoomScreen equip wiring wiring test: MiniroomScene receives equip from myMiniroomProvider
00:00 +2: All tests passed!
```

**iOS simulator build:**
```
Xcode build done.                                            7.2s
✓ Built build/ios/iphonesimulator/Runner.app
```

**flutter analyze (changed files only):**
- 8 pre-existing `withOpacity` deprecation infos (not introduced by this change)
- 1 pre-existing `_CoinTransactionSheet` unused warning (not introduced by this change)
- 0 new errors introduced by this fix

## Follow-ups

- The `_CoinTransactionSheet` unused element warning and `withOpacity` deprecations are pre-existing and separate from this fix. They can be addressed in a separate cleanup pass.
- No other worktrees need restarting; only `app/` files were changed.

## Related

- `docs/reports/2026-04-20-design-miniroom-cyworld-revise.md`
- `docs/reports/2026-04-19-feature-room-decoration.md`
- `docs/reports/2026-04-20-feature-character-cyworld-style.md` (independent rollback of cyworld-style, not affected by this fix)

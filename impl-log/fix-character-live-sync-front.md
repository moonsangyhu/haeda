# fix(app): reflect live character changes across verification & nudge screens

- **Date**: 2026-04-11
- **Commits**: 9f48845, f625ab9, 770c129
- **Area**: frontend

## Problem

Three issues were fixed in this session:

1. **HEAD build broken** — `my_room_screen.dart` (committed in 91f10c0) imported `TappableCharacter` from `app/lib/core/widgets/tappable_character.dart`, but that file was never committed. A fresh clone of `main` failed `flutter build ios --simulator`.

2. **Live character sync missing** — after a user equipped an item or saved appearance in the character shop, the change did not propagate to other screens until a manual refetch. The daily verification list, verification detail screen (author row), comment list, and calendar day sheet's nudge member list all kept rendering the stale `character` snapshot embedded in the original API response.

3. **Latent equip payload bug** — `character_provider.dart equipItem` sent `{slot: itemId}` in its PUT `/me/character` body, but the backend `CharacterUpdateRequest` schema expects `{'${slot}_item_id': itemId}`. Equips were never persisted server-side.

## Changed Files

| File | Change |
|------|--------|
| `app/lib/core/widgets/tappable_character.dart` | Added missing file (widget existed only as an import target; this commit makes it real) |
| `app/lib/features/character/providers/character_provider.dart` | Imports `calendar_provider`, `comment_provider`, `verification_provider`; adds `_invalidateCharacterConsumers()` called from `equipItem` and `saveAppearance`; fixes `equipItem` PUT payload to `{'${slot}_item_id': itemId}` |
| `app/lib/features/challenge_space/screens/daily_verifications_screen.dart` | `_VerificationListItem` converted to `ConsumerWidget`; prefers `ref.watch(myCharacterProvider).valueOrNull` over `item.user.character` when the item author is the current user |
| `app/lib/features/challenge_space/screens/verification_detail_screen.dart` | New private `_resolveCharacter(ref, userId, embedded)` helper; `_AuthorSection` and `_CommentItemTile` converted to `ConsumerWidget` and use the helper |
| `app/lib/features/challenge_space/widgets/member_nudge_list.dart` | `_MemberRow` converted to `ConsumerWidget`; resolves `effectiveCharacter` from `myCharacterProvider` when `isSelf`, otherwise falls back to `member.character`; `_showCharacterSheet` signature updated to accept `CharacterData?` |
| `app/macos/Flutter/Flutter-Debug.xcconfig` | Auto-regenerated after `flutter_contacts` pubspec addition |
| `app/macos/Flutter/Flutter-Release.xcconfig` | Auto-regenerated after `flutter_contacts` pubspec addition |
| `app/macos/Flutter/GeneratedPluginRegistrant.swift` | Auto-regenerated after `flutter_contacts` pubspec addition |

## Implementation Details

- `_invalidateCharacterConsumers()` calls `ref.invalidate` on `verificationDetailProvider`, `dailyVerificationsProvider`, and `calendarProvider`. This triggers a refetch on the next read of those providers, ensuring any screen that is currently mounted and observing those providers rebuilds with fresh data.
- The equip payload fix (`{'${slot}_item_id': itemId}`) aligns with the backend `CharacterUpdateRequest` schema. Without this fix the server silently accepted the request but applied no change.
- Screens that display another user's character (not the current user's) are intentionally left using the embedded snapshot — there is no provider to watch for other users.
- The macOS plugin files are routine churn from `flutter pub get` and do not affect iOS runtime.

## Tests & Build

- Analyze: not recorded (deployer did not capture analyze output separately)
- Tests: none added — UI/provider wiring change; existing test suite does not cover these providers
- Build: pass (`flutter build ios --simulator`, 33.4 s)
- Simulator: app launched on iPhone 17 simulator (UDID `48703B52-2ADA-4235-930D-5D96B52FCE67`), Dart VM service attached, first frame rendered

## Manual QA Status

**Pending** — live-sync behavior (equip item in shop → open verification screen → confirm avatar updated) was NOT manually exercised end-to-end in this session. The build gate passes; functional smoke test is deferred.

## Rollback

```
git revert 770c129
git revert f625ab9
git revert 9f48845
```

Reverting `9f48845` alone re-introduces the HEAD compile break in `my_room_screen.dart` (which still imports `TappableCharacter` from its original commit 91f10c0). Safe reversal of the sync fix only requires reverting `f625ab9`; reverting the build fix (`9f48845`) should only be done together with reverting 91f10c0.

## Out of Scope

- Untracked `app/ios/**` files visible in `git status` are pre-existing iOS scaffolding, not created by this session.
- Backend not rebuilt; no server/ changes were made.

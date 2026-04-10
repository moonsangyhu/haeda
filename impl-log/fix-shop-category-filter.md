# fix(app): fix shop category filtering and change price emoji to diamond

- **Date**: 2026-04-10
- **Commit**: b3aa128
- **Area**: frontend

## What Changed

Shop category tabs (모자/상의/하의/신발/액세서리) were showing no items because the frontend sent lowercase category keys ('hat', 'top', etc.) while the DB stores uppercase ('HAT', 'TOP', etc.). Also removed the "전체" (All) tab and changed price emoji from coin to diamond.

## Changed Files

| File | Change |
|------|--------|
| app/lib/features/character/screens/shop_screen.dart | Remove "전체" tab, uppercase category keys, 🪙→💎 emoji |
| app/lib/features/character/providers/shop_provider.dart | Update purchase cache invalidation to use uppercase category keys |

## Implementation Details

- Root cause: case mismatch between frontend category keys (lowercase) and DB seed data (uppercase)
- Removed null entry from `_categoryKeys` (was for "전체" tab)
- Changed all category keys to uppercase to match DB: HAT, TOP, BOTTOM, SHOES, ACCESSORY
- Changed price emoji from 🪙 to 💎 in both item card and detail sheet
- Changed "코인으로 구매" text to "보석으로 구매"
- Updated `shop_provider.dart` purchase invalidation to iterate uppercase categories instead of invalidating null

## Tests & Build

- Analyze: pass (6 pre-existing info-level warnings)
- Tests: skipped (UI-only change)
- Build: pass (flutter build ios --simulator)

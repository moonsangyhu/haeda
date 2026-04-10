# feat: add Duolingo-style status bar with streak, challenges, and gems

- **Date**: 2026-04-10
- **Commit**: 09e793f
- **Area**: both (backend + frontend)

## What Changed

Added a Duolingo-inspired top status bar visible across all tabs, showing the user's global streak count (consecutive verification days), active/completed challenge counts, and gem balance. Backend includes a new gem ledger system (gem_transactions table) and GET /me/stats endpoint. Gems are awarded on each verification (+5).

## Changed Files

| File | Change |
|------|--------|
| `server/app/models/gem_transaction.py` | New GemTransaction model (ledger-style) |
| `server/alembic/versions/20260410_0001_006_add_gem_transactions.py` | Migration: gem_transactions table + indexes |
| `server/app/services/gem_service.py` | award_gems() and get_balance() |
| `server/app/services/user_stats_service.py` | calculate_global_streak() + get_user_stats() |
| `server/app/models/__init__.py` | Added GemTransaction import |
| `server/app/models/user.py` | Added gem_transactions relationship |
| `server/app/routers/me.py` | Added GET /me/stats endpoint |
| `server/app/schemas/user.py` | Added UserStatsResponse schema |
| `server/app/services/verification_service.py` | Gem awarding on verification (+5) |
| `app/lib/features/status_bar/models/user_stats.dart` | Freezed UserStats model |
| `app/lib/features/status_bar/providers/user_stats_provider.dart` | FutureProvider for GET /me/stats |
| `app/lib/features/status_bar/widgets/status_bar.dart` | StatusBar ConsumerWidget (emoji icons + stats) |
| `app/lib/core/widgets/main_shell.dart` | Integrated StatusBar above navigationShell with SafeArea/MediaQuery |
| `app/lib/features/challenge_space/screens/create_verification_screen.dart` | Invalidate userStatsProvider after verification |

## Implementation Details

- **Gem system**: Ledger/transaction pattern — balance = SUM(amount). Avoids race conditions, supports future shop spend.
- **Global streak**: Cross-challenge calculation — SELECT DISTINCT date FROM verifications, walk backwards counting consecutive days.
- **StatusBar placement**: Column in MainShell body — SafeArea(bottom:false) for notch, MediaQuery.removePadding(removeTop:true) to prevent double SafeArea in child AppBars.
- **Icons**: Emoji-based (🌺/🥀 for streak, 🏃 for challenges, 💎 for gems) consistent with existing SeasonIcons pattern.
- **Challenge display**: "active/completed" format (e.g., "3/2") showing both progress and accomplishment.
- **Gem earning**: +5 per verification (integrated in verification_service.create_verification before commit).

## Tests & Build

- Analyze: pass (no new issues)
- Tests: skipped (uv not available in environment)
- Build: iOS simulator pass

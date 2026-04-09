# feat(app): add dark mode theme

- **Date**: 2026-04-09
- **PR**: #1 — https://github.com/moonsangyhu/haeda/pull/1
- **Branch**: feat/dark-mode
- **Area**: frontend + config

## What Changed

다크 모드 테마 지원 추가. 기존에 설정 UI 토글과 SharedPreferences 저장은 구현되어 있었지만, 실제 다크 ThemeData가 없고 MaterialApp에 연결되지 않아 동작하지 않았음. 다크 컬러 팔레트 정의, MaterialApp 연결, 하드코딩 색상 제거로 완성.

## Changed Files

| File | Change |
|------|--------|
| `app/lib/core/theme/app_theme.dart` | 다크 컬러 팔레트 상수 5개 추가 + `darkTheme` getter 추가 (227→397줄) |
| `app/lib/app.dart` | `HaedaApp`을 `StatelessWidget` → `ConsumerWidget` 전환, `darkTheme` + `themeMode` 속성 추가 |
| `app/lib/features/settings/screens/settings_screen.dart` | `AppTheme.*` 직접 참조 → `Theme.of(context).colorScheme.*` 교체, AppTheme import 제거 |
| `.claude/rules/agents.md` | Build Verification + Post-Implementation 섹션 추가 |
| `.claude/skills/commit/SKILL.md` | PR 생성 + 번호 prefix + impl-log 워크플로우 추가 |

## Implementation Details

**다크 컬러 팔레트**:
- `darkBackground`: `Color(0xFF1A1A2E)` — 딥 네이비
- `darkSurface`: `Color(0xFF25253E)`
- `darkTextPrimary`: `Color(0xFFF5F5F5)`
- `darkTextSecondary`: `Color(0xFFB0B0C0)`
- `darkOutline`: `Color(0xFF3D3D5C)`
- primary/accent는 라이트와 동일 유지 (핑크 `0xFFF48FB1` / 퍼플 `0xFFCE93D8`)

**MaterialApp 연결**: `HaedaApp`을 `ConsumerWidget`으로 변경하여 `settingsProvider`를 watch. `settings.darkMode` 값에 따라 `ThemeMode.dark` / `ThemeMode.light` 전환.

**설정 화면**: 기존 `AppTheme.primary`, `AppTheme.textPrimary`, `AppTheme.textSecondary`, `AppTheme.error` 하드코딩을 `theme.colorScheme.primary`, `.onSurface`, `.onSurfaceVariant`, `.error`로 교체. 다크모드에서도 올바른 색상 표시.

**롤백 시 주의사항**: `app.dart`의 `ConsumerWidget` 전환을 되돌릴 때 `flutter_riverpod`와 `settings_provider` import도 함께 제거해야 함.

## Tests & Build

- Analyze: pass (0 errors, 110 pre-existing warnings/infos)
- Tests: 92 passed, 0 failed
- Build: `flutter build web` — pass (✓ Built build/web)

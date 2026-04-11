# feat: character background color (my room tab)

**Date**: 2026-04-11
**Worktree**: feature
**Scope**: server + app + docs

## Summary

내 방 탭에서 캐릭터가 주변 UI에 묻혀 돋보이지 않는 문제를 해결하기 위해, 캐릭터를 원형 컬러 배경 위에 올리고 배경색을 유저별 고유색으로 저장한다. 유저는 캐릭터 생성 온보딩에서 최초 1회 배경색을 선택하며, 이후 내 방 탭의 원을 길게 누르면 컬러 피커 바텀시트로 변경할 수 있다.

## Changes

### Docs
- `docs/domain-model.md` §2.1 — User 테이블에 `background_color VARCHAR(9) NULLABLE` 추가
- `docs/api-contract.md`
  - POST `/auth/kakao` 응답 user 객체에 `background_color` 추가
  - PUT `/auth/profile` 요청/응답에 `background_color` 추가, 에러 코드 `INVALID_BACKGROUND_COLOR` 신설

### Backend (`server/`)
- `app/models/user.py` — `background_color: Mapped[str | None]` (VARCHAR 9) 컬럼 추가
- `alembic/versions/20260411_0001_013_add_user_background_color.py` — ADD COLUMN 마이그레이션 신규
- `app/schemas/user.py` — `UserBrief`, `UserWithIsNew`, `ProfileUpdateResponse`에 `background_color: str | None` 추가
- `app/services/auth_service.py`
  - `ALLOWED_BACKGROUND_COLORS` 화이트리스트 8색 정의 (Flutter 팔레트와 동기화)
  - `update_profile()` 시그니처 변경: `nickname` → optional, 새 파라미터 `background_color`
  - 색상 정규화(대문자) + 화이트리스트 검증, 위반 시 `INVALID_BACKGROUND_COLOR` 400
- `app/routers/auth.py`
  - PUT `/auth/profile` — `nickname`을 `str | None = None`으로 완화, `background_color: str | None = None` 폼 필드 추가
  - 카카오/dev 로그인 응답 `UserWithIsNew`에 `background_color` 포함
- `app/routers/me.py` — GET `/me` 응답 `UserBrief`에 `background_color` 반영
- `tests/test_auth.py` — background_color 성공/무효/대소문자 정규화/닉네임 없이 단독 업데이트 총 4개 케이스 추가

### Frontend (`app/`)
- `lib/core/theme/app_theme.dart` — `characterBackgroundPalette` (8색 파스텔 상수) + `characterBackgroundFromHex()` 헬퍼 추가
- `lib/features/auth/models/auth_models.dart` — `AuthUser`, `ProfileUpdateData`에 `backgroundColor: String?` 필드 추가 (build_runner 재생성)
- `lib/features/auth/providers/auth_provider.dart`
  - `checkAuthOnStartup()`에서 `/me` 응답의 `background_color` 복원
  - `updateProfile()` 시그니처 변경: `nickname`/`profileImage`/`backgroundColor` 모두 optional, multipart form에 선택적 포함, 응답을 `copyWith`로 반영
- `lib/features/character/screens/character_creation_screen.dart`
  - `_selectedBackgroundIndex` 상태 추가
  - 머리스타일 섹션 아래에 `_buildBackgroundSection()` 신규 — 피부톤 circular picker 패턴 재사용, 8색 원형 버튼 + 체크 아이콘
  - 미리보기 원형 컨테이너 색상이 선택한 배경색으로 변경
  - `_onDone()`에서 `authStateProvider.updateProfile(backgroundColor: ...)` → `saveAppearance()` 순서로 호출
- `lib/features/character/screens/my_room_screen.dart`
  - 기존 `TappableCharacter` 영역을 새로운 `_CharacterOrb` 위젯으로 교체 — 원형 컨테이너(170×170) + 이중 shadow + 내부 `CharacterAvatar(size: 130)`
  - `_showBackgroundPicker()` — 길게 눌러 바텀시트 오픈 후 `updateProfile(backgroundColor: ...)` 호출, 실패 시 SnackBar
  - `_BackgroundPickerSheet` — 팔레트 8색 Wrap + 현재 선택 강조
  - 배경색은 `ref.watch(authStateProvider).user?.backgroundColor`에서 읽고 null이면 팔레트[0] 기본값

## Verification

### Backend
- `docker compose up --build -d backend` → `feature-backend-1 Started`
- 마이그레이션 013 로그 확인: `Running upgrade 012 -> 013, add background_color to users`
- `curl /health` → `{"status":"ok"}`
- E2E curl:
  - `PUT /auth/profile` with `background_color=#F8BBD0` → 200, 응답에 `"background_color":"#F8BBD0"`
  - `PUT /auth/profile` with `background_color=#123456` → `{"error":{"code":"INVALID_BACKGROUND_COLOR",...}}`
  - `GET /me` → 저장된 색상이 `background_color` 필드로 반환됨
- pytest: **13 passed in 0.23s** (`tests/test_auth.py` — 기존 9 + 신규 4)

### Frontend
- `dart run build_runner build --delete-conflicting-outputs` → 1072 outputs 성공
- `flutter analyze` 편집 파일 5개 → 0 errors (기존 deprecation info만 존재)
- `flutter build ios --simulator --debug` → `Built build/ios/iphonesimulator/Runner.app` (13.7s)
- `xcrun simctl install/launch booted com.example.haeda` → `com.example.haeda: 75326` (iPhone 17 / iOS 26.4)

## Notes

- 서버 화이트리스트와 Flutter 팔레트는 하드코딩으로 동기화되어 있다. 팔레트 변경 시 두 곳을 함께 수정해야 한다.
- `update_profile` 엔드포인트는 기존 호출자(닉네임만 보내는 profile_setup)와의 호환을 위해 nickname을 optional로 만들었다. 닉네임만 보내는 호출은 그대로 동작한다.
- 원형 배경은 `_CharacterOrb` ConsumerWidget으로 분리되어 `authStateProvider` 변경에 즉시 재빌드된다. long-press 피커에서 색 변경 시 서버 → provider 상태 → orb 순으로 반영된다.

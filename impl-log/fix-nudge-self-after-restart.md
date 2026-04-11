# fix(app,server): prevent self-nudge after app restart

- **Date**: 2026-04-11
- **Commit**: cc85b72
- **Area**: both

## What Changed

멤버 목록에서 "콕!" 버튼을 누르면 "오류가 발생했어요" 스낵바가 뜨던 버그. 앱 재시작 후 `authStateProvider` 가 rehydrate 되지 않아 `currentUserId == null` 이 되고, `MemberNudgeList` 의 `isSelf` 체크가 모든 멤버에 대해 false 가 되면서 자기 자신 행도 탭 가능해졌다. 탭하면 백엔드가 `CANNOT_NUDGE_SELF` (400) 를 반환하지만 에러 핸들러에 해당 코드 케이스가 없어 default "오류가 발생했어요"로 떨어졌다.

## Changed Files

| File | Change |
|------|--------|
| `server/app/routers/me.py` | `GET /me` 엔드포인트 추가 (UserBrief 반환) |
| `app/lib/features/auth/providers/auth_provider.dart` | `checkAuthOnStartup()` 가 토큰 있으면 `/me` 호출 후 state 주입, 401 이면 토큰 삭제 |
| `app/lib/features/auth/screens/splash_screen.dart` | splash 에서 `checkAuthOnStartup()` 를 await 후 `authStateProvider.valueOrNull` 기반 라우팅 |
| `app/lib/features/challenge_space/widgets/member_nudge_list.dart` | 에러 switch 에 `CANNOT_NUDGE_SELF` 케이스 추가 |
| `app/lib/features/challenge_space/widgets/nudge_bottom_sheet.dart` | 동일 |

## Implementation Details

- **근본 원인 진단**: DB 확인 결과 해당 챌린지의 오늘 verification 0건, status=active 이라 가능한 400 코드는 `CANNOT_NUDGE_SELF` 뿐이었음. 백엔드 로그의 400→201 시퀀스는 유저가 자기 행 탭 → 다른 멤버 탭 순서로 재현됨.
- **auth_provider**: `AuthUser.fromJson` 은 `is_new` 가 required 라서 `/me` 응답(해당 필드 없음)을 직접 매핑 불가 → `AuthUser(...)` 수동 생성 + `isNew: false`.
- **splash**: 기존엔 토큰 존재 여부만 체크하고 state 는 건드리지 않음 → 토큰 유효성 검증까지 포함하도록 변경. `/me` 401 시 토큰 삭제 → `/login` 이동.
- **에러 핸들러**: 기본 케이스 메시지는 유지하되 `CANNOT_NUDGE_SELF` 만 추가 ("자기 자신을 콕 찌를 수는 없어요"). 프론트 방어 로직(`isSelf`)이 동작하면 실제로는 도달하지 않음.
- 라우터 prefix `/me` 에 `@router.get("")` 패턴으로 최상위 경로 추가. 기존 `/me/character` 등과 충돌 없음.

## Tests & Build

- Backend pytest: 82 passed (backend-builder 실행)
- Backend curl 검증: `GET /api/v1/me` (토큰) → 200 `{"data":{"id":"...","nickname":"김철수",...}}`, 무토큰 → 401 UNAUTHORIZED
- Flutter analyze: 0 errors (168 pre-existing warnings/infos)
- Flutter build ios --simulator: pass
- Simulator 실행 확인: `GET /api/v1/me` 200 OK 호출 확인 (backend 로그), 앱 화면 정상 표시

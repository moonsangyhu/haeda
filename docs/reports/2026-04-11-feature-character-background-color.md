# 2026-04-11 feature report — character background color

**Role**: feature worktree (cross-layer)
**Slug**: character-background-color

## Request

> 하위에 내 방 모양 탭에 내 캐릭터가 좀 더 돋보일 수 있게 동그란 배경 안에 들어가야 해. 배경 안에 색은 사용자마다 최초에 선택하고 고유해야 해.

## Decisions

| 항목 | 선택 | 근거 |
|------|------|------|
| 저장소 | 서버 `users.background_color` | 기기 바뀌어도 유지, 유저 답변 |
| 최초 선택 시점 | 캐릭터 생성 화면 | 이미 circular picker 패턴 존재 |
| 변경 UX | 내 방 탭 원형 배경 long-press | 별도 설정 메뉴 불필요 |
| 팔레트 | 파스텔 8색 고정 화이트리스트 | 자유 hex보다 일관성 + 서버 검증 단순 |

## Affected Layers

- Backend: users 테이블, PUT /auth/profile, GET /me, 카카오/dev 로그인
- Frontend: theme 팔레트, auth 모델, 캐릭터 생성, 내 방 탭
- Docs: domain-model §2.1, api-contract Auth 섹션

## Verification Summary

| 항목 | 결과 |
|------|------|
| Alembic migration 013 | ✅ Running upgrade 012 → 013 |
| Backend health | ✅ `{"status":"ok"}` |
| PUT /auth/profile (valid) | ✅ 200, 응답 반영 |
| PUT /auth/profile (invalid) | ✅ 400 INVALID_BACKGROUND_COLOR |
| GET /me | ✅ background_color 포함 |
| pytest tests/test_auth.py | ✅ 13 passed in 0.23s |
| flutter build ios --simulator | ✅ Built Runner.app (13.7s) |
| iPhone 17 simulator launch | ✅ pid 75326 |

## Risks / Followups

- 팔레트는 서버 `ALLOWED_BACKGROUND_COLORS`와 Flutter `characterBackgroundPalette`가 하드코딩으로 동기화. 확장 시 두 곳 동시 수정 필요.
- 기존 유저(background_color=NULL)는 기본값 팔레트[0] (#FFCDD2)로 fallback. 마이그레이션 없이 즉시 표시 가능.
- 시뮬레이터 실제 UI 시각 검증은 유저가 내 방 탭에 진입해 원형 배경과 long-press 피커 동작을 직접 확인해야 완성.

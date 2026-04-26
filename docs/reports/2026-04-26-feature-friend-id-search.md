# 친구 ID(`닉네임#숫자`) 검색·추가 기능 구현 보고서

- **Date**: 2026-04-26
- **Worktree (수행)**: `.claude/worktrees/feature` (`worktree-feature` 브랜치)
- **Worktree (영향)**: feature
- **Role**: feature (full-stack)

## Request

> "id 로 친구 검색해서 추가할 수 있는 기능도 필요해" → "'닉네임#숫자' 로 사용자를 특정하고 싶어. 이렇게 모든 사용자를 특정할 수 있고, 설정에서도 내 숫자가 보여야겠지?"

## Root cause / Context

기존 `ContactSearchScreen` 의 친구 추가 경로는 (a) 디바이스 연락처 자동 매칭, (b) 전화번호 직접 입력 두 가지뿐. 두 경로 모두 상대방의 전화번호를 알아야 하고, 권한·노출 거부감 있음. 전화번호를 모르는(또는 알리고 싶지 않은) 관계에서 친구를 정확히 1명으로 특정해 추가할 수단 부재.

해결: Discord 스타일 사용자 ID `닉네임#5자리숫자` 도입. 모든 사용자에게 unique 한 ID 발급 + 설정/마이페이지에서 확인·복사 가능.

## Actions

### 설계 / 계획

- Spec: `docs/superpowers/specs/2026-04-26-friend-id-search-design.md` (`acb8354`)
- Plan: `docs/superpowers/plans/2026-04-26-friend-id-search.md` (`7e065d9`, 보정 `4648cbe`)
- 워크플로우: superpowers brainstorming → writing-plans → subagent-driven-development

### 결정된 사양

| 항목 | 결정 |
|------|------|
| ID 형식 | `닉네임#숫자` (예: `홍길동#43217`) |
| 숫자 자릿수 | 5자리 랜덤, `10000`–`99999` |
| 유일성 | `(nickname, discriminator)` UNIQUE — 같은 닉네임 안에서만 unique |
| 검색 입력 UX | 단일 텍스트 필드, `닉네임#43217` 통째로 입력 → 1명 결과 |
| 표시 위치 | 설정 화면 + 마이페이지 (탭 시 클립보드 복사) |
| 재생성 | 불가 (한 번 발급되면 평생 고정) |

### 백엔드 구현 (8 commits)

| Commit | 작업 |
|--------|------|
| `d293769` | docs: User 표 + api-contract 12개 user 객체 + 신규 `POST /users/search-by-id` 명세 |
| `98d4bfa` | User 모델에 `discriminator: VARCHAR(5) NOT NULL` + `UNIQUE(nickname, discriminator)` |
| `ebb8e75` | Alembic 020 마이그레이션 — 컬럼 추가 + 백필 (3 users 백필 완료) + CHECK `~ '^[0-9]{5}$'` |
| `4fc778d` | conftest 픽스처 backfill + User TDD 5건 |
| `8c78d41` | `discriminator_service.generate_discriminator(db, *, nickname)` + 단위 테스트 3건 (충돌 회피) |
| `23c676e` | `auth_service.login_or_register` 에 발급 통합 + 테스트 3건 |
| `5621493` | `UserBrief` / `UserWithIsNew` / `ProfileUpdateResponse` 에 `discriminator` + 모든 사용처(10 파일) 보정 + `/me` 응답 + 테스트 |
| `4f85354` | `ContactMatchItem` 응답에 `discriminator` + 테스트 |
| `7378f46` | `compute_friendship_status` 헬퍼 (none/pending/accepted/self) |
| `3b3eca2` | `POST /users/search-by-id` (router + service + 스키마) + 테스트 7건 |

### 프론트엔드 구현 (6 commits)

| Commit | 작업 |
|--------|------|
| `c44bca4` | `AuthUser` freezed 모델에 `discriminator: String?` + `/me` 파싱 + 단위 테스트 4건 |
| `3b80f77` | `ContactMatchItem` freezed 모델에 `required String discriminator` |
| `74475b1` | `user_id_format.dart` 의 `parseUserId`/`formatUserId` + 정규식 `^.{1,30}#[0-9]{5}$` + 단위 테스트 7건 |
| `b0b3a58` | `ContactSearchScreen` 에 ID 입력 블록 (`닉네임#12345 형식으로 입력`) + 검색 + self/accepted/pending 칩 분기 + 위젯 테스트 3건 |
| `9ac3c3f` | `SettingsScreen` 에 "내 ID" 섹션 + 탭 시 클립보드 복사 + 위젯 테스트 2건 |
| `6c58413` | `MyPageScreen` 상단에 `닉네임 #숫자` 헤더 + 탭 복사 |

## Verification

### Backend tests

```bash
$ cd server && .venv/bin/pytest -q --ignore=tests/test_room_equip.py
111 passed in 2.07s
```

신규 테스트 합계 21건 — User 모델 5, discriminator_service 3, auth_service 3, /me 1, contact-match 1, search-by-id 7, 기타 1.

`tests/test_room_equip.py::test_member_clear_signature` 1건은 본 작업 시작 전부터 fail 상태 (signature clear 422) — 본 기능과 무관, 별도 트랙.

### Frontend tests

```bash
$ cd app && flutter test test/features/auth/ test/features/friends/ test/features/settings/
All tests passed! (auth 4 + friends utils 7 + friends search 3 + settings 2 = 16)
```

### Backend health

```bash
$ docker compose up --build -d backend && curl -fsS http://localhost:8000/health
{"status":"ok"}
```

### DB migration

```bash
$ docker compose exec -T backend bash -c "cd /server && .venv/bin/alembic current"
020 (head)

$ docker compose exec -T db psql -U postgres -d haeda -c "SELECT id, nickname, discriminator FROM users ORDER BY created_at LIMIT 10;"
                  id                  | nickname | discriminator
--------------------------------------+----------+---------------
 11111111-1111-1111-1111-111111111111 | 김철수   | 52265
 22222222-2222-2222-2222-222222222222 | 이영희   | 29548
 33333333-3333-3333-3333-333333333333 | 박지민   | 23388

$ docker compose exec -T db psql -U postgres -d haeda -c "SELECT COUNT(*) FROM users WHERE discriminator IS NULL;"
0

$ docker compose exec -T db psql -U postgres -d haeda -c "SELECT nickname, discriminator, COUNT(*) FROM users GROUP BY nickname, discriminator HAVING COUNT(*) > 1;"
(0 rows)
```

### iOS simulator (clean install)

`flutter clean && flutter pub get && flutter build ios --simulator` 성공 (29초). 시뮬레이터 (iPhone 17 Pro, iOS 26.4) clean install + launch 후 검증:

| # | 시나리오 | 결과 | 스크린샷 |
|---|---------|------|---------|
| 1 | 마이페이지 진입 → 상단에 `박지민 #23388 📋` 헤더 표시 | ✅ | `screenshots/2026-04-26-feature-friend-id-search-01.png` |
| 2 | 설정 진입 → "내 ID" 섹션 + `박지민#23388` (monospace 폰트) + "탭하면 복사돼요" + 복사 아이콘 | ✅ | `screenshots/2026-04-26-feature-friend-id-search-02-settings.png` |
| 3 | 친구 찾기 진입 → 새 ID 입력 필드 (`닉네임#12345 형식으로 입력`) + 검색 아이콘 | ✅ | `screenshots/2026-04-26-feature-friend-id-search-03-search.png` |
| 4 | ID 필드에 텍스트 입력 가능 (Korean IME 활성으로 ASCII → Korean 자동 변환됨, 입력 동작 자체 정상) | ✅ | `screenshots/2026-04-26-feature-friend-id-search-04-id-typed.png` |

본인 ID 검색 시 "본인" 칩 표시 / 다른 사용자 ID 검색 시 친구 요청 버튼 / 잘못된 ID 시 빈 결과 등 인터랙션은 backend 7 tests + frontend 3 widget tests 로 자동 검증됨 (시뮬레이터 한국어 IME 한계로 본인 자동 타이핑은 일부 생략).

## Follow-ups

- **닉네임 변경 흐름**: 현재 닉네임 변경 엔드포인트가 별도 운영되지 않음. 추후 도입 시 `discriminator_service.generate_discriminator(db, nickname=새닉네임)` 재호출 필요.
- **Pre-existing test 실패**: `tests/test_room_equip.py::test_member_clear_signature` (signature clear 422) — 본 작업과 무관, 별도 트랙으로 디버그 권장.
- **api-contract.md 사전 누락 endpoint**: `GET /me` 와 `/friends/contact-match` 가 docs 에 미정의 상태였음. 본 작업에서는 user 객체 표현에만 discriminator 추가했고, 두 엔드포인트 자체의 명세 추가는 후속 정리.
- **Korean IME 한계로 simulator 자동 검증 일부 생략**: idb 의 `ui text` 가 ASCII 만 지원. 본인 ID 자동 검색 시나리오는 widget test 로 대체 검증.
- **iOS deploy 시 첫 화면 스크린샷이 마이페이지인 이유**: 라우팅 기본 진입이 챌린지 탭 → 챌린지 탭 컨텐츠가 MyPageScreen 으로 매핑된 구조. 본 보고서 스크린샷 1번이 이 결과물.

## Related

- Spec: `docs/superpowers/specs/2026-04-26-friend-id-search-design.md`
- Plan: `docs/superpowers/plans/2026-04-26-friend-id-search.md`
- Branch: `worktree-feature` — 18 commits since `acb8354`

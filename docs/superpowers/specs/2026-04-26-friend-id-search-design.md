# 친구 ID(`닉네임#숫자`) 검색·추가 기능 설계

- 작성일: 2026-04-26
- 상태: ready (사용자 검토 대기)
- 범위: full-stack (server + app)
- 우선순위: P0 (친구 추가 경로 보강)

## 1. 배경 / 문제

현재 친구 추가 경로는 `ContactSearchScreen` 의 (a) 디바이스 연락처 자동 매칭, (b) 전화번호 직접 입력 두 가지뿐이다. 두 경로 모두 상대방의 전화번호를 알아야만 가능하고, 연락처 권한·전화번호 노출에 대한 사용자 거부감이 있다. 전화번호를 모르는 (또는 알리고 싶지 않은) 관계에서 친구를 정확히 1명으로 특정해 추가할 수단이 없다.

해결: Discord 스타일의 사용자 ID `닉네임#숫자` 도입. 모든 사용자에게 unique 한 ID 를 발급해, 상대가 자기 ID 를 알려주면 그 ID 로 정확히 한 명을 검색·추가할 수 있게 한다. 내 ID 는 설정 / 마이페이지에서 확인·복사 가능하다.

## 2. 결정된 사항 요약

| 항목 | 결정 |
|------|------|
| ID 형식 | `닉네임#숫자` (예: `홍길동#43217`) |
| 숫자 자릿수 | **5자리 랜덤**, 범위 `10000`–`99999` |
| 유일성 | `(nickname, discriminator)` 쌍이 unique. 같은 숫자가 닉네임 다르면 공존 가능 |
| 검색 입력 UX | 단일 텍스트 필드, `닉네임#43217` 통째로 입력 → 정확히 1명 결과 |
| 표시 위치 | 설정 화면 + 마이페이지 닉네임 옆 |
| 상호작용 | 탭하면 클립보드 복사 + 토스트 "ID 복사됨" |
| 재생성 (숫자 변경) | **불가** (한 번 발급되면 평생 고정) |

## 3. 데이터 모델 변경

### 3.1 `users` 테이블

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `discriminator` | `VARCHAR(5)` | `NOT NULL` | 5자리 숫자 문자열 (`'10000'`–`'99999'`) |

추가 제약:

- `UNIQUE (nickname, discriminator)` — 닉네임당 같은 숫자 중복 방지
- `CHECK (discriminator ~ '^[0-9]{5}$')` — 형식 강제

### 3.2 소스-오브-트루스 문서 변경

본 spec 의 사용자 승인이 곧 문서 수정 승인이다.

- `docs/domain-model.md` §2.1 User 표에 `discriminator` row 추가
- `docs/api-contract.md` 의 user 응답 스키마 (다음 위치들) 에 `discriminator` 필드 추가:
  - `GET /me` 응답
  - `GET /users/{user_id}/character` 응답에 포함된 user 정보 (포함되어 있다면)
  - `/friends/contact-match` 응답의 매치 항목 (일관성 위해 추가)
  - 신설 `POST /users/search-by-id` 응답
  - 친구 목록·요청 등에 등장하는 user 표현 모두

## 4. 마이그레이션 — 기존 사용자 백필

Alembic migration 1개로 처리:

1. `discriminator` 컬럼을 `NULLABLE` 로 추가
2. Python 단계에서 모든 기존 `users` 를 `nickname` 별 그룹핑, 각 그룹 내에서 unique 한 5자리 숫자를 random 으로 배정
   - 그룹 내에서 이미 사용된 숫자는 set 에 보관, 충돌 시 재롤
   - 한 닉네임당 90,000 슬롯 기준 충돌 가능성 무시 가능 수준
3. `NOT NULL` + `UNIQUE (nickname, discriminator)` + `CHECK` 제약 추가

다운그레이드: 컬럼 삭제 (제약 자동 제거 후).

## 5. 신규 가입 / 닉네임 변경 시 발급 로직

### 5.1 가입 시점

`auth_service` 의 카카오 OAuth 첫 가입 흐름에서 `User` insert 직전:

```
1. 결정된 nickname 으로 같은 닉네임의 기존 discriminator 집합을 조회
2. random.randint(10000, 99999) 시도
3. 집합에 없으면 채택, 있으면 재롤 (최대 5회)
4. 5회 모두 실패하면 NICKNAME_FULL 에러 (사용자에게 닉네임 변경 안내)
```

90,000 슬롯이 모두 차야 5회 연속 실패가 발생하므로 MVP 규모에서 사실상 일어나지 않지만, 코드는 안전망을 갖춘다.

### 5.2 닉네임 변경 시점

본 spec 범위에서는 별도 처리하지 않는다. (현재 닉네임 변경 엔드포인트가 존재하지 않으면 본 작업과 무관. 존재한다면 후속 작업으로 5.1 과 동일한 로직 — "현재 discriminator 가 새 닉네임 그룹에 없으면 유지, 있으면 재발급" — 을 추가한다. 본 spec 의 implementation plan 단계에서 확인.)

## 6. 백엔드 API — `POST /users/search-by-id`

```
POST /users/search-by-id
Authorization: Bearer <token>
Content-Type: application/json

Request body:
{
  "nickname": "홍길동",
  "discriminator": "43217"
}

200 OK
{
  "data": {
    "user_id": "uuid",
    "nickname": "홍길동",
    "discriminator": "43217",
    "profile_image_url": "https://...",
    "friendship_status": "none" | "pending" | "accepted" | "self"
  }
}

404 Not Found
{
  "error": { "code": "USER_NOT_FOUND", "message": "해당 ID 를 가진 사용자를 찾을 수 없어요." }
}

400 Bad Request
{
  "error": { "code": "INVALID_ID_FORMAT", "message": "ID 형식이 올바르지 않아요." }
}

401 Unauthorized
{
  "error": { "code": "UNAUTHORIZED", "message": "..." }
}
```

설계 노트:

- POST 선택 이유: `#` 가 URL fragment 라 GET 쿼리 인코딩 이슈 회피. body 가 깔끔.
- `friendship_status` 의 `self` 는 본인을 검색한 경우. 클라이언트는 "본인" 칩만 표시하고 친구 요청 버튼은 숨긴다.
- 라우터: `server/app/routers/users.py` 에 추가
- 서비스: `friend_service` 에 `friendship_status` 계산 헬퍼가 이미 있다면 재사용. 없다면 `friend_service.compute_friendship_status(viewer_id, target_id)` 신설하고 `/friends/contact-match` 도 같은 함수를 쓰도록 정리

## 7. 프론트 — 친구 찾기 화면 입력 추가

`app/lib/features/friends/screens/contact_search_screen.dart` 에 세 번째 입력 블록 추가:

```
┌──────────────────────────────────────┐
│ [연락처에서 친구 찾기]                │  ← 기존
├──────────────────────────────────────┤
│ ─── 또는 직접 검색 ───                │
│ [📞 전화번호 입력           🔍]       │  ← 기존
│ [@ 닉네임#43217 입력         🔍]       │  ← NEW
└──────────────────────────────────────┘
        결과 영역 (재사용)
```

- 입력 검증: 정규식 `^.{2,30}#[0-9]{5}$` 만족 시에만 검색 활성화
  - 최소 2자, 최대 30자 닉네임 (User.nickname 길이 정책과 일치)
  - 5자리 숫자 강제
- 분리 파싱: `parts = input.split('#')` → `parts[0]` 닉네임, `parts[1]` discriminator
- 검색 결과: 단일 항목. 기존 `_buildMatchTile` 위젯 재사용
  - `friendship_status == 'self'` 면 "본인" 칩 (중성 색) + 친구 요청 버튼 숨김
  - 그 외는 기존 로직과 동일 (none → 친구 요청 버튼, pending → "요청됨" 칩, accepted → "친구" 칩)
- 빈 입력 / 형식 미달일 때는 검색 비활성. 검색 후 404 면 "해당 ID 를 가진 사용자를 찾을 수 없어요." 표시

상태 관리: 기존 화면이 `ConsumerStatefulWidget` 이므로 동일 패턴으로 `_idController`, `_idSearchLoading` 추가.

## 8. 프론트 — 내 ID 표시

### 8.1 설정 화면 (`app/lib/features/settings/screens/settings_screen.dart`)

상단에 "내 ID" 섹션 추가:

```
┌─────────────────────────────────────┐
│ 내 ID                               │
│ ┌─────────────────────────────────┐ │
│ │ 홍길동#43217           [📋 복사] │ │  ← 행 탭 = 복사
│ └─────────────────────────────────┘ │
│ 친구에게 알려주면 ID 로 추가할 수 있어요 │
└─────────────────────────────────────┘
```

- 탭 동작: `Clipboard.setData(ClipboardData(text: '$nickname#$discriminator'))` + 토스트 "ID 복사됨"
- 데이터 소스: `GET /me` 응답의 `nickname` + `discriminator`

### 8.2 마이페이지 (`app/lib/features/my_page/screens/my_page_screen.dart`)

기존 닉네임 표시 옆에 작게 discriminator 추가:

```
홍길동  #43217        ← #43217 은 12sp, 회색 (theme.colorScheme.onSurfaceVariant)
```

- 닉네임+ID 영역 전체 탭하면 풀 ID 복사 + 토스트
- 시각적 강조 없음 (조용한 보조 정보)

## 9. 모델 / 응답 동기화

### 9.1 백엔드

- `server/app/schemas/user.py` 의 user-out 스키마에 `discriminator: str` 필드 추가
- `GET /me` 응답 (router: `server/app/routers/me.py`) 에 `discriminator` 포함되도록 serializer 조정
- `/friends/contact-match` 응답의 `ContactMatchItem` 에 `discriminator` 포함

### 9.2 프론트엔드

- `app/lib/features/friends/models/friend_data.dart` 의 `ContactMatchItem` 에 `discriminator` 필드 추가 (freezed → `flutter pub run build_runner build`)
- `app/lib/features/auth/providers/auth_provider.dart` 의 `AuthUser` 에 `discriminator: String?` 필드 추가 + `/me` 응답 파싱부 (`map['discriminator']`) 보강. (현재 `AuthUser` 가 freezed 가 아닌 단순 클래스이므로 build_runner 불필요)

## 10. 엣지 케이스 / 에러 처리

| 케이스 | 동작 |
|--------|------|
| 입력이 형식 불일치 (`#` 없음, 숫자 아님 등) | 검색 버튼 비활성. 활성화되어 있어도 백엔드는 400 `INVALID_ID_FORMAT` |
| 존재하지 않는 ID | 404 `USER_NOT_FOUND` → "해당 ID 를 가진 사용자를 찾을 수 없어요." |
| 본인 ID 검색 | `friendship_status: "self"` → "본인" 칩, 요청 버튼 숨김 |
| 이미 친구 | `friendship_status: "accepted"` → "친구" 칩 |
| 요청 보낸 상태 | `friendship_status: "pending"` → "요청됨" 칩 |
| 같은 닉네임 90,000명 도달 | 가입 시 `NICKNAME_FULL` 에러로 닉네임 변경 안내 (실질적 발생 X) |
| 클립보드 복사 실패 (드물게) | 토스트 "복사하지 못했어요" |

## 11. 테스트 전략 (TDD 의무)

### 11.1 백엔드 (`server/tests/`)

- **Migration**: `test_migration_discriminator_backfill.py` — 기존 사용자가 있는 상태에서 마이그레이션 실행 후 모든 행이 unique `(nickname, discriminator)` 만족 + CHECK 통과
- **auth_service**: `test_signup_assigns_discriminator.py` — 같은 닉네임 다수 가입 시 충돌 없이 발급 (random 을 mock 해 결정성 확보), 5회 실패 시 `NICKNAME_FULL`
- **router `/users/search-by-id`**: `test_users_search_by_id.py`
  - 200: 정상 조회
  - 404: 존재하지 않음
  - 400: 형식 불일치
  - 401: 인증 누락
  - friendship_status 분기: none / pending / accepted / self 각각

### 11.2 프론트엔드 (`app/test/`)

- ID 입력 검증 정규식 단위 테스트
- `ContactSearchScreen` 위젯 테스트:
  - ID 입력 → 검색 → 결과 카드 표시
  - 404 빈 상태 메시지
  - "본인" 케이스에 요청 버튼 숨김
- `SettingsScreen` 위젯 테스트: ID 표시 + 탭 시 클립보드 복사 호출
- `MyPageScreen` 위젯 테스트: 닉네임 옆 discriminator 표시

## 12. 구현 영향 파일 (예상)

### Server

- `server/app/migrations/versions/<new>_add_user_discriminator.py` (신규)
- `server/app/models/user.py` (필드 + 제약 추가)
- `server/app/schemas/user.py` (응답 스키마 필드 추가)
- `server/app/services/auth_service.py` (가입 시 발급 로직)
- `server/app/services/user_service.py` 또는 신규 헬퍼 (discriminator 발급 함수)
- `server/app/services/friend_service.py` (`compute_friendship_status` 헬퍼 + contact-match 응답)
- `server/app/routers/users.py` (`POST /users/search-by-id` 추가)
- `server/tests/...` (위 11.1 의 테스트들)

### App

- `app/lib/features/friends/screens/contact_search_screen.dart` (ID 검색 입력 추가)
- `app/lib/features/friends/models/friend_data.dart` (ContactMatchItem 에 discriminator)
- `app/lib/features/settings/screens/settings_screen.dart` (내 ID 섹션)
- `app/lib/features/my_page/screens/my_page_screen.dart` (닉네임 옆 표시)
- `app/lib/features/auth/providers/auth_provider.dart` (`AuthUser` 에 discriminator)
- `app/test/...` (위 11.2 의 테스트들)

### Docs (소스-오브-트루스)

- `docs/domain-model.md` — User 표 row 추가
- `docs/api-contract.md` — user 응답 스키마 + 신규 엔드포인트

## 13. Out of Scope

- 닉네임 변경 시 discriminator 재발급 흐름 (변경 엔드포인트 미존재 가정)
- ID 자체 커스터마이징 (사용자가 원하는 숫자 지정)
- 닉네임만으로 검색 (동명이인 리스트 표시) — 결정안에서 명시적으로 제외
- ID QR 코드 / 딥링크 공유 — 후속 작업
- ID 노출 / 비노출 프라이버시 토글 — 후속 작업

## 14. 검증 (verification-before-completion)

본 기능 완료 선언 전에:

1. `docker compose up --build -d backend && curl -fsS http://localhost:8000/health` → 200
2. `pytest server/tests/...` → 11.1 의 모든 테스트 PASS, 출력 발췌 인용
3. iOS simulator clean install → 친구 찾기 화면에서 본인 ID 검색 / 다른 사용자 ID 검색 / 잘못된 ID 검색 / 설정·마이페이지 ID 표시 + 복사 토스트 수동 확인
4. `flutter test` 통과 출력 발췌 인용

## 15. 관련 보고서 (참고)

- (추후 implementation plan 작성 시 `docs/reports/` 에서 friends / users / settings 관련 보고서 grep 후 인용)

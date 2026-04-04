# MVP Slice 01: 달력 루프

> 버전: 0.1
> 최종 수정: 2026-04-04
> 우선순위: P0 첫 번째 수직 슬라이스

---

## 1. 슬라이스 범위

이 슬라이스는 P0 핵심 루프의 중심 경로를 **수직으로 관통**한다: 화면 → API → DB → 테스트.

```
내 페이지        챌린지 공간       인증 제출        날짜별 인증
(챌린지 목록) → (월 달력 조회) → (하루 인증) →  (인증 목록 조회)
```

### 포함

| 단계 | 사용자 플로우 | API | 관련 기능 ID |
|------|-------------|-----|-------------|
| 1 | 내 페이지에서 참여 중 챌린지 목록 확인 | `GET /me/challenges` | F-08 |
| 2 | 챌린지 카드 탭 → 챌린지 공간 진입, 월 달력 조회 | `GET /challenges/{id}/calendar` | F-09, F-10, F-11 |
| 3 | 오늘 날짜에서 [인증하기] → 인증 제출 | `POST /challenges/{id}/verifications` | F-13 |
| 4 | 달력에서 날짜 탭 → 해당 날짜 인증 목록 조회 | `GET /challenges/{id}/verifications/{date}` | F-12 |

### 제외 (이 슬라이스에서)

- 로그인 / 프로필 설정 (별도 슬라이스)
- 챌린지 생성 / 참여 (별도 슬라이스)
- 인증 상세 + 댓글 (Slice 02)
- 챌린지 완료 화면 (Slice 03)
- 이미지 업로드 (이 슬라이스에서는 사진 없이 일기만 제출, 이미지는 Slice 02에서 추가)

### 전제 조건

- DB에 테스트 User, Challenge, ChallengeMember 시드 데이터가 존재한다고 가정
- 인증 토큰은 하드코딩 또는 테스트용 토큰으로 대체 가능

---

## 2. 화면 명세

### 2.1 내 페이지 (챌린지 목록)

```
┌──────────────────────────────┐
│  내 페이지                     │
│                               │
│  ── 참여 중인 챌린지 ──         │
│  ┌──────────────────────┐     │
│  │ 운동 30일              │     │
│  │ 달성률 73.3%           │     │
│  │ 참여자 5명             │     │
│  └──────────────────────┘     │
│  ┌──────────────────────┐     │
│  │ 독서 습관              │     │
│  │ 달성률 40.0%           │     │
│  │ 참여자 3명             │     │
│  └──────────────────────┘     │
└──────────────────────────────┘
```

- 데이터 소스: `GET /me/challenges?status=active`
- 각 카드: title, achievement_rate, member_count 표시
- 카드 탭 → `/challenges/:id` (챌린지 공간)으로 네비게이션

### 2.2 챌린지 공간 (월 달력)

```
┌──────────────────────────────┐
│  ◀ 운동 30일 (참여자 5명)     │
│                               │
│  ◀  2026년 4월  ▶             │
│  일  월  화  수  목  금  토     │
│            1    2    3    4    │
│           🌸   🌸              │
│   5    6    7    8    9  ...   │
│       🌸   😀  😀             │
│            😀                  │
│                               │
│  ── 오늘 (4월 4일) ──          │
│  아직 인증하지 않았어요!         │
│  [인증하기]                     │
└──────────────────────────────┘
```

- 데이터 소스: `GET /challenges/{id}/calendar?year=2026&month=4`
- 날짜 셀 렌더링 규칙:
  - `all_completed == true` → 계절 아이콘 (season_icon_type)
  - `verified_members.length > 0` → 프로필 썸네일 배열
  - `verified_members.length == 0` → 빈 칸
- 오늘 날짜에 [인증하기] 버튼: 현재 유저가 `verified_members`에 없을 때만 표시
- 날짜 탭 → 해당 날짜 인증 목록 (2.4)
- 월 전환: ◀▶ 탭으로 year/month 파라미터 변경

### 2.3 인증 제출

```
┌──────────────────────────────┐
│  인증 작성                     │
│                               │
│  오늘의 일기                   │
│  ┌──────────────────────┐     │
│  │ (텍스트 입력)          │     │
│  └──────────────────────┘     │
│                               │
│  [제출하기]                    │
└──────────────────────────────┘
```

- 이 슬라이스에서는 **일기(텍스트)만** 제출 (사진 업로드는 Slice 02)
- 데이터 전송: `POST /challenges/{id}/verifications` (diary_text only)
- 제출 성공 시:
  - `day_completed == true` → 전원 인증 축하 다이얼로그
  - 챌린지 공간(달력)으로 복귀, 달력 갱신

### 2.4 날짜별 인증 목록

```
┌──────────────────────────────┐
│  4월 2일 인증 현황 (3/5)       │
│                               │
│  ┌────┐ 김철수  ✓              │
│  ┌────┐ 이영희  ✓              │
│  ┌────┐ 박지민  ✓              │
└──────────────────────────────┘
```

- 데이터 소스: `GET /challenges/{id}/verifications/{date}`
- 각 행: 프로필 썸네일 + nickname
- 이 슬라이스에서는 목록만 표시 (인증 상세 탭은 Slice 02)

---

## 3. API 상세

이 슬라이스에서 구현하는 API 4개. 전체 스키마는 `docs/api-contract.md` 참조.

### 3.1 GET `/me/challenges`

```
Query: ?status=active
Response:
{
  "data": {
    "challenges": [
      {
        "id": "uuid",
        "title": "string",
        "category": "string",
        "start_date": "YYYY-MM-DD",
        "end_date": "YYYY-MM-DD",
        "status": "active",
        "member_count": 5,
        "achievement_rate": 73.3,
        "badge": null
      }
    ]
  }
}
```

**서버 로직:**
1. `ChallengeMember WHERE user_id = 현재유저` → challenge_id 리스트
2. `Challenge WHERE id IN (...)`, status 필터 적용
3. 각 챌린지별 달성률 계산: `COUNT(Verification WHERE challenge_id, user_id) / 기대 인증 횟수 × 100`

### 3.2 GET `/challenges/{id}/calendar`

```
Query: ?year=2026&month=4
Response: → api-contract.md §4 참조
```

**서버 로직:**
1. 멤버 확인 (NOT_A_MEMBER 시 403)
2. Verification 조회 (challenge_id + 해당 월 날짜 범위)
3. DayCompletion 조회 (challenge_id + 해당 월 날짜 범위)
4. ChallengeMember + User JOIN → members 리스트
5. 날짜별 집계하여 days[] 구성

### 3.3 POST `/challenges/{id}/verifications`

```
Body (이 슬라이스): multipart/form-data
  - diary_text: string (필수)
  - photo: 생략 (Slice 02에서 추가)

Response (201): → api-contract.md §4 참조
```

**서버 로직:**
1. 사전 검증 5종 (CHALLENGE_NOT_FOUND, NOT_A_MEMBER, CHALLENGE_ENDED, ALREADY_VERIFIED_TODAY, PHOTO_REQUIRED)
   - 이 슬라이스에서는 photo_required=false인 챌린지만 테스트
2. Verification INSERT
3. 전원 인증 판정 → 조건 충족 시 DayCompletion INSERT
4. 응답 반환

### 3.4 GET `/challenges/{id}/verifications/{date}`

```
Path: date = YYYY-MM-DD
Response: → api-contract.md §4 참조
```

**서버 로직:**
1. 멤버 확인
2. Verification WHERE challenge_id, date → JOIN User
3. DayCompletion 조회 → all_completed, season_icon_type
4. 응답 조립

---

## 4. DB 테이블 (이 슬라이스에서 사용)

전체 스키마는 `docs/domain-model.md` 참조. 이 슬라이스에서 필요한 테이블:

| 테이블 | 용도 | 비고 |
|--------|------|------|
| User | 멤버 프로필 표시 | 시드 데이터로 생성 |
| Challenge | 챌린지 정보 | 시드 데이터로 생성 |
| ChallengeMember | 참여 관계, 달성률 | 시드 데이터로 생성 |
| Verification | 인증 레코드 생성/조회 | INSERT + SELECT |
| DayCompletion | 전원 인증 기록 | INSERT (자동) + SELECT |

### 마이그레이션 범위

이 슬라이스에서 위 5개 테이블 + P0 인덱스를 모두 생성한다 (Comment 테이블 포함 — Slice 02에서 사용하지만, 스키마는 한 번에 생성).

```sql
-- 생성 순서 (FK 의존성)
1. users
2. challenges
3. challenge_members  (FK: users, challenges)
4. verifications      (FK: challenges, users)
5. day_completions    (FK: challenges)
6. comments           (FK: verifications, users)
```

---

## 5. 시드 데이터

테스트 및 개발용 시드 데이터:

```
User:
  - user_1: 김철수 (테스트 로그인 사용자)
  - user_2: 이영희
  - user_3: 박지민

Challenge:
  - challenge_1: "운동 30일"
    category: "운동"
    start_date: 2026-03-05
    end_date: 2026-04-03
    verification_frequency: { type: "daily" }
    photo_required: false
    status: active

ChallengeMember:
  - user_1 → challenge_1
  - user_2 → challenge_1
  - user_3 → challenge_1

Verification (과거 데이터):
  - user_1, challenge_1, 2026-03-05 ~ 2026-03-20 (16일치)
  - user_2, challenge_1, 2026-03-05 ~ 2026-03-18 (14일치)
  - user_3, challenge_1, 2026-03-05 ~ 2026-03-20 (16일치)

DayCompletion:
  - challenge_1, 2026-03-05 ~ 2026-03-18 중 3명 모두 인증한 날짜 → spring
```

---

## 6. 테스트 기준

### 6.1 API 통합 테스트

| 테스트 케이스 | API | 검증 사항 |
|-------------|-----|----------|
| 내 챌린지 목록 조회 | GET /me/challenges | 참여 중인 챌린지만 반환, 달성률 정확성 |
| 빈 챌린지 목록 | GET /me/challenges | 참여 챌린지 없는 유저 → 빈 배열 |
| status 필터링 | GET /me/challenges?status=active | active만 반환 |
| 달력 조회 (정상) | GET /challenges/{id}/calendar | days[] 날짜별 verified_members 정확성 |
| 달력 조회 (전원 인증 일) | GET /challenges/{id}/calendar | all_completed=true, season_icon_type 값 확인 |
| 달력 조회 (비멤버) | GET /challenges/{id}/calendar | 403 FORBIDDEN |
| 인증 제출 (정상) | POST /challenges/{id}/verifications | 201, Verification 레코드 생성 확인 |
| 인증 제출 (중복) | POST /challenges/{id}/verifications | 422 ALREADY_VERIFIED_TODAY |
| 인증 제출 → 전원 인증 달성 | POST /challenges/{id}/verifications | day_completed=true, DayCompletion 생성 |
| 인증 제출 (종료된 챌린지) | POST /challenges/{id}/verifications | 422 CHALLENGE_ENDED |
| 날짜별 인증 목록 (정상) | GET /challenges/{id}/verifications/{date} | verifications[] 정확성 |
| 날짜별 인증 목록 (인증 없는 날) | GET /challenges/{id}/verifications/{date} | 빈 verifications[] |

### 6.2 단위 테스트

| 대상 | 검증 사항 |
|------|----------|
| 달성률 계산 (daily) | 인증 횟수 / 총 일수 × 100, 소수점 첫째자리 |
| 달성률 계산 (weekly) | ceil(일수/7) × N 기반 기대 횟수 |
| 계절 판정 (season_icon_type) | 3~5월=spring, 6~8=summer, 9~11=fall, 12~2=winter |
| 전원 인증 판정 | 인증 수 == 멤버 수 → true |

### 6.3 Flutter 위젯 테스트

| 대상 | 검증 사항 |
|------|----------|
| 챌린지 카드 | title, achievement_rate, member_count 표시 |
| 달력 셀 (빈 칸) | verified_members 없을 때 빈 칸 렌더링 |
| 달력 셀 (썸네일) | verified_members 프로필 이미지 표시 |
| 달력 셀 (계절 아이콘) | all_completed=true 시 아이콘 표시 |
| 인증하기 버튼 | 미인증 상태에서만 표시, 인증 완료 시 숨김 |

---

## 7. 완료 조건 (Definition of Done)

- [ ] 4개 API 엔드포인트 구현 및 api-contract.md 응답 형식 일치
- [ ] 5개 DB 테이블 + 인덱스 마이그레이션 완료
- [ ] 내 페이지 → 챌린지 공간 → 인증 제출 → 날짜별 목록 흐름이 E2E로 동작
- [ ] 전원 인증 판정 시 DayCompletion 자동 생성 확인
- [ ] 달력에서 계절 아이콘 / 썸네일 / 빈 칸 정확히 렌더링
- [ ] API 통합 테스트 12개 + 단위 테스트 4개 통과
- [ ] 시드 데이터로 데모 가능 상태

---

## Open Questions

| # | 항목 | 영향 |
|---|------|------|
| 1 | 달력 API 응답에서 챌린지 기간 밖 날짜를 어떻게 처리할지 (비활성 표시 vs 미반환) | 달력 셀 렌더링 로직 |
| 2 | 달성률 계산 시 챌린지 시작 전/진행 중일 때 기대 인증 횟수를 전체 기간 기준으로 할지, 오늘까지 경과일 기준으로 할지 | achievement_rate 값 |
| 3 | 인증 제출 가능 시간 범위 (자정 기준? 사용자 시간대?) | Verification.date 판정 |

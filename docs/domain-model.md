# 해다 (Haeda) — 도메인 모델

> 버전: 0.2 (MVP)
> 최종 수정: 2026-04-04

---

## 핵심 객체 정의

앱의 중심 단위는 **Challenge(챌린지)**이다.
- 모든 활동(인증, 댓글, 달력, 완료)은 챌린지 안에서 이루어진다.
- **category**는 Challenge의 자유 입력 속성(VARCHAR)이며, 독립 엔터티가 아니다.
- 라우팅과 API 경로 모두 `/challenges/{id}` 를 최상위 그룹으로 사용한다.

---

## 1. ER 다이어그램 (텍스트)

### P0 엔터티

```
User 1──N ChallengeMember N──1 Challenge
  │                                  │
  │ 1──N Verification N──1 ──────────┘
  │           │
  │           │ 1──N Comment
  │                    │
  └────────────────────┘ (author)

Challenge 1──N DayCompletion
```

### P1 엔터티 (알림 기능 추가 시)

```
User 1──N DeviceToken
```

---

## 2. 엔터티 상세

### 2.1 User — P0

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 사용자 고유 ID |
| kakao_id | BIGINT | UNIQUE, NOT NULL | 카카오 OAuth 고유 ID |
| nickname | VARCHAR(30) | NOT NULL | 닉네임 |
| profile_image_url | TEXT | NULLABLE | 프로필 사진 URL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 가입일시 |

### 2.2 Challenge — P0 (핵심 객체)

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 챌린지 고유 ID |
| creator_id | UUID | FK → User, NOT NULL | 생성자 |
| title | VARCHAR(100) | NOT NULL | 제목 |
| description | TEXT | NULLABLE | 설명 |
| category | VARCHAR(50) | NOT NULL | 카테고리 (자유 입력, 독립 엔터티 아님) |
| start_date | DATE | NOT NULL | 시작일 |
| end_date | DATE | NOT NULL | 종료일 |
| verification_frequency | JSONB | NOT NULL | 인증 빈도 설정 (아래 참조) |
| photo_required | BOOLEAN | NOT NULL, DEFAULT FALSE | 사진 필수 여부 |
| invite_code | VARCHAR(8) | UNIQUE, NOT NULL | 초대 코드 (자동 생성) |
| is_public | BOOLEAN | NOT NULL, DEFAULT FALSE | 공개 여부 (P0에서는 항상 false) |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'active' | 상태 (active / completed) |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 생성일시 |

**verification_frequency JSONB 구조:**
```json
// 매일
{ "type": "daily" }

// 주 N회
{ "type": "weekly", "times_per_week": 3 }
```

**제약 조건:**
- `end_date > start_date`
- `status IN ('active', 'completed')`

### 2.3 ChallengeMember — P0

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 멤버십 고유 ID |
| challenge_id | UUID | FK → Challenge, NOT NULL | 챌린지 |
| user_id | UUID | FK → User, NOT NULL | 참여자 |
| joined_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 참여일시 |
| badge | VARCHAR(20) | NULLABLE | 완료 배지 (챌린지 종료 시 부여) |

**제약 조건:**
- UNIQUE(challenge_id, user_id) — 동일 챌린지에 중복 참여 불가

### 2.4 Verification — P0

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 인증 고유 ID |
| challenge_id | UUID | FK → Challenge, NOT NULL | 대상 챌린지 |
| user_id | UUID | FK → User, NOT NULL | 인증자 |
| date | DATE | NOT NULL | 인증 대상 날짜 |
| photo_url | TEXT | NULLABLE | 인증 사진 URL |
| diary_text | TEXT | NOT NULL | 일기 텍스트 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 제출일시 |

**제약 조건:**
- UNIQUE(challenge_id, user_id, date) — 같은 챌린지에서 같은 날 중복 인증 불가
- `date BETWEEN challenge.start_date AND challenge.end_date`
- `photo_required = TRUE`인 챌린지는 `photo_url NOT NULL` (애플리케이션 레벨 검증)

### 2.5 DayCompletion — P0

전원 인증 달성 기록. Verification이 생성될 때 해당 날짜의 전원 인증 여부를 확인하고, 전원 완료 시 자동 생성.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| challenge_id | UUID | FK → Challenge, NOT NULL | 대상 챌린지 |
| date | DATE | NOT NULL | 전원 인증 완료 날짜 |
| season_icon_type | VARCHAR(10) | NOT NULL | spring / summer / fall / winter |
| completed_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 전원 인증 완료 시각 |

**제약 조건:**
- UNIQUE(challenge_id, date) — 같은 챌린지에서 같은 날 중복 레코드 불가
- `season_icon_type IN ('spring', 'summer', 'fall', 'winter')`

**season_icon_type 판정 로직:**
```
3월~5월  → spring
6월~8월  → summer
9월~11월 → fall
12월~2월 → winter
```

### 2.6 Comment — P0

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| verification_id | UUID | FK → Verification, NOT NULL | 대상 인증 |
| author_id | UUID | FK → User, NOT NULL | 작성자 |
| content | VARCHAR(500) | NOT NULL | 댓글 내용 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 작성일시 |

### 2.7 DeviceToken — P1

> P1: 푸시 알림(F-15, F-16) 구현 시 추가.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| user_id | UUID | FK → User, NOT NULL | 소유자 |
| token | TEXT | NOT NULL | FCM 디바이스 토큰 |
| platform | VARCHAR(10) | NOT NULL | ios / android |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 등록일시 |

**제약 조건:**
- UNIQUE(user_id, token)
- `platform IN ('ios', 'android')`

### 2.8 Notification — P1

> P1: 인앱 알림 히스토리(F-19) 구현 시 추가.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| user_id | UUID | FK → User, NOT NULL | 수신자 |
| type | VARCHAR(30) | NOT NULL | 알림 타입 (verification_reminder, member_verified, day_completed, challenge_completed) |
| title | VARCHAR(200) | NOT NULL | 알림 제목 |
| body | VARCHAR(500) | NOT NULL | 알림 본문 |
| data_json | JSONB | | 추가 데이터 (challenge_id 등) |
| is_read | BOOLEAN | NOT NULL, DEFAULT FALSE | 읽음 여부 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 생성일시 |

**제약 조건:**
- `type IN ('verification_reminder', 'member_verified', 'day_completed', 'challenge_completed')`

---

## 3. 인덱스 설계

### P0 인덱스

| 테이블 | 인덱스 | 용도 |
|--------|--------|------|
| Challenge | idx_challenge_status | 활성 챌린지 조회 |
| Challenge | idx_challenge_invite_code | 초대 코드 검색 |
| ChallengeMember | idx_member_user_id | 내 챌린지 목록 |
| ChallengeMember | idx_member_challenge_id | 챌린지 참여자 목록 |
| Verification | idx_verification_challenge_date | 달력 뷰 (챌린지+날짜별 조회) |
| Verification | idx_verification_user_challenge | 사람별 인증 내역 |
| DayCompletion | idx_day_completion_challenge | 챌린지의 전원 인증 날짜 목록 |
| Comment | idx_comment_verification | 인증별 댓글 목록 |

### P1 인덱스

| 테이블 | 인덱스 | 용도 |
|--------|--------|------|
| Challenge | idx_challenge_is_public | 공개 챌린지 탐색 |
| DeviceToken | idx_device_user | 사용자별 디바이스 조회 |
| Notification | idx_notification_user_created | 사용자별 알림 목록 (최신순) |

---

## 4. 핵심 비즈니스 규칙

### 달성률 계산
```
개인 달성률 = (실제 인증 횟수 / 기대 인증 횟수) × 100

기대 인증 횟수:
  - daily: end_date - start_date + 1 (일수)
  - weekly(N): ceil(일수 / 7) × N
```

### 전원 인증 판정
```
인증 제출 시:
  1. 해당 날짜의 인증 수 카운트
  2. 챌린지 현재 참여 멤버 수와 비교
  3. 인증 수 == 멤버 수 → DayCompletion 레코드 생성
  4. (P1) 전원에게 푸시 알림 발송
```

### 챌린지 종료
```
스케줄러 (매일 자정):
  1. end_date < today && status == 'active' 인 챌린지 조회
  2. status → 'completed' 변경
  3. 각 멤버별 달성률 계산 → badge 부여
  4. (P1) 참여자에게 완료 푸시 알림 발송
```

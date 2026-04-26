# 해다 (Haeda) — 도메인 모델

> 버전: 0.2 (MVP)
> 최종 수정: 2026-04-04

---

## 핵심 객체 정의

앱의 중심 단위는 **Challenge(챌린지)**이다.
- 모든 활동(인증, 달력, 완료)은 챌린지 안에서 이루어진다.
- **category**는 Challenge의 자유 입력 속성(VARCHAR)이며, 독립 엔터티가 아니다.
- 라우팅과 API 경로 모두 `/challenges/{id}` 를 최상위 그룹으로 사용한다.

---

## 1. ER 다이어그램 (텍스트)

### P0 엔터티

```
User 1──N ChallengeMember N──1 Challenge
  │                                  │
  │ 1──N Verification N──1 ──────────┘

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
| discriminator | VARCHAR(5) | NOT NULL | 5자리 숫자 (`'10000'`–`'99999'`). `(nickname, discriminator)` UNIQUE, CHECK `~ '^[0-9]{5}$'` |
| profile_image_url | TEXT | NULLABLE | 프로필 사진 URL |
| background_color | VARCHAR(9) | NULLABLE | 캐릭터 배경 원형 색상 (고정 팔레트 내 hex, 예 `#FFCDD2`) |
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
| day_cutoff_hour | SMALLINT | NOT NULL, DEFAULT 0, CHECK 0~2 | 하루 경계 시각. 0=자정, 1=01시, 2=02시. 해당 시각 이전의 인증은 전날 미션으로 인정. 챌린지 생성자만 설정/변경 가능 |
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
| notify_streak | BOOLEAN | NOT NULL, DEFAULT TRUE | 연속 인증 알림 수신 여부 (챌린지별 토글) |

**제약 조건:**
- UNIQUE(challenge_id, user_id) — 동일 챌린지에 중복 참여 불가

### 2.4 Verification — P0

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 인증 고유 ID |
| challenge_id | UUID | FK → Challenge, NOT NULL | 대상 챌린지 |
| user_id | UUID | FK → User, NOT NULL | 인증자 |
| date | DATE | NOT NULL | 인증 대상 날짜 |
| photo_urls | JSONB | NULLABLE | 인증 사진 URL 목록 (최대 3장) |
| diary_text | TEXT | NOT NULL | 일기 텍스트 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 제출일시 |

**제약 조건:**
- UNIQUE(challenge_id, user_id, date) — 같은 챌린지에서 같은 날 중복 인증 불가
- `date BETWEEN challenge.start_date AND challenge.end_date`
- `photo_required = TRUE`인 챌린지는 `photo_urls`에 최소 1장 필수 (애플리케이션 레벨 검증)
- `photo_urls` 최대 3장 제한 (애플리케이션 레벨 검증)

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

### 2.6 DeviceToken — P1

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

### 2.7 Notification — P1

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
- `type IN ('verification_reminder', 'member_verified', 'day_completed', 'challenge_completed', 'streak_milestone')`

### 2.8 GemTransaction (코인 거래) — P0

재화(코인) 획득/소비 내역. 인증, 스트릭, 전원 달성, 챌린지 완주, 출석, 아이템 구매 시 자동 생성.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| user_id | UUID | FK → User, NOT NULL | 사용자 |
| amount | INTEGER | NOT NULL | 양수=획득, 음수=소비 |
| reason | VARCHAR(50) | NOT NULL | VERIFICATION, ALL_COMPLETED, CHALLENGE_DONE, STREAK_3, STREAK_7, DAILY_LOGIN, PURCHASE |
| reference_id | UUID | NULLABLE | 관련 챌린지ID 또는 아이템ID |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 거래 시각 |

**코인 잔액**: `SELECT COALESCE(SUM(amount), 0) FROM gem_transactions WHERE user_id = ?`

**코인 획득 이벤트:**

| 이벤트 | 코인 | 조건 |
|--------|------|------|
| 일일 인증 완료 | +10 | 챌린지당 1일 1회 |
| 전원 인증 달성 | +20 | DayCompletion 생성 시, 참여자 전원 |
| 챌린지 완주 | +100 | 챌린지 종료 + 참여 완료 |
| 3일 연속 인증 | +15 | 같은 챌린지 내 연속 3일 |
| 7일 연속 인증 | +50 | 같은 챌린지 내 연속 7일 |
| 일일 출석 | +5 | 앱 접속 시 1일 1회 |

### 2.9 Item (아이템 카탈로그) — P0 / P2 확장

상점에서 판매하는 캐릭터 착용 아이템 + 미니룸/챌린지 방 꾸미기 아이템 (P2: F-31).

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| name | VARCHAR(50) | NOT NULL | 아이템 이름 |
| category | VARCHAR(20) | NOT NULL | 카테고리 (아래 참조) |
| price | INTEGER | NOT NULL | 코인 가격 |
| rarity | VARCHAR(10) | NOT NULL | COMMON, RARE, EPIC |
| asset_key | VARCHAR(100) | NOT NULL | 에셋 파일 경로 키 |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE | 상점 진열 여부 |
| is_limited | BOOLEAN | NOT NULL, DEFAULT FALSE | 한정판 여부 (보상 전용) — P2 |
| reward_trigger | VARCHAR(64) | NULLABLE | 획득 경로. SHOP=상점 전용, NULL=상점+보상 병행, FIRST_VERIFICATION/STREAK_7/COMPLETE_30/ALL_VERIFIED_DAY=보상 전용 — P2 |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | 정렬 순서 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | |

**제약 조건:**
- `category IN ('HAT', 'TOP', 'BOTTOM', 'SHOES', 'ACCESSORY', 'MR_WALL', 'MR_CEILING', 'MR_WINDOW', 'MR_SHELF', 'MR_PLANT', 'MR_DESK', 'MR_RUG', 'MR_FLOOR', 'CR_WALL', 'CR_WINDOW', 'CR_CALENDAR', 'CR_BOARD', 'CR_SOFA', 'CR_FLOOR', 'SIGNATURE')`
- `rarity IN ('COMMON', 'RARE', 'EPIC')`
- `MR_*` = 미니룸 슬롯, `CR_*` = 챌린지 방 공용 슬롯, `SIGNATURE` = 챌린지 방 멤버 개인 슬롯 (크로스 룸).

### 2.10 UserItem (인벤토리) — P0

사용자가 구매한 아이템 목록.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| user_id | UUID | FK → User, NOT NULL | 소유자 |
| item_id | UUID | FK → Item, NOT NULL | 아이템 |
| purchased_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 구매 시각 |

**제약 조건:**
- UNIQUE(user_id, item_id) — 동일 아이템 중복 구매 불가

### 2.11 CharacterEquip (캐릭터 착용 상태) — P0

사용자의 현재 캐릭터 착용 상태. 유저당 1행.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| user_id | UUID | PK, FK → User | 사용자 |
| hat_item_id | UUID | FK → Item, NULLABLE | 착용 모자 |
| top_item_id | UUID | FK → Item, NULLABLE | 착용 상의 |
| bottom_item_id | UUID | FK → Item, NULLABLE | 착용 하의 |
| shoes_item_id | UUID | FK → Item, NULLABLE | 착용 신발 |
| accessory_item_id | UUID | FK → Item, NULLABLE | 착용 액세서리 |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 마지막 변경 |

**비즈니스 룰:**
- 각 슬롯에는 해당 카테고리 아이템만 착용 가능
- 보유(UserItem)하지 않은 아이템은 착용 불가
- 코인 잔액 부족 시 구매 불가

### 2.12 RoomEquipMr (미니룸 장착 상태) — P2

사용자의 미니룸 8개 슬롯 현재 장착 상태. 유저당 1행. 슬롯 NULL = 디자인 기본값 렌더.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| user_id | UUID | PK, FK → User | 사용자 |
| wall_item_id | UUID | FK → Item, NULLABLE | 벽지 (category=MR_WALL) |
| ceiling_item_id | UUID | FK → Item, NULLABLE | 천장 (category=MR_CEILING) |
| window_item_id | UUID | FK → Item, NULLABLE | 창 (category=MR_WINDOW) |
| shelf_item_id | UUID | FK → Item, NULLABLE | 선반 (category=MR_SHELF) |
| plant_item_id | UUID | FK → Item, NULLABLE | 화분 (category=MR_PLANT) |
| desk_item_id | UUID | FK → Item, NULLABLE | 책상 (category=MR_DESK) |
| rug_item_id | UUID | FK → Item, NULLABLE | 러그 (category=MR_RUG) |
| floor_item_id | UUID | FK → Item, NULLABLE | 바닥 (category=MR_FLOOR) |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 마지막 변경 |

**비즈니스 룰:**
- 각 슬롯은 해당 카테고리 아이템만 허용 (불일치 = `ITEM_CATEGORY_MISMATCH` 422).
- 보유(UserItem)하지 않은 아이템 장착 시 `NOT_OWNED` 403.
- 슬롯 NULL → 디자인 기본값 렌더.
- Item.is_active=false 로 변경 시 자동 NULL fallback (silent).

### 2.13 RoomEquipCr (챌린지 방 공용 장착) — P2

챌린지 방의 공용 6개 슬롯 장착 상태. 챌린지당 1행. 방장만 편집 가능.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| challenge_id | UUID | PK, FK → Challenge | 챌린지 |
| wall_item_id | UUID | FK → Item, NULLABLE | 벽지 (category=CR_WALL) |
| window_item_id | UUID | FK → Item, NULLABLE | 창 (category=CR_WINDOW) |
| calendar_item_id | UUID | FK → Item, NULLABLE | 미니 달력 (category=CR_CALENDAR) |
| board_item_id | UUID | FK → Item, NULLABLE | 게시판 (category=CR_BOARD) |
| sofa_item_id | UUID | FK → Item, NULLABLE | 중앙 소파 (category=CR_SOFA) |
| floor_item_id | UUID | FK → Item, NULLABLE | 바닥 (category=CR_FLOOR) |
| updated_by_user_id | UUID | FK → User, NULLABLE | 마지막 변경 사용자 (감사용) |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 마지막 변경 |

**비즈니스 룰:**
- 방장(`Challenge.creator_id`) 만 편집 가능. 비방장 = `CR_NOT_CREATOR` 403.
- 카테고리 불일치 = `ITEM_CATEGORY_MISMATCH` 422.
- 방장이 챌린지를 떠나면 row 유지하되 기본값 렌더 (P3에서 승계 정책).
- 챌린지 삭제 시 cascade delete.

### 2.14 RoomEquipCrSignature (챌린지 방 멤버 signature) — P2

챌린지 방에서 각 멤버가 자기 캐릭터 옆에 표시할 개인 signature 아이템. 챌린지당 멤버당 최대 1행.

| 필드 | 타입 | 제약 | 설명 |
|------|------|------|------|
| id | UUID | PK | 고유 ID |
| challenge_id | UUID | FK → Challenge, NOT NULL | 챌린지 |
| user_id | UUID | FK → User, NOT NULL | 멤버 |
| signature_item_id | UUID | FK → Item, NOT NULL | signature 아이템 (category=SIGNATURE) |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 마지막 변경 |

**제약 조건:**
- UNIQUE(challenge_id, user_id) — 챌린지당 멤버별 1건. 재지정은 upsert.
- INDEX(challenge_id), INDEX(user_id).

**비즈니스 룰:**
- ChallengeMember 가 아니면 `CR_NOT_MEMBER` 403.
- `signature_item_id` 의 Item.category != 'SIGNATURE' = `ITEM_CATEGORY_MISMATCH` 422.
- 보유(UserItem)하지 않은 signature 지정 시 `NOT_OWNED` 403.
- 멤버 탈퇴 시 row 삭제. 챌린지 삭제 시 cascade delete.

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
| RoomEquipCrSignature | idx_cr_sig_challenge | 챌린지별 signature 목록 (P2) |
| RoomEquipCrSignature | idx_cr_sig_user | 사용자별 signature 조회 (P2) |

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

### 인증 대상 날짜 (effective date)
```
인증 제출 시, 대상 날짜(date)는 해당 챌린지의 day_cutoff_hour 를 반영한 "현재 유효 날짜"를 기본값으로 한다.

effective_today(now_kst, cutoff_hour) = (now_kst - cutoff_hour hours).date()

예) cutoff_hour = 2
  - 2026-03-09 01:59 KST → 2026-03-08
  - 2026-03-09 02:00 KST → 2026-03-09
cutoff_hour = 0 (기본) 이면 기존 동작과 동일 (자정 기준).
```

### 전원 인증 판정
```
인증 제출 시:
  1. 해당 날짜(effective date)의 인증 수 카운트
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

# 해다 (Haeda) — API 계약서

> 버전: 0.2 (MVP)
> 최종 수정: 2026-04-04
> Base URL: `/api/v1`

---

## P0 / P1 범위 안내

- **P0**: Auth, Challenges (생성·상세·초대코드조회·참여·완료), My Page, Verifications, Coins (재화), Shop (상점/아이템), Character (캐릭터 커스터마이징)
- **P1**: 공개 챌린지 목록 (`GET /challenges`), Notifications (디바이스 토큰, 푸시 알림)

---

## 공통 사항

### 인증
모든 API (로그인 제외)는 `Authorization: Bearer <access_token>` 헤더 필요.

### 응답 형식
```json
// 성공
{
  "data": { ... }
}

// 에러
{
  "error": {
    "code": "CHALLENGE_NOT_FOUND",
    "message": "챌린지를 찾을 수 없습니다."
  }
}
```

### 공통 에러 코드
| HTTP | code | 설명 |
|------|------|------|
| 401 | UNAUTHORIZED | 인증 토큰 없음 또는 만료 |
| 403 | FORBIDDEN | 권한 없음 |
| 404 | NOT_FOUND | 리소스 없음 |
| 422 | VALIDATION_ERROR | 요청 데이터 검증 실패 |

---

## 1. Auth — P0

### POST `/auth/kakao` — 카카오 로그인

카카오 OAuth 인가 코드로 로그인/회원가입 처리 후 앱 토큰 발급.

**Request:**
```json
{
  "kakao_access_token": "string"
}
```

**Response (200):**
```json
{
  "data": {
    "access_token": "string",
    "refresh_token": "string",
    "user": {
      "id": "uuid",
      "nickname": "string | null",
      "profile_image_url": "string | null",
      "background_color": "string | null",
      "is_new": true
    }
  }
}
```

`is_new: true`이면 클라이언트에서 프로필 설정 화면으로 이동.

---

### PUT `/auth/profile` — 프로필 설정

**Request (multipart/form-data):**
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| nickname | string | Y | 닉네임 (2~30자) |
| profile_image | file | N | 프로필 사진 |
| background_color | string | N | 캐릭터 배경 원형 색상 (고정 팔레트 내 hex, 예 `#FFCDD2`) |

**Response (200):**
```json
{
  "data": {
    "id": "uuid",
    "nickname": "string",
    "profile_image_url": "string | null",
    "background_color": "string | null",
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| NICKNAME_TOO_SHORT | 닉네임 2자 미만 |
| NICKNAME_TOO_LONG | 닉네임 30자 초과 |
| INVALID_BACKGROUND_COLOR | 팔레트 외 색상 값 |

---

## 2. Challenges — P0

### POST `/challenges` — 챌린지 생성

**Request:**
```json
{
  "title": "운동 30일",
  "description": "매일 30분 이상 운동하기",
  "category": "운동",
  "start_date": "2026-04-05",
  "end_date": "2026-05-04",
  "verification_frequency": {
    "type": "daily"
  },
    "photo_required": true,
  "day_cutoff_hour": 0
}
```

> P0에서 `is_public`은 서버가 기본 `false`로 설정. 클라이언트는 전송하지 않는다.

**Response (201):**
```json
{
  "data": {
    "id": "uuid",
    "title": "운동 30일",
    "description": "매일 30분 이상 운동하기",
    "category": "운동",
    "start_date": "2026-04-05",
    "end_date": "2026-05-04",
    "verification_frequency": { "type": "daily" },
    "photo_required": true,
    "day_cutoff_hour": 0,
    "is_public": false,
    "invite_code": "ABCD1234",
    "status": "active",
    "creator": {
      "id": "uuid",
      "nickname": "string",
      "profile_image_url": "string"
    },
    "member_count": 1,
    "created_at": "2026-04-04T12:00:00Z"
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| INVALID_DATE_RANGE | end_date <= start_date |
| INVALID_FREQUENCY | verification_frequency 형식 오류 |
| INVALID_DAY_CUTOFF_HOUR | day_cutoff_hour 가 0, 1, 2 범위 밖 |

---

---

### PATCH `/challenges/{id}/settings` — 챌린지 설정 변경 (생성자 전용)

챌린지 생성자(creator)만 호출 가능. 생성자가 아닌 경우 403.

**Request:**
```json
{
  "day_cutoff_hour": 2
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| day_cutoff_hour | int | N | 하루 경계 시각. 허용값 0, 1, 2. 미입력 시 기존 값 유지 |

**Response (200):**
```json
{
  "data": {
    "day_cutoff_hour": 2
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| CHALLENGE_NOT_FOUND | 존재하지 않는 챌린지 |
| NOT_CHALLENGE_CREATOR | 챌린지 생성자가 아님 |
| INVALID_DAY_CUTOFF_HOUR | day_cutoff_hour 가 0, 1, 2 범위 밖 |

### GET `/challenges` — 공개 챌린지 목록 — P1

> P1: 공개 탐색 기능(F-05) 구현 시 활성화.

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| cursor | string | N | 페이지네이션 커서 |
| limit | int | N | 페이지 크기 (기본 20, 최대 50) |
| category | string | N | 카테고리 필터 |

**Response (200):**
```json
{
  "data": {
    "challenges": [
      {
        "id": "uuid",
        "title": "string",
        "category": "string",
        "start_date": "2026-04-05",
        "end_date": "2026-05-04",
        "member_count": 5,
        "photo_required": true,
        "creator": {
          "id": "uuid",
          "nickname": "string",
          "profile_image_url": "string"
        }
      }
    ],
    "next_cursor": "string | null"
  }
}
```

---

### GET `/challenges/{id}` — 챌린지 상세

**Response (200):**
```json
{
  "data": {
    "id": "uuid",
    "title": "string",
    "description": "string",
    "category": "string",
    "start_date": "2026-04-05",
    "end_date": "2026-05-04",
    "verification_frequency": { "type": "daily" },
    "photo_required": true,
    "day_cutoff_hour": 0,
    "is_public": false,
    "invite_code": "ABCD1234",
    "status": "active",
    "creator": {
      "id": "uuid",
      "nickname": "string",
      "profile_image_url": "string"
    },
    "member_count": 5,
    "is_member": true,
    "created_at": "2026-04-04T12:00:00Z"
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| CHALLENGE_NOT_FOUND | 존재하지 않는 챌린지 |

---

### GET `/challenges/invite/{code}` — 초대 코드로 챌린지 조회

**Response (200):** 챌린지 상세와 동일 형식.

**에러:**
| code | 조건 |
|------|------|
| INVALID_INVITE_CODE | 존재하지 않는 초대 코드 |

---

### POST `/challenges/{id}/join` — 챌린지 참여

**Request:** 없음 (인증 헤더만 필요)

**Response (200):**
```json
{
  "data": {
    "challenge_id": "uuid",
    "joined_at": "2026-04-04T12:00:00Z"
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| CHALLENGE_NOT_FOUND | 존재하지 않는 챌린지 |
| ALREADY_JOINED | 이미 참여 중 |
| CHALLENGE_ENDED | 이미 종료된 챌린지 |


---

### PATCH `/challenges/{id}/members/me/settings` — 멤버 알림 설정

챌린지별 알림 설정을 변경한다. 현재는 연속 인증 알림 토글만 지원.

**Request:**
```json
{
  "notify_streak": false
}
```

**Response (200):**
```json
{
  "data": {
    "notify_streak": false
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| CHALLENGE_NOT_FOUND | 존재하지 않는 챌린지 |
| NOT_A_MEMBER | 챌린지 참여자가 아님 |
---

### GET `/challenges/{id}/completion` — 챌린지 완료 결과 (Flow 8)

챌린지 종료 후 완료 화면에 필요한 데이터를 반환한다. `status == 'completed'`인 챌린지에만 유효.

**Response (200):**
```json
{
  "data": {
    "challenge_id": "uuid",
    "title": "운동 30일",
    "category": "운동",
    "start_date": "2026-03-05",
    "end_date": "2026-04-03",
    "total_days": 30,
    "my_result": {
      "user_id": "uuid",
      "achievement_rate": 86.7,
      "verified_days": 26,
      "expected_days": 30,
      "badge": "completed"
    },
    "members": [
      {
        "user_id": "uuid",
        "nickname": "김철수",
        "profile_image_url": "string",
        "achievement_rate": 90.0,
        "verified_days": 27,
        "badge": "completed"
      },
      {
        "user_id": "uuid",
        "nickname": "이영희",
        "profile_image_url": "string",
        "achievement_rate": 86.7,
        "verified_days": 26,
        "badge": "completed"
      }
    ],
    "day_completions": 12,
    "calendar_summary": {
      "total_days": 30,
      "all_completed_days": 12,
      "season_icon_types": ["spring"]
    }
  }
}
```

| 필드 | 설명 |
|------|------|
| `my_result` | 요청한 사용자 본인의 달성 결과 |
| `members` | 전체 참여자 달성 결과 (달성률 내림차순) |
| `day_completions` | 전원 인증 달성 일수 |
| `calendar_summary` | 달력 보존 표시에 필요한 요약 정보 |

**에러:**
| code | 조건 |
|------|------|
| CHALLENGE_NOT_FOUND | 존재하지 않는 챌린지 |
| NOT_A_MEMBER | 챌린지 참여자가 아님 |
| CHALLENGE_NOT_COMPLETED | 아직 종료되지 않은 챌린지 |

> 완료 화면의 달력 상세 데이터는 기존 `GET /challenges/{id}/calendar` API를 재활용한다.

---

## 3. My Page — P0

### GET `/me/challenges` — 내 챌린지 목록

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| status | string | N | active / completed (기본: 전체) |

**Response (200):**
```json
{
  "data": {
    "challenges": [
      {
        "id": "uuid",
        "title": "string",
        "category": "string",
        "start_date": "2026-04-05",
        "end_date": "2026-05-04",
        "status": "active",
        "member_count": 5,
        "achievement_rate": 73.3,
        "badge": null,
        "today_verified": false
      }
    ]
  }
}
```

`achievement_rate`: 소수점 첫째자리까지 (0.0 ~ 100.0)
`today_verified`: 오늘 날짜에 사용자의 인증이 존재하면 `true`

---

## 4. Verifications — P0

### POST `/challenges/{id}/verifications` — 인증 제출

**Request (multipart/form-data):**
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| photos | file[] | 조건부 | 인증 사진 최대 3장 (photo_required 시 최소 1장 필수) |
| diary_text | string | Y | 일기 텍스트 |
| date | string (YYYY-MM-DD) | N | 인증 대상 날짜. 미입력 시 서버가 챌린지의 `day_cutoff_hour` 를 반영한 effective today 로 계산. 챌린지 기간 내 & effective today 이전 날짜만 허용 |

**Response (201):**
```json
{
  "data": {
    "id": "uuid",
    "date": "2026-04-04",
    "photo_urls": ["string"] | null,
    "diary_text": "string",
    "created_at": "2026-04-04T12:00:00Z",
    "day_completed": true,
    "season_icon_type": "spring"
  }
}
```

`day_completed: true` — 이 인증으로 전원 인증이 달성된 경우.

**에러:**
| code | 조건 |
|------|------|
| CHALLENGE_NOT_FOUND | 존재하지 않는 챌린지 |
| NOT_A_MEMBER | 챌린지 참여자가 아님 |
| ALREADY_VERIFIED | 해당 날짜에 이미 인증함 |
| PHOTO_REQUIRED | 사진 필수인데 미첨부 |
| CHALLENGE_ENDED | 이미 종료된 챌린지 |
| INVALID_DATE | 인증 불가능한 날짜 (챌린지 기간 외 또는 미래 날짜) |

---

### GET `/challenges/{id}/calendar` — 달력 뷰 데이터

월 단위로 달력 뷰에 필요한 데이터를 반환.

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| year | int | Y | 연도 |
| month | int | Y | 월 (1~12) |

**Response (200):**
```json
{
  "data": {
    "challenge_id": "uuid",
    "year": 2026,
    "month": 4,
    "members": [
      {
        "id": "uuid",
        "nickname": "김철수",
        "profile_image_url": "string"
      }
    ],
    "days": [
      {
        "date": "2026-04-01",
        "verified_members": ["uuid-1", "uuid-2", "uuid-3"],
        "all_completed": true,
        "season_icon_type": "spring"
      },
      {
        "date": "2026-04-02",
        "verified_members": ["uuid-1"],
        "all_completed": false,
        "season_icon_type": null
      }
    ]
  }
}
```

---

### GET `/challenges/{id}/verifications/{date}` — 특정 날짜 인증 목록

**Path Parameters:** date 형식 `YYYY-MM-DD`

**Response (200):**
```json
{
  "data": {
    "date": "2026-04-01",
    "all_completed": true,
    "season_icon_type": "spring",
    "verifications": [
      {
        "id": "uuid",
        "user": {
          "id": "uuid",
          "nickname": "김철수",
          "profile_image_url": "string",
          "character": {
            "hat": { "asset_key": "hat/pink_beanie.png", "rarity": "COMMON" } | null,
            "top": null,
            "bottom": null,
            "shoes": null,
            "accessory": null
          } | null
        },
        "photo_urls": ["string"] | null,
        "diary_text": "오늘은 5km 달렸다!",
        "created_at": "2026-04-01T08:30:00Z"
      }
    ]
  }
}
```

---

### GET `/verifications/{id}` — 인증 상세

**Response (200):**
```json
{
  "data": {
    "id": "uuid",
    "challenge_id": "uuid",
    "user": {
      "id": "uuid",
      "nickname": "김철수",
      "profile_image_url": "string",
      "character": {
        "hat": { "asset_key": "hat/pink_beanie.png", "rarity": "COMMON" } | null,
        "top": null,
        "bottom": null,
        "shoes": null,
        "accessory": null
      } | null
    },
    "date": "2026-04-01",
    "photo_urls": ["string"] | null,
    "diary_text": "오늘은 5km 달렸다! 날씨가 좋아서 기분이 좋았다.",
    "created_at": "2026-04-01T08:30:00Z"
  }
}
```

---

## 5. Coins (재화) — P0

### GET `/me/coins` — 내 코인 잔액

**Response (200):**
```json
{
  "data": {
    "balance": 1250
  }
}
```

---

### GET `/me/coins/transactions` — 코인 거래 내역

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| cursor | string | N | 페이지네이션 커서 (마지막 transaction id) |
| limit | int | N | 페이지 크기 (기본 20, 최대 50) |

**Response (200):**
```json
{
  "data": {
    "items": [
      {
        "id": "uuid",
        "amount": 10,
        "type": "VERIFICATION",
        "reference_id": "uuid | null",
        "created_at": "2026-04-10T09:00:00Z"
      }
    ],
    "next_cursor": "string | null"
  }
}
```

---

## 6. Shop (상점) — P0

### GET `/shop/items` — 상점 아이템 목록

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| category | string | N | HAT, TOP, BOTTOM, SHOES, ACCESSORY, MR_WALL, MR_CEILING, MR_WINDOW, MR_SHELF, MR_PLANT, MR_DESK, MR_RUG, MR_FLOOR, CR_WALL, CR_WINDOW, CR_CALENDAR, CR_BOARD, CR_SOFA, CR_FLOOR, SIGNATURE |
| is_limited | boolean | N | true → 한정판만, false → 일반만, 미지정 → 전체 (P2) |

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "신사모자",
      "category": "HAT",
      "price": 50,
      "rarity": "COMMON",
      "asset_key": "hat/hat_gentleman.png",
      "is_owned": false,
      "is_limited": false
    }
  ]
}
```

`is_limited=true` 인 아이템은 상점 진열 시 잠금(획득 경로 안내) 표시. 보상 전용(reward_trigger 가 SHOP 이 아닌 값) 인 경우 구매가 거부될 수 있다.

---

### POST `/shop/items/{item_id}/purchase` — 아이템 구매

**Response (201):**
```json
{
  "data": {
    "item_id": "uuid",
    "remaining_balance": 1200
  }
}
```

**에러:**
| code | HTTP | 조건 |
|------|------|------|
| INSUFFICIENT_COINS | 402 | 코인 잔액 부족 |
| ALREADY_OWNED | 409 | 이미 보유한 아이템 |
| ITEM_NOT_FOUND | 404 | 존재하지 않는 아이템 |

---

## 7. Character (캐릭터) — P0

### GET `/me/items` — 내 보유 아이템 목록

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "item": {
        "id": "uuid",
        "name": "신사모자",
        "category": "HAT",
        "rarity": "COMMON",
        "asset_key": "hat/hat_gentleman.png"
      },
      "purchased_at": "2026-04-10T09:00:00Z"
    }
  ]
}
```

---

### GET `/me/character` — 내 캐릭터 착용 상태

**Response (200):**
```json
{
  "data": {
    "hat": { "id": "uuid", "name": "신사모자", "asset_key": "hat/hat_gentleman.png", "rarity": "COMMON" },
    "top": null,
    "bottom": null,
    "shoes": null,
    "accessory": null
  }
}
```

---

### PUT `/me/character` — 캐릭터 착용 변경

**Request:**
```json
{
  "hat_item_id": "uuid | null",
  "top_item_id": "uuid | null",
  "bottom_item_id": null,
  "shoes_item_id": null,
  "accessory_item_id": null
}
```

**Response (200):** `/me/character` GET과 동일 형식.

**에러:**
| code | HTTP | 조건 |
|------|------|------|
| ITEM_NOT_OWNED | 403 | 보유하지 않은 아이템 착용 시도 |
| INVALID_CATEGORY | 400 | 슬롯과 카테고리 불일치 |

---

### GET `/users/{user_id}/character` — 다른 유저 캐릭터 조회

챌린지 방 멤버의 캐릭터를 조회한다. 응답 형식은 `/me/character`와 동일.

---

### POST `/challenges/{id}/verifications` 응답 변경 — P0

인증 제출 시 획득한 코인 정보가 응답에 추가된다.

**Response 추가 필드:**
```json
{
  "data": {
    "...기존 필드...",
    "coins_earned": [
      { "type": "VERIFICATION", "amount": 10 },
      { "type": "STREAK_3", "amount": 15 },
      { "type": "ALL_COMPLETED", "amount": 20 }
    ]
  }
}
```

### GET `/challenges/{id}/calendar` 응답 변경 — P0

멤버 목록에 캐릭터 착용 정보가 추가된다.

**members[] 추가 필드:**
```json
{
  "members": [
    {
      "...기존 필드...",
      "character": {
        "hat": { "asset_key": "hat/hat_gentleman.png", "rarity": "COMMON" },
        "top": null,
        "bottom": null,
        "shoes": null,
        "accessory": null
      }
    }
  ]
}
```

---

## 8. Notifications — P1

> P1: 푸시 알림 기능(F-15, F-16, F-18) 구현 시 활성화.

### POST `/devices` — 디바이스 토큰 등록

**Request:**
```json
{
  "token": "fcm-device-token-string",
  "platform": "ios"
}
```

**Response (201):**
```json
{
  "data": {
    "id": "uuid",
    "registered": true
  }
}
```

---

### GET `/notifications` — 알림 목록 — P1

> P1: 인앱 알림 히스토리(F-19) 구현 시 활성화.

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| cursor | string | N | 페이지네이션 커서 |
| limit | int | N | 페이지 크기 (기본 20, 최대 50) |

**Response (200):**
```json
{
  "data": {
    "notifications": [
      {
        "id": "uuid",
        "type": "member_verified",
        "title": "string",
        "body": "string",
        "data": {
          "challenge_id": "uuid"
        },
        "is_read": false,
        "created_at": "2026-04-05T12:00:00Z"
      }
    ],
    "next_cursor": "string | null"
  }
}
```

### PUT `/notifications/{id}/read` — 알림 읽음 처리 — P1

**Response (200):**
```json
{
  "data": {
    "id": "uuid",
    "is_read": true
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| NOTIFICATION_NOT_FOUND | 존재하지 않는 알림 |
| FORBIDDEN | 본인의 알림이 아님 |

---

## 9. 푸시 알림 이벤트 (서버 → 클라이언트) — P1

| 이벤트 | 트리거 | 수신자 | payload |
|--------|--------|--------|---------|
| verification_reminder | 스케줄러 (설정 시간) | 오늘 미인증 멤버 | `{ challenge_id, title }` |
| member_verified | 인증 제출 시 | 같은 챌린지 다른 멤버 | `{ challenge_id, user_nickname }` |
| day_completed | 전원 인증 달성 시 | 전체 멤버 | `{ challenge_id, date, season_icon_type }` |
| challenge_completed | 챌린지 기간 종료 시 | 전체 멤버 | `{ challenge_id, achievement_rate, badge }` |
| streak_milestone | 연속 인증 마일스톤 달성 시 (3, 7, 14, 30일) | 같은 챌린지 다른 멤버 (notify_streak=true) | `{ challenge_id, user_id, streak_days }` |

---

## 10. Room Decoration (방 꾸미기) — P2

미니룸·챌린지 방의 슬롯별 variant 교체. F-31. 본 섹션의 모든 엔드포인트는 인증된 사용자 한정.

공통 에러 코드:

| code | HTTP | 조건 |
|------|------|------|
| ITEM_NOT_OWNED | 403 | 보유(UserItem)하지 않은 아이템 장착 시도 (기존 §8 캐릭터와 동일 코드 재사용) |
| ITEM_CATEGORY_MISMATCH | 422 | 슬롯과 아이템 카테고리 불일치 |
| ITEM_NOT_FOUND | 404 | 존재하지 않거나 비활성(is_active=false) 아이템 |
| CR_NOT_CREATOR | 403 | 챌린지 방장이 아닌 사용자가 공용 슬롯 편집 시도 |
| CR_NOT_MEMBER | 403 | 챌린지 멤버가 아닌 사용자가 signature 편집 시도 |
| INVALID_SLOT | 422 | path 의 slot 값이 미정의 슬롯 |
| REWARD_ALREADY_CLAIMED | 409 | 동일 reward_trigger 로 이미 보상 지급됨 (Phase 5 이후 활성화) |

### GET `/me/room/miniroom` — 내 미니룸 장착 조회

`RoomEquipMr` row 가 없으면 모든 슬롯 null 응답 (자동 생성하지 않는다).

**Response (200):**
```json
{
  "data": {
    "wall": { "id": "uuid", "name": "라벤더 벽지", "category": "MR_WALL", "rarity": "COMMON", "asset_key": "mr/wall_lavender", "is_limited": false },
    "ceiling": null,
    "window": null,
    "shelf": null,
    "plant": null,
    "desk": null,
    "rug": null,
    "floor": { "id": "uuid", "name": "마루 바닥", "category": "MR_FLOOR", "rarity": "COMMON", "asset_key": "mr/floor_wood", "is_limited": false },
    "updated_at": "2026-04-19T10:00:00Z"
  }
}
```

### PUT `/me/room/miniroom` — 미니룸 슬롯 부분 변경

각 슬롯은 옵셔널. 명시된 슬롯만 변경된다. `null` 명시는 해당 슬롯을 기본값으로 되돌린다 (DELETE 와 동일 효과).

**Request:**
```json
{
  "wall_item_id": "uuid",
  "ceiling_item_id": null,
  "window_item_id": "uuid"
}
```

**Response (200):** `GET /me/room/miniroom` 와 동일한 형식의 변경 후 상태.

**에러:** `ITEM_NOT_OWNED`, `ITEM_CATEGORY_MISMATCH`, `ITEM_NOT_FOUND`.

### DELETE `/me/room/miniroom/{slot}` — 슬롯 기본값으로 복원

`{slot}` ∈ `wall | ceiling | window | shelf | plant | desk | rug | floor`.

**Response:** 204 No Content.

**에러:** `INVALID_SLOT` (422).

### GET `/challenges/{id}/room` — 챌린지 방 장착 조회

공용 슬롯 + 멤버 signature 목록.

**Response (200):**
```json
{
  "data": {
    "wall": { "id": "uuid", "name": "...", "category": "CR_WALL", "rarity": "COMMON", "asset_key": "cr/wall_green", "is_limited": false },
    "window": null,
    "calendar": null,
    "board": null,
    "sofa": null,
    "floor": null,
    "updated_by_user_id": "uuid | null",
    "updated_at": "2026-04-19T10:00:00Z",
    "signatures": [
      {
        "user_id": "uuid",
        "nickname": "민수",
        "signature_item": { "id": "uuid", "name": "강아지", "category": "SIGNATURE", "rarity": "COMMON", "asset_key": "sig/dog", "is_limited": false }
      }
    ]
  }
}
```

방 row 가 없으면 모든 슬롯 null + signatures=[].

### PUT `/challenges/{id}/room` — 챌린지 방 공용 슬롯 부분 변경 (방장 전용)

**Request:**
```json
{
  "wall_item_id": "uuid",
  "sofa_item_id": null
}
```

**Response (200):** `GET /challenges/{id}/room` 와 동일.

**에러:** `CR_NOT_CREATOR`, `ITEM_NOT_OWNED`, `ITEM_CATEGORY_MISMATCH`, `ITEM_NOT_FOUND`.

### DELETE `/challenges/{id}/room/{slot}` — 공용 슬롯 기본값 복원 (방장 전용)

`{slot}` ∈ `wall | window | calendar | board | sofa | floor`.

**Response:** 204 No Content.

**에러:** `CR_NOT_CREATOR`, `INVALID_SLOT`.

### PUT `/challenges/{id}/room/signature` — 내 signature 지정/변경

**Request:**
```json
{ "signature_item_id": "uuid" }
```

`signature_item_id` 의 Item.category 는 반드시 `SIGNATURE`.

**Response (200):**
```json
{
  "data": {
    "user_id": "uuid",
    "nickname": "민수",
    "signature_item": { "id": "uuid", "name": "강아지", "category": "SIGNATURE", "rarity": "COMMON", "asset_key": "sig/dog", "is_limited": false }
  }
}
```

**에러:** `CR_NOT_MEMBER`, `ITEM_NOT_OWNED`, `ITEM_CATEGORY_MISMATCH`, `ITEM_NOT_FOUND`.

### DELETE `/challenges/{id}/room/signature` — 내 signature 해제

**Response:** 204 No Content. signature 가 없는 경우도 idempotent 204.

**에러:** `CR_NOT_MEMBER`.

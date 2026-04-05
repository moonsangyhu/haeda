# 해다 (Haeda) — API 계약서

> 버전: 0.2 (MVP)
> 최종 수정: 2026-04-04
> Base URL: `/api/v1`

---

## P0 / P1 범위 안내

- **P0**: Auth, Challenges (생성·상세·초대코드조회·참여·완료), My Page, Verifications, Comments
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

**Response (200):**
```json
{
  "data": {
    "id": "uuid",
    "nickname": "string",
    "profile_image_url": "string | null"
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| NICKNAME_TOO_SHORT | 닉네임 2자 미만 |
| NICKNAME_TOO_LONG | 닉네임 30자 초과 |

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
  "photo_required": true
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

---

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
        "badge": null
      }
    ]
  }
}
```

`achievement_rate`: 소수점 첫째자리까지 (0.0 ~ 100.0)

---

## 4. Verifications — P0

### POST `/challenges/{id}/verifications` — 인증 제출

**Request (multipart/form-data):**
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| photo | file | 조건부 | 인증 사진 (photo_required 시 필수) |
| diary_text | string | Y | 일기 텍스트 |

**Response (201):**
```json
{
  "data": {
    "id": "uuid",
    "date": "2026-04-04",
    "photo_url": "string | null",
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
| ALREADY_VERIFIED_TODAY | 오늘 이미 인증함 |
| PHOTO_REQUIRED | 사진 필수인데 미첨부 |
| CHALLENGE_ENDED | 이미 종료된 챌린지 |

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
          "profile_image_url": "string"
        },
        "photo_url": "string | null",
        "diary_text": "오늘은 5km 달렸다!",
        "comment_count": 3,
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
      "profile_image_url": "string"
    },
    "date": "2026-04-01",
    "photo_url": "string | null",
    "diary_text": "오늘은 5km 달렸다! 날씨가 좋아서 기분이 좋았다.",
    "comments": [
      {
        "id": "uuid",
        "author": {
          "id": "uuid",
          "nickname": "이영희",
          "profile_image_url": "string"
        },
        "content": "대단해요! 👏",
        "created_at": "2026-04-01T09:00:00Z"
      }
    ],
    "created_at": "2026-04-01T08:30:00Z"
  }
}
```

---

## 5. Comments — P0

### POST `/verifications/{id}/comments` — 댓글 작성

**Request:**
```json
{
  "content": "대단해요! 👏"
}
```

**Response (201):**
```json
{
  "data": {
    "id": "uuid",
    "author": {
      "id": "uuid",
      "nickname": "이영희",
      "profile_image_url": "string"
    },
    "content": "대단해요! 👏",
    "created_at": "2026-04-01T09:00:00Z"
  }
}
```

**에러:**
| code | 조건 |
|------|------|
| VERIFICATION_NOT_FOUND | 존재하지 않는 인증 |
| NOT_A_MEMBER | 해당 챌린지 참여자가 아님 |
| COMMENT_TOO_LONG | 500자 초과 |

---

### GET `/verifications/{id}/comments` — 댓글 목록

**Query Parameters:**
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| cursor | string | N | 페이지네이션 커서 |
| limit | int | N | 페이지 크기 (기본 20) |

**Response (200):**
```json
{
  "data": {
    "comments": [
      {
        "id": "uuid",
        "author": {
          "id": "uuid",
          "nickname": "string",
          "profile_image_url": "string"
        },
        "content": "string",
        "created_at": "2026-04-01T09:00:00Z"
      }
    ],
    "next_cursor": "string | null"
  }
}
```

---

## 6. Notifications — P1

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

## 7. 푸시 알림 이벤트 (서버 → 클라이언트) — P1

| 이벤트 | 트리거 | 수신자 | payload |
|--------|--------|--------|---------|
| verification_reminder | 스케줄러 (설정 시간) | 오늘 미인증 멤버 | `{ challenge_id, title }` |
| member_verified | 인증 제출 시 | 같은 챌린지 다른 멤버 | `{ challenge_id, user_nickname }` |
| day_completed | 전원 인증 달성 시 | 전체 멤버 | `{ challenge_id, date, season_icon_type }` |
| challenge_completed | 챌린지 기간 종료 시 | 전체 멤버 | `{ challenge_id, achievement_rate, badge }` |

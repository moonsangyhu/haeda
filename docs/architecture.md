# 해다 (Haeda) — 아키텍처

> 버전: 0.1
> 최종 수정: 2026-04-04
> 대상 범위: P0 (MVP 첫 릴리스)

---

## 1. 시스템 개요

```
┌──────────────────┐       HTTPS        ┌──────────────────┐      ┌────────────┐
│   Flutter App    │ ◀──────────────▶  │  FastAPI Server   │ ───▶ │ PostgreSQL │
│  (iOS/Android)   │                    │  (Python 3.12+)  │      └────────────┘
└──────────────────┘                    │                  │      ┌────────────┐
                                        │                  │ ───▶ │ Object     │
                                        │                  │      │ Storage    │
                                        └──────────────────┘      └────────────┘
```

- 클라이언트: Flutter 단일 코드베이스 (iOS + Android)
- 서버: Python FastAPI, 단일 프로세스 (파일럿 규모 50명 이하)
- DB: PostgreSQL (단일 인스턴스)
- 이미지 저장소: 미확정 (S3 / Firebase Storage / R2 — Open Questions 참조)

---

## 2. Flutter 앱 구조

### 2.1 디렉토리 레이아웃

```
lib/
├── main.dart
├── app/
│   ├── router.dart                  # GoRouter 기반 라우팅
│   └── theme.dart                   # 앱 테마 (계절 아이콘 포함)
├── core/
│   ├── api/
│   │   ├── api_client.dart          # HTTP 클라이언트 (dio)
│   │   ├── auth_interceptor.dart    # Bearer 토큰 자동 주입
│   │   └── error_handler.dart       # 공통 에러 코드 처리
│   ├── auth/
│   │   ├── auth_provider.dart       # 인증 상태 관리
│   │   └── token_storage.dart       # secure storage에 토큰 저장
│   └── image/
│       └── image_picker_service.dart # 카메라/갤러리 선택 + 리사이즈
├── features/
│   ├── auth/                        # Flow 1: 로그인, 프로필 설정
│   ├── my_page/                     # Flow 2: 내 챌린지 목록
│   ├── challenge_create/            # Flow 3: 챌린지 생성
│   ├── challenge_join/              # Flow 4-A: 초대 링크 참여
│   ├── challenge_space/             # Flow 5: 달력 뷰 (핵심 화면)
│   ├── verification/                # Flow 6, 7: 인증 제출, 인증 상세 + 댓글
│   └── challenge_complete/          # Flow 8: 완료 결과
└── shared/
    ├── models/                      # 공유 데이터 모델 (Challenge, User 등)
    ├── widgets/                     # 공통 위젯 (프로필 썸네일, 카드 등)
    └── utils/                       # 날짜 유틸, 계절 판정 등
```

### 2.2 상태 관리

- **Riverpod** 사용
- 각 feature별 독립 Provider 구성
- 인증 상태는 `core/auth/auth_provider.dart`에서 전역 관리

### 2.3 라우팅

챌린지(Challenge)가 핵심 객체이므로, 라우팅도 챌린지 ID 기반으로 구성한다.

```
/                              → 내 페이지 (메인)
/login                         → 로그인
/profile-setup                 → 프로필 설정 (최초 1회)
/challenges/create             → 챌린지 생성
/challenges/:id                → 챌린지 공간 (달력 뷰)
/challenges/:id/verify         → 인증 작성
/challenges/:id/date/:date     → 날짜별 인증 현황
/challenges/:id/completion     → 챌린지 완료 결과
/verifications/:id             → 인증 상세 (사진+일기+댓글)
/invite/:code                  → 초대 링크 딥링크 진입
```

---

## 3. FastAPI 서버 구조

### 3.1 디렉토리 레이아웃

```
server/
├── main.py                          # FastAPI 앱 진입점
├── core/
│   ├── config.py                    # 환경 설정 (DB URL, 시크릿 등)
│   ├── database.py                  # SQLAlchemy async session
│   ├── security.py                  # JWT 발급/검증, 카카오 토큰 검증
│   └── dependencies.py              # FastAPI Depends (현재 유저, DB 세션)
├── models/                          # SQLAlchemy ORM 모델
│   ├── user.py                      # User
│   ├── challenge.py                 # Challenge
│   ├── challenge_member.py          # ChallengeMember
│   ├── verification.py              # Verification
│   ├── day_completion.py            # DayCompletion
│   └── comment.py                   # Comment
├── schemas/                         # Pydantic 요청/응답 스키마
│   ├── auth.py
│   ├── challenge.py
│   ├── verification.py
│   └── comment.py
├── routers/                         # API 라우터 (api-contract.md 섹션 1:1 대응)
│   ├── auth.py                      # /auth/*
│   ├── challenges.py                # /challenges/*
│   ├── my_page.py                   # /me/*
│   ├── verifications.py             # /verifications/*, /challenges/{id}/verifications/*
│   └── comments.py                  # /verifications/{id}/comments/*
├── services/                        # 비즈니스 로직
│   ├── auth_service.py              # 카카오 로그인, 토큰 발급
│   ├── challenge_service.py         # 챌린지 생성, 참여, 완료
│   ├── verification_service.py      # 인증 제출, 전원 인증 판정
│   ├── calendar_service.py          # 달력 뷰 데이터 조회
│   ├── completion_service.py        # 챌린지 완료 결과 집계
│   └── image_service.py             # 이미지 업로드, 리사이즈, 서명 URL
├── tasks/                           # 백그라운드 작업
│   └── challenge_scheduler.py       # 매일 자정: 챌린지 자동 종료, 배지 부여
├── migrations/                      # Alembic DB 마이그레이션
└── tests/
```

### 3.2 레이어 규칙

```
Router → Service → Model(ORM) → DB
  │          │
  │          └── 비즈니스 로직 (달성률 계산, 전원 인증 판정 등)
  └── 요청 검증 (Pydantic schema), 응답 직렬화
```

- Router: HTTP 관심사만 (파라미터 파싱, 응답 코드)
- Service: 비즈니스 규칙, 트랜잭션 경계
- Model: ORM 매핑, 쿼리

---

## 4. PostgreSQL 주요 테이블

> 상세 스키마는 `docs/domain-model.md` 참조. 여기서는 관계와 핵심 인덱스만 요약.

### 4.1 P0 테이블

```
User ─────────────┐
  │                │
  │ (user_id)      │ (creator_id)
  ▼                ▼
ChallengeMember ──▶ Challenge
  │                    │
  │ (user_id,          │ (challenge_id)
  │  challenge_id)     ▼
  ▼              DayCompletion
Verification
  │
  │ (verification_id)
  ▼
Comment
```

### 4.2 핵심 쿼리와 인덱스 매핑

| 화면 / 기능 | 주요 쿼리 | 사용 인덱스 |
|-------------|----------|------------|
| 내 페이지 | ChallengeMember WHERE user_id → JOIN Challenge | idx_member_user_id |
| 달력 뷰 | Verification WHERE challenge_id, date BETWEEN ... | idx_verification_challenge_date |
| 달력 뷰 (전원 인증) | DayCompletion WHERE challenge_id | idx_day_completion_challenge |
| 날짜별 인증 목록 | Verification WHERE challenge_id, date | idx_verification_challenge_date |
| 인증 상세 댓글 | Comment WHERE verification_id | idx_comment_verification |
| 초대 코드 조회 | Challenge WHERE invite_code | idx_challenge_invite_code |

---

## 5. 이미지 업로드 전략

### 5.1 업로드 흐름

```
Flutter App                          FastAPI                        Object Storage
    │                                   │                               │
    │  POST /challenges/{id}/verifications                              │
    │  (multipart: photo + diary_text)  │                               │
    │ ─────────────────────────────────▶│                               │
    │                                   │  1. 이미지 검증               │
    │                                   │     - 파일 타입: JPEG/PNG     │
    │                                   │     - 최대 크기: 10MB         │
    │                                   │                               │
    │                                   │  2. 리사이즈                  │
    │                                   │     - 최대 1280px (긴 변)     │
    │                                   │     - JPEG 80% 품질           │
    │                                   │                               │
    │                                   │  3. 업로드 ─────────────────▶│
    │                                   │     key: verifications/       │
    │                                   │       {challenge_id}/{date}/  │
    │                                   │       {user_id}.jpg           │
    │                                   │                               │
    │                                   │  4. 서명된 URL 생성           │
    │                                   │     (읽기 전용, TTL: 1시간)   │
    │                                   │                               │
    │                                   │  5. Verification 레코드 저장  │
    │                                   │     photo_url = 서명된 URL    │
    │  ◀─────────────────────────────── │                               │
    │  201 { data: { photo_url, ... } } │                               │
```

### 5.2 클라이언트 측 사전 처리

- 카메라/갤러리 선택 후 클라이언트에서 1차 리사이즈 (최대 2000px)
- 서버 업로드 크기 절감 목적

### 5.3 서명된 URL

- 이미지 조회 시 서버가 서명된 URL(presigned URL)을 생성하여 반환
- TTL: 1시간 (만료 시 클라이언트가 API 재호출하여 갱신)
- 저장소 직접 노출 방지

> **Open Question**: 저장소 선택 (S3 / Firebase Storage / R2)은 미확정. 서비스 레이어에서 추상화하여 교체 용이하게 설계한다.

---

## 6. 인증 흐름 (카카오 OAuth)

```
Flutter App            카카오 서버              FastAPI
    │                      │                      │
    │  1. 카카오 로그인 SDK  │                      │
    │ ────────────────────▶│                      │
    │                      │                      │
    │  2. kakao_access_token                      │
    │ ◀────────────────────│                      │
    │                      │                      │
    │  3. POST /auth/kakao                        │
    │     { kakao_access_token }                  │
    │ ───────────────────────────────────────────▶│
    │                                              │
    │                      │  4. 토큰 검증 요청     │
    │                      │ ◀─────────────────── │
    │                      │                      │
    │                      │  5. 사용자 정보 응답   │
    │                      │ ──────────────────▶  │
    │                                              │
    │                         6. User upsert       │
    │                            (kakao_id 기준)   │
    │                                              │
    │                         7. JWT 발급           │
    │                            access_token      │
    │                            refresh_token     │
    │                                              │
    │  8. { access_token, refresh_token, user }    │
    │ ◀─────────────────────────────────────────── │
    │                                              │
    │  이후 모든 API 요청:                          │
    │  Authorization: Bearer <access_token>        │
    │ ───────────────────────────────────────────▶│
```

### 토큰 전략

| 토큰 | 용도 | TTL | 저장 위치 |
|------|------|-----|-----------|
| access_token | API 인증 | 1시간 | Flutter secure storage |
| refresh_token | access_token 갱신 | 30일 | Flutter secure storage |
| kakao_access_token | 카카오 API 호출 (서버에서 1회 사용 후 폐기) | — | 메모리 (전달 후 폐기) |

### 토큰 갱신

```
access_token 만료 (401 UNAUTHORIZED)
  │
  ▼
POST /auth/refresh { refresh_token }
  │
  ├── 성공 → 새 access_token + refresh_token 발급
  └── 실패 (refresh_token도 만료) → 로그인 화면으로 이동
```

---

## 7. 핵심 요청 흐름

### 7.1 달력 조회 (Flow 5)

```
Flutter: 챌린지 공간 진입
  │
  ▼
GET /api/v1/challenges/{id}/calendar?year=2026&month=4
  │
  ▼ FastAPI
  │
  ├── 1. 현재 유저가 챌린지 멤버인지 확인
  │      (ChallengeMember WHERE challenge_id, user_id)
  │
  ├── 2. 해당 월의 Verification 조회
  │      (Verification WHERE challenge_id, date BETWEEN 4/1~4/30)
  │      → 날짜별 verified_members 리스트 구성
  │
  ├── 3. 해당 월의 DayCompletion 조회
  │      (DayCompletion WHERE challenge_id, date BETWEEN 4/1~4/30)
  │      → all_completed, season_icon_type 매핑
  │
  ├── 4. 챌린지 멤버 목록 조회
  │      (ChallengeMember JOIN User WHERE challenge_id)
  │      → members 리스트 (id, nickname, profile_image_url)
  │
  └── 5. 응답 조립
         { challenge_id, year, month, members, days[] }
```

### 7.2 인증 제출 (Flow 6)

```
Flutter: [제출하기] 탭
  │
  ▼
POST /api/v1/challenges/{id}/verifications
  (multipart: photo + diary_text)
  │
  ▼ FastAPI
  │
  ├── 1. 사전 검증
  │      - 챌린지 존재 여부 (CHALLENGE_NOT_FOUND)
  │      - 멤버 여부 (NOT_A_MEMBER)
  │      - 챌린지 상태 active 여부 (CHALLENGE_ENDED)
  │      - 오늘 중복 인증 여부 (ALREADY_VERIFIED_TODAY)
  │      - photo_required인데 사진 미첨부 여부 (PHOTO_REQUIRED)
  │
  ├── 2. 이미지 처리 (사진 있을 경우)
  │      - 검증 → 리사이즈 → 저장소 업로드 → 서명된 URL
  │
  ├── 3. Verification 레코드 생성
  │      INSERT INTO verification (challenge_id, user_id, date, photo_url, diary_text)
  │
  ├── 4. 전원 인증 판정
  │      COUNT(Verification WHERE challenge_id, date=today) == COUNT(ChallengeMember)?
  │      ├── YES → DayCompletion 레코드 생성, season_icon_type 판정
  │      └── NO  → day_completed: false
  │
  └── 5. 응답
         { id, date, photo_url, diary_text, day_completed, season_icon_type }
```

### 7.3 댓글 조회 (Flow 7)

```
Flutter: 인증 상세 화면 진입
  │
  ▼
GET /api/v1/verifications/{id}
  │
  ▼ FastAPI
  │
  ├── 1. Verification 조회 (JOIN User)
  │      → user, date, photo_url, diary_text
  │
  ├── 2. Comment 목록 조회 (JOIN User AS author)
  │      → comments[] (id, author, content, created_at)
  │      ORDER BY created_at ASC
  │
  └── 3. 응답 조립
         { verification + comments 포함 }

---

Flutter: 댓글 작성
  │
  ▼
POST /api/v1/verifications/{id}/comments
  { content: "대단해요!" }
  │
  ▼ FastAPI
  │
  ├── 1. Verification 존재 확인 (VERIFICATION_NOT_FOUND)
  ├── 2. 해당 챌린지 멤버 여부 확인 (NOT_A_MEMBER)
  ├── 3. 내용 길이 검증 (COMMENT_TOO_LONG, 500자)
  ├── 4. Comment 레코드 생성
  └── 5. 응답
         { id, author, content, created_at }
```

---

## 8. 배포 구성 (파일럿)

| 구성 요소 | 환경 | 비고 |
|-----------|------|------|
| FastAPI 서버 | 단일 VPS 또는 컨테이너 (1 인스턴스) | 파일럿 50명 규모, 수평 확장 불필요 |
| PostgreSQL | 동일 서버 또는 매니지드 DB | 일일 자동 백업 |
| Object Storage | 미확정 | 서비스 레이어 추상화 |
| HTTPS | Let's Encrypt 또는 클라우드 로드밸런서 | 필수 |
| 스케줄러 | APScheduler (in-process) 또는 시스템 cron | 매일 자정: 챌린지 종료 처리 |

---

## Open Questions

| # | 항목 | 영향 |
|---|------|------|
| 1 | 사진 저장소 선택 (S3 / Firebase Storage / R2) | 이미지 업로드 구현, 서명 URL 방식, 비용 |
| 2 | 배포 환경 선택 (VPS vs 컨테이너 vs 서버리스) | CI/CD, 모니터링 구성 |
| 3 | Flutter 상태 관리 확정 (Riverpod vs Bloc) | 코드 구조, 테스트 방식 |
| 4 | access_token/refresh_token 정확한 TTL | 보안과 UX 균형 |
| 5 | 클라이언트 이미지 사전 리사이즈 해상도 기준 | 업로드 속도, 이미지 품질 |

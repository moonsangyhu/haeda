# Status Bar Challenge Pill — 가장 최근 챌린지 진입 + 이모지 식별

- **Date**: 2026-04-28
- **Area**: full-stack (server + app)
- **Status**: ready

## 목적

`StatusBar` 의 lightning pill 을 다음과 같이 변환한다:
1. **탭** → 사용자가 가장 최근에 인증한 챌린지의 `/challenges/:id` 로 진입
2. **아이콘** → 단순 lightning 이 아니라 "그 챌린지가 어떤 챌린지인지" 한 글리프로 식별 가능한 이모지

streak / gem pill 과 같은 "탭 가능 + 글리프 + 숫자" 위계를 유지하면서, 마지막으로 변환되지 않은 lightning pill 의 가치를 끌어올린다.

## 결정 (브레인스토밍 결과)

| # | 항목 | 결정 |
|---|------|------|
| 1 | "가장 최근" 의 정의 | 가장 최근에 인증한 챌린지 (`last_verified_at` desc) |
| 2 | 아이콘 전략 | 챌린지 단위 이모지 1개 (신규 `Challenge.icon` 필드) |
| 3 | 챌린지 0개일 때 | fallback `lightning.svg` + 탭 시 `/create` 진입 |
| 4 | Pill 텍스트 | `[🏃 N]` — 이모지 + active 챌린지 개수 (`activeChallenges`) |
| 5 | 입력 UX | 챌린지 생성 Step1 에 TextField (`maxLength=2`) + blank 시 `🎯` default |
| 6 | 범위 | 백엔드 + 프론트 pill + Step1 입력 까지. 챌린지방 (`/challenges/:id`) 에서 이모지 수정 은 follow-up |

## 아키텍처

### 백엔드 (FastAPI + SQLAlchemy 2.0 async + Alembic)

#### 1. 스키마 변경
- `Challenge` 모델에 `icon: str = mapped_column(String(8), nullable=False, server_default='🎯')` 추가
- 길이 8 byte 는 ZWJ + variation selector 까지 포함하는 단일 emoji 의 UTF-8 인코딩 상한 (대부분 4 byte, 가족 emoji 등 최대 7 byte 관측). 안전 마진 1 byte.

#### 2. Migration — `023_add_challenge_icon`
- `op.add_column('challenges', sa.Column('icon', sa.String(8), nullable=False, server_default='🎯'))`
- 기존 row 는 server_default 로 자동 backfill `'🎯'`
- downgrade: `op.drop_column('challenges', 'icon')`

#### 3. API contract 업데이트 (`docs/api-contract.md`)

```
POST /challenges (body)
  + icon: string (optional, default '🎯', maxLength 8 byte)

GET /challenges/:id (response.data)
  + icon: string

GET /me/challenges (response.data.challenges[*])
  + icon: string
  + last_verified_at: string | null  (ISO 8601 datetime, 마지막 verification.created_at)

  ordering rule:
    last_verified_at DESC NULLS LAST,
    start_date DESC  (tie-breaker)
```

#### 4. Service 변경
- `challenge_service.create_challenge()` — body 의 `icon` 값 사용 (없으면 `'🎯'`)
- `challenge_service.list_my_challenges(user_id)`:
  - Verification table 에 대한 subquery `SELECT challenge_id, MAX(created_at) AS last_verified_at FROM verifications GROUP BY challenge_id`
  - challenge LEFT JOIN subquery
  - ORDER BY `last_verified_at DESC NULLS LAST, start_date DESC`

### 프론트엔드 (Flutter + Riverpod + GoRouter + freezed)

#### 1. Models
- `ChallengeSummary` — `icon: String` (`@Default('🎯')`) + `lastVerifiedAt: DateTime?` (`@JsonKey(name: 'last_verified_at')`)
- `ChallengeDetail` — `icon: String` (`@Default('🎯')`)
- `ChallengeCreateRequest` (provider) — `icon: String` 필드 추가, request body 직렬화 시 포함

#### 2. Provider — 신규
`app/lib/features/status_bar/providers/most_recent_challenge_provider.dart`
```dart
final mostRecentChallengeProvider = Provider<ChallengeSummary?>((ref) {
  final list = ref.watch(myChallengesProvider).valueOrNull ?? const [];
  // 백엔드가 last_verified_at desc nulls last 로 정렬해 주므로 첫 항목.
  return list.isEmpty ? null : list.first;
});
```

#### 3. StatusBar 위젯 변경
- 기존 lightning pill 인라인 `_StatPill` 을 별도 `_ChallengePill` 로 추출 (단일 책임).
- 분기:
  - `mostRecentChallenge != null` → `_StatItem(emoji: c.icon, value: '${stats.activeChallenges}')` + `InkWell.onTap = context.push('/challenges/${c.id}')`
  - `mostRecentChallenge == null` → `_StatItem(asset: 'lightning', value: '${stats.activeChallenges}')` + `InkWell.onTap = context.push('/create')`
- `_StatItem` 시그니처 확장: `asset` 또는 `emoji` 둘 중 하나. emoji 면 `Text(emoji, fontSize: 20)`, asset 면 기존 `SvgPicture.asset`.
- Semantics label 도 분기 (`'챌린지 ${c.title}, 진행 중 N개'` vs `'챌린지 없음, 만들기'`).

#### 4. ChallengeCreateStep1Screen 변경
- "이모지" 라벨 + `TextFormField` 추가 (controller `_iconController`, `maxLength=2`, `hintText='🎯'`).
- 다음 단계로 넘길 때 비어있으면 `'🎯'` 로 채워 `extra` 에 포함.
- Step2 의 `ChallengeCreateRequest` 생성 시 icon 필드 전달.

### 데이터 흐름

```
[챌린지 생성]
  사용자 Step1: title=아침 운동 / category=운동 / icon=🏃
  → POST /challenges {title, category, icon: "🏃", ...}
  → DB: Challenge.icon = "🏃"
  → 응답에 icon 포함

[인증]
  POST /challenges/:id/verifications
  → Verification.created_at = now
  → 다음 GET /me/challenges 호출 시 이 challenge 의 last_verified_at = now

[StatusBar 렌더]
  ref.watch(myChallengesProvider) → [{id, icon, last_verified_at, ...}, ...]
                                     (서버 정렬: last_verified_at DESC NULLS LAST)
  ref.watch(mostRecentChallengeProvider) → list[0] (또는 null)
  pill = mostRecent != null
    ? [Text(mostRecent.icon) + Text(stats.activeChallenges)] (탭 → /challenges/{id})
    : [SvgPicture('lightning') + Text(stats.activeChallenges)] (탭 → /create)
```

## 컴포넌트 분해

| # | 컴포넌트 | 책임 | 의존 |
|---|---------|------|------|
| 1 | `Challenge` 모델 (server) | DB 스키마 | — |
| 2 | Migration 023 | 컬럼 추가 + backfill | 모델 |
| 3 | `challenge_service.create_challenge` | icon 저장 | 모델 |
| 4 | `challenge_service.list_my_challenges` | last_verified_at 계산 + 정렬 | 모델, Verification |
| 5 | API schemas (server) | icon, last_verified_at 응답 형식 | 모델 |
| 6 | api-contract.md 업데이트 | 명세 | — |
| 7 | `ChallengeSummary` model (app) | icon, lastVerifiedAt 필드 | API contract |
| 8 | `ChallengeDetail` model (app) | icon 필드 | API contract |
| 9 | `mostRecentChallengeProvider` | 가장 최근 챌린지 selector | myChallengesProvider |
| 10 | `StatusBar._ChallengePill` | pill 렌더 분기 | provider, ChallengeSummary |
| 11 | `_StatItem` 확장 | asset|emoji 둘 중 하나 | — |
| 12 | `ChallengeCreateStep1Screen` icon 필드 | 입력 + default | — |
| 13 | `ChallengeCreateRequest` icon 필드 | 직렬화 | — |

## 테스트 (TDD 사이클)

### 백엔드 (pytest)
- `test_challenge_create.py`:
  - icon 받은 채로 생성 → 응답 + DB 에 그대로 저장
  - icon 없이 생성 → 기본 `'🎯'` 저장
  - icon 길이 제약 (서버 검증) — 9 byte 거부 422
- `test_me_challenges.py`:
  - verification 0개 챌린지의 `last_verified_at` = null
  - verification 있는 챌린지의 `last_verified_at` = max(created_at) ISO string
  - 정렬: 최근 verified > 옛 verified > null > null (start_date desc tie-breaker)
  - `icon` 응답 포함
- migration test:
  - upgrade → 기존 challenge.icon = `'🎯'` 채워짐
  - downgrade → icon column 제거

### 프론트엔드 (flutter test)
- `status_bar_test.dart`:
  - 챌린지 0개 → lightning SVG 보임 + tap → /create 진입 검증
  - 챌린지 있을 때 → 첫 챌린지 icon 텍스트 보임 + active 개수 + tap → /challenges/{id} 진입
  - 가장 최근 챌린지의 icon 이 다른 챌린지가 추가되어도 list[0] 기준으로 갱신되는지 (provider override 로 테스트)
- `challenge_create_step1_screen_test.dart`:
  - icon 비워둔 채 다음 → step2 extra 의 icon = `'🎯'`
  - icon 입력 후 다음 → step2 extra 의 icon = 입력값

### 시뮬레이터 시각 검증 (`haeda-ios-tap` 스킬)
1. 신규 사용자 (챌린지 0개) → status bar pill = lightning, 탭 → /create 진입
2. 챌린지 만들기 (icon=🏃) → 완료 → my-page 복귀, status bar pill = `[🏃 1]`
3. pill 탭 → /challenges/{id} 의 챌린지방 진입
4. 두 번째 챌린지 만들기 (icon=📚) → 인증 안 함 → status bar pill = `[🏃 2]` (이전 인증 챌린지가 우선)
5. 새 챌린지 인증 → status bar pill = `[📚 2]` (가장 최근 인증 기준 변경 확인)

## 에러 처리

- 응답에 icon 누락 (서버 미배포 / 캐시) → 모델 `@Default('🎯')` 로 안전.
- 응답에 last_verified_at 누락 → null. 정렬은 서버 책임이라 클라이언트는 들어온 순서 그대로 사용.
- 챌린지방 진입 실패 → `/challenges/:id` 의 기본 에러 처리 (변경 없음).
- icon 입력에 emoji 가 아닌 일반 문자 들어와도 거부하지 않음 (텍스트 fallback). MVP 단순화.
- icon 길이 백엔드에서 8 byte 초과 시 `INVALID_INPUT` 422.

## 변경 파일 목록

### 백엔드
- `server/alembic/versions/20260428_0001_023_add_challenge_icon.py` (신규)
- `server/app/models/challenge.py` (icon 컬럼 추가)
- `server/app/schemas/challenge.py` (icon, last_verified_at 응답)
- `server/app/services/challenge_service.py` (create + list_my_challenges)
- `server/app/routers/challenges.py` (필요 시 schema mapping)
- `server/app/routers/me.py` (응답)
- `server/tests/conftest.py` (Challenge fixture 에 icon 인자)
- `server/tests/test_challenge_create.py` (신규 케이스)
- `server/tests/test_me_challenges.py` (신규 케이스)

### 프론트엔드
- `app/lib/features/my_page/models/challenge_summary.dart`
- `app/lib/features/challenge_space/models/challenge_detail.dart`
- `app/lib/features/challenge_create/models/challenge_create_response.dart` (이미 icon 있을 수도)
- `app/lib/features/challenge_create/providers/challenge_create_provider.dart` (icon 필드)
- `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart`
- `app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart` (extra 통과)
- `app/lib/features/status_bar/widgets/status_bar.dart`
- `app/lib/features/status_bar/providers/most_recent_challenge_provider.dart` (신규)
- `app/test/features/status_bar/widgets/status_bar_test.dart`
- `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart`

### 문서
- `docs/api-contract.md` — 챌린지 섹션 (POST /challenges + GET /me/challenges + GET /challenges/:id) 업데이트

## Out of Scope (follow-up)

- 챌린지방 (`/challenges/:id`) 에서 이모지 수정 affordance — 별도 PR
- preset emoji chip 그리드 (12-16개 자주 쓰는 이모지 + "직접 입력")
- emoji picker 패키지 도입
- ChallengeCard (my-page 목록) 에 이모지 노출
- /challenges 전용 풀스크린 페이지 (gem/streak 페이지 와 같은 패턴) — 현 디자인은 pill → 챌린지방 직접 진입이라 중간 페이지 불필요

## Related

- 선례 (같은 패턴 status-bar pill 변환):
  - `docs/reports/2026-04-27-feature-streak-page.md` (streak pill → /streak)
  - `docs/reports/2026-04-27-feature-gems-page.md` (gem pill → /gems)
- API contract: `docs/ARCHIVE/api-contract.md` (현재 challenge 섹션)
- 도메인 모델: `docs/ARCHIVE/domain-model.md` (Challenge 엔티티)
- Status bar 위젯: `app/lib/features/status_bar/widgets/status_bar.dart`

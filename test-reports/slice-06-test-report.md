# Slice-06 테스트 결과서

> 최종 업데이트: 2026-04-05 (2차 — 보완 후 재판정)
> 판정: **완료**

## 슬라이스 개요

| 항목 | 내용 |
|------|------|
| 슬라이스 | slice-06 (챌린지 종료 스케줄러) |
| 목적 | 종료일이 지난 active 챌린지를 completed로 전환하고, 멤버별 badge를 부여하며, 내 페이지 완료 카드에 배지를 표시 |
| 관련 Flow | user-flows.md Flow 2 (내 페이지 완료 카드), domain-model.md §4 (챌린지 종료) |
| P0 여부 | P0 (F-07 챌린지 완료, F-08 내 챌린지 목록) |

## 구현 범위

### Backend

| 구현 항목 | 상태 | 비고 |
|-----------|------|------|
| close_expired_challenges() | 구현 완료 | end_date < today && status == 'active' → completed 전환 |
| 멤버별 badge 부여 | 구현 완료 | badge='completed' 단일 값 (PRD §9 Open Q #3 미확정) |
| 달성률 계산 재활용 | 구현 완료 | _compute_achievement_rate() import (daily/weekly 모두 지원) |
| APScheduler lifespan 등록 | 구현 완료 | main.py CronTrigger(hour=0, minute=0) 매일 자정 |

### Frontend

| 화면 | 라우트 | 상태 |
|------|--------|------|
| ChallengeCard (완료) suffix | / (내 페이지) | 구현 완료 |
| ChallengeCard 배지 획득 표시 | / (내 페이지) | 구현 완료 |

## 테스트 결과

### Backend 테스트

실행 명령: `cd server && uv run pytest -v`

#### test_scheduler.py (9건)

| 테스트 | 결과 | 비고 |
|--------|------|------|
| test_close_daily_challenge | PASS | daily 챌린지 → completed, badge=completed |
| test_close_weekly_challenge | PASS | weekly(3) 챌린지 → completed, badge=completed |
| test_already_completed_not_reprocessed | PASS | 이미 completed → count=0 |
| test_future_challenge_not_closed | PASS | end_date >= today → status 유지 |
| test_ongoing_challenge_not_closed | PASS | end_date == today → 종료 안됨 |
| test_daily_expected_days_calculation | PASS | total_days=30, 26/30=86.7% |
| test_weekly_expected_days_calculation | PASS | expected=ceil(28/7)*3=12, 10/12=83.3% |
| test_completion_after_scheduler | PASS | scheduler 후 GET /completion 200 정상 |
| test_me_challenges_after_scheduler | PASS | scheduler 후 GET /me/challenges badge=completed |

#### test_scheduler_registration.py (2건)

| 테스트 | 결과 | 비고 |
|--------|------|------|
| test_scheduler_running_and_job_registered | PASS | lifespan 후 scheduler running, job 존재 |
| test_scheduler_job_trigger_is_daily_midnight | PASS | CronTrigger hour=0, minute=0 |

**요약**: 11 passed, 0 failed (전체 backend 65 passed, 0 failed)

### Frontend 테스트

실행 명령: `cd app && flutter test`

#### challenge_card_test.dart (6건)

| 테스트 | 결과 | 비고 |
|--------|------|------|
| displays title, achievement rate, and member count | PASS | 기본 카드 렌더링 |
| completed challenge shows (완료) suffix on title | PASS | "물 마시기 (완료)" |
| active challenge does not show (완료) suffix | PASS | |
| completed challenge with badge shows 배지 획득 label | PASS | |
| completed challenge without badge does not show 배지 획득 | PASS | |
| achievement rate displays with one decimal place | PASS | "달성률 86.7%" |

#### my_page_screen_test.dart (8건)

| 테스트 | 결과 | 비고 |
|--------|------|------|
| active 챌린지와 completed 챌린지가 분리되어 표시된다 | PASS | 섹션 분리 확인 |
| 챌린지가 없으면 빈 상태 메시지가 표시된다 | PASS | |
| loading 상태에서 로딩 위젯이 표시된다 | PASS | |
| error 상태에서 에러 메시지와 재시도 버튼이 표시된다 | PASS | |
| completed 챌린지에 badge가 있으면 배지 획득이 표시된다 | PASS | |
| completed 챌린지에 badge가 없으면 배지 획득이 없다 | PASS | |
| active만 있을 때 완료 섹션이 없다 | PASS | |
| completed만 있을 때 참여 중 섹션이 없다 | PASS | |

**요약**: 14 passed, 0 failed (전체 flutter 76 passed, 0 failed)

### Local Smoke Test

| 항목 | 결과 | 확인 방법 |
|------|------|----------|
| PostgreSQL 접속 | PASS | pg_isready -h localhost -p 5432 → "accepting connections" |
| Backend health | PASS | curl http://localhost:8000/health → {"status":"ok"} |
| APScheduler 설치 확인 | PASS | docker exec — apscheduler 3.11.2 |
| Scheduler 실행 (docker exec) | PASS | close_expired_challenges(today=2026-04-05) → "Processed 1 challenge(s)" |
| Challenge status 전환 | PASS | DB 직접 확인: status='completed' |
| 멤버 badge 부여 | PASS | DB 직접 확인: 3명 모두 badge='completed' |
| GET /me/challenges?status=completed | PASS | curl 200, badge="completed", achievement_rate=53.3 |
| GET /challenges/{id}/completion | PASS | curl 200, my_result.badge="completed", members 3명, calendar_summary 정상 |
| Scheduler 재실행 (idempotency) | PASS | 이미 completed → "Processed 0 challenge(s)" |
| Flutter 웹 빌드 | PASS | flutter build web → "Built build/web" |
| Flutter UI 연동 | [미실행] | 브라우저 실행 환경 제한 |

## 확인 구분

### 실제 확인한 것
- Backend pytest 11건(slice-06) + 전체 65건 직접 실행 → 65 passed
- Flutter widget test 14건(slice-06) + 전체 76건 직접 실행 → 76 passed
- Docker Postgres + 시드 데이터로 실제 scheduler 실행 + API curl 직접 호출
- DB 직접 조회로 status/badge 전환 확인
- Scheduler idempotency 확인 (재실행 시 count=0)
- APScheduler 3.11.2 설치 확인 (docker exec)
- Flutter 웹 빌드 성공 확인
- spec-keeper 에이전트 2회 실행 (1차: 5+2+3, 2차: 12+2+0)
- qa-reviewer 에이전트 2회 실행 (1차: 14통과+2수정+1개선, 2차: 25통과+0수정+1개선)
- docs-drift-check로 전체 코드↔문서 정합성 확인 (slice-06 관련 drift 0건)

### 미확인 / 추정
- Flutter → Backend 실제 연동 (브라우저 실행 불가). ResponseInterceptor의 envelope 자동 해제가 이전 슬라이스에서 검증됨.
- APScheduler CronTrigger가 실제 자정에 동작하는지 (테스트로 trigger 설정 검증됨, 실제 cron 실행은 시간이 필요)

## Spec Drift 점검

### spec-keeper 검토 결과 (2차 — 보완 후)
- **일치 12건**: 종료 조건, status 전환, status 허용값, badge 부여, 달성률 공식, 단일 badge 허용, P1 미구현, **lifespan 스케줄러 등록**, job ID/replace_existing, lifespan shutdown, 완료 suffix, 배지 표시
- **주의 2건**: (1) 배지 디자인 규칙 미결정 (PRD §9 Open Q #3), (2) P1 완료 푸시 알림 미구현
- **불일치 0건**

### docs-drift-check 결과
- API 경로: 구현된 모든 P0 엔드포인트 일치 (Auth 슬라이스 미구현은 별도)
- 응답 스키마: drift 없음
- DB 모델: drift 없음
- 에러 코드: INTERNAL_ERROR 1건 문서 미정의 (slice-06 외 기존 코드)
- 화면 플로우: Auth 화면 4개 미구현 (별도 슬라이스)

### qa-reviewer 결과 (2차 — 보완 후)
- **통과 25건**: 이전 blocking "[1] 스케줄러 미등록" 해소 확인 포함
- **수정 필요 0건**
- **개선 권장 1건**: _compute_achievement_rate() 반환값 미사용 (의도적, 배지 규칙 미확정)

## 이슈

### Blocking
- 없음 (이전 blocking "스케줄러 등록 누락"은 main.py lifespan + APScheduler로 해소됨)

### Non-blocking (3건)
- `scheduler_service.py:89-94` — `_compute_achievement_rate()` 반환값 미사용. 배지 규칙 확정 전까지 의도적이나 불필요한 연산.
- `challenge_service.py:487` — `my_result`에 `type: ignore[arg-type]` 사용. Race condition 시 RuntimeError 가능 (slice-05에서도 지적됨).
- ChallengeCard에서 completed 카드의 참여자수와 배지를 동시 표시 — user-flows.md Flow 2 와이어프레임에서는 완료 카드에 "달성률 90% · 배지 획득"만 표시하나, 현재 구현은 참여자수도 함께 표시. 기능적 문제는 아니나 와이어프레임과 차이 있음.

## 에이전트/스킬 활용 내역

| 에이전트/스킬 | 사용 시점 | 결과 |
|-------------|---------|------|
| spec-keeper (1차) | 초기 스펙 검토 | 5건 일치, 2건 주의, 3건 불일치 |
| spec-keeper (2차) | 보완 후 재검증 | 12건 일치, 2건 주의, 0건 불일치. Blocking 해소 확인 |
| qa-reviewer (1차) | 초기 품질 리뷰 | 14건 통과, 2건 수정 필요, 1건 개선 권장 |
| qa-reviewer (2차) | 보완 후 재검토 | 25건 통과, 0건 수정 필요, 1건 개선 권장. "slice-06 PASS" |
| docs-drift-check | 정합성 점검 | slice-06 관련 drift 0건 |
| smoke-test (2회) | 통합 확인 | scheduler + API + idempotency + APScheduler 확인 PASS |

## 판정

- **슬라이스 완료 여부**: 완료
- **다음 슬라이스 진행 가능**: 예
- **사유**: Backend 1개 서비스(scheduler) + 1개 lifespan 등록 + Frontend 1개 위젯(ChallengeCard) 수정이 docs 기준 100% 구현. pytest 65 passed (slice-06 11건), flutter test 76 passed (slice-06 14건). Local API smoke test에서 scheduler 실행 → status 전환 → badge 부여 → completion API → /me/challenges 반영까지 end-to-end 동작 확인. APScheduler lifespan 등록으로 이전 blocking 해소. spec-keeper 2차: 12건 일치, 0건 불일치. qa-reviewer 2차: 25건 통과, 0건 수정 필요. Spec drift 0건.

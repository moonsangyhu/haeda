# Haeda (해다)

협력형 챌린지 앱 — 참여자 전원이 인증해야 계절 아이콘이 완성되는 달력 기반 동기부여 서비스.
병원 파일럿(4주) 대상 MVP 개발 중. Flutter + FastAPI + PostgreSQL + 카카오 OAuth.

## Source of Truth

모든 구현 판단의 기준은 아래 4개 문서다. 코드와 문서가 충돌하면 문서가 맞다.

- `docs/prd.md` — 기능 목록, P0/P1 범위, 비기능 요구사항, 성공 지표
- `docs/user-flows.md` — 화면 플로우, 화면 구조
- `docs/domain-model.md` — 엔터티, 필드, 제약 조건, 비즈니스 규칙
- `docs/api-contract.md` — REST 엔드포인트, 요청/응답 스키마, 에러 코드

docs/ 파일은 원칙적으로 수정하지 않는다. 수정이 필요하면 사용자 승인 필수.

## MVP Guardrails

- P0 범위만 구현한다. P1(공개 탐색, 푸시 알림, Apple 로그인)과 MVP 제외 기능은 만들지 않는다.
- PRD에 없는 엔터티, 엔드포인트, 화면을 임의로 추가하지 않는다.
- `docs/prd.md` §9 Open Questions에 해당하는 결정이 필요하면 구현 전에 사용자에게 확인한다.

## Implementation Rules

- **용어**: 코드의 클래스명, 변수명, API 경로는 docs의 영문 용어를 따른다 (Challenge, Verification, DayCompletion, ChallengeMember, Comment).
- **API 계약**: 경로, 필드명, 타입, 에러 코드는 `api-contract.md`를 그대로 구현한다. 응답은 `{"data": ...}` / `{"error": {"code": "...", "message": "..."}}` envelope을 사용한다.
- **Flutter**: feature-first 구조, Riverpod, GoRouter, dio. 상세 규칙은 `.claude/skills/flutter-mvp/`.
- **FastAPI**: SQLAlchemy 2.0 async, Pydantic v2, Alembic. 상세 규칙은 `.claude/skills/fastapi-mvp/`.
- **계절 아이콘**: 3~5월 spring, 6~8월 summer, 9~11월 fall, 12~2월 winter.
- **경로별 규칙**: server/ 작업 시 `.claude/rules/server-guard.md`, app/ 작업 시 `.claude/rules/app-guard.md`가 자동 로딩된다.

## Workflow Rules

수직 슬라이스 개발 흐름:

1. **계획 (Plan-first)**: Shift+Tab으로 Plan Mode 진입 후 `/slice-planning {슬라이스명}` 실행. 계획이 승인될 때까지 구현하지 않는다.
2. **스펙 검증**: `spec-keeper` 에이전트로 계획의 스펙 정합성 확인. P0 범위·엔터티·에러코드 불일치 시 구현 진입 금지.
3. **구현**: `backend-builder`로 API 구현 → `flutter-builder`로 UI 구현. 또는 필요에 따라 직접 구현.
4. **점검**: `/mvp-slice-check {슬라이스명}`으로 완성도 점검. `/docs-drift-check`로 코드↔문서 정합성 확인.
5. **리뷰**: `qa-reviewer` 에이전트로 품질 리뷰.
6. **보완 루프**: QA가 "부분 완료/미완료" 판정 시, 출력된 보완 프롬프트를 해당 탭(backend/frontend)에 붙여넣어 수정 → QA 재검토. "완료"까지 반복. 프롬프트 재생성이 필요하면 `/qa-remediation {슬라이스명}`.
7. **통합 확인**: `/smoke-test`로 로컬 환경에서 전체 스택 동작 확인.
8. **결과 기록**: `/slice-test-report {슬라이스명}`으로 테스트 결과서를 `test-reports/`에 저장. git 커밋 대상.

### 검증 원칙

- **"작동함을 증명해라."** 모든 슬라이스는 실제 테스트 실행 결과로 완료를 판정한다.
- mock 성공, fallback 경로 성공, 빌드만 통과는 "작동 증명"이 아니다.
- pytest/flutter test 출력의 passed/failed 숫자를 인용해야 한다.
- 실제 확인한 것과 미확인 항목을 구분한다. 추정으로 "완료"를 선언하지 않는다.
- smoke test 없이 슬라이스 완료 판정을 내리지 않는다.

### 세션 네이밍

- 슬라이스 작업 시 `claude -n slice-{NN}-{layer}` 형식으로 세션을 시작한다 (예: `claude -n slice-04-backend`).
- 병렬 worktree 작업 시 `claude --worktree slice-{NN} -n slice-{NN}` 형식을 사용한다.
- 세부 규칙은 `docs/worktree-runbook.md` 참조.

기타:
- `.env`, secrets, credentials는 코드에 하드코딩하지 않는다.
- server/ 작업 시 app/ 코드를 건드리지 않는다. 반대도 마찬가지.
- **로컬 환경 (Container-First)**: `docker compose up --build -d`로 전체 스택 기동. `/local`로 동일. `/local stop`으로 중지, `/local status`로 상태 확인, `/local reset`으로 초기화.

## CLAUDE.md 갱신 규칙

이 파일은 프로젝트의 작업 규칙서다. 아래 경우에 갱신한다:

- **반복 실수**: Claude가 같은 실수를 2회 이상 하면, 방지 규칙을 추가한다.
- **새 패턴 확정**: 팀이 새로운 코딩 패턴이나 워크플로를 채택하면 반영한다.
- **규칙 폐기**: 더 이상 유효하지 않은 규칙은 삭제한다. 주석 처리하지 않는다.

갱신하지 않는 것:
- 구현 세부사항 (코드에서 확인 가능한 것)
- 일회성 디버깅 기록 (test-reports/에 남긴다)
- 상세 절차 (skills/ 또는 docs/에 분리한다)

CLAUDE.md는 짧고 강하게 유지한다. 200줄 이하 목표.

## Out of Scope (지금은 하지 않는 것)

CI/CD 파이프라인, 배포 구성, 프로덕션 인프라(K8s), 모니터링 설정.

> **예외**: 로컬 개발용 `docker compose`는 허용. `docker compose up --build`로 전체 스택 기동. 프로덕션 최적화·CI/CD 연동은 범위 밖.

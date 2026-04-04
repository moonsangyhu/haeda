# Haeda (해다)

협력형 챌린지 앱 — 참여자 전원이 인증해야 계절 아이콘이 완성되는 달력 기반 동기부여 서비스.
병원 파일럿(4주) 대상 MVP 개발 중. Flutter + FastAPI + PostgreSQL + 카카오 OAuth.

## Source of Truth

모든 구현 판단의 기준은 아래 4개 문서다. 코드와 문서가 충돌하면 문서가 맞다.

- `docs/prd.md` — 기능 목록, P0/P1 범위, 비기능 요구사항, 성공 지표
- `docs/user-flows.md` — 화면 플로우, 화면 구조
- `docs/domain-model.md` — 엔터티, 필드, 제약 조건, 비즈니스 규칙
- `docs/api-contract.md` — REST 엔드포인트, 요청/응답 스키마, 에러 코드

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

## Workflow Rules

- 작업 시작 전에 관련 docs를 읽고 spec alignment를 확인한다.
- 불확실하면 `spec-keeper` 에이전트로 검토한다.
- 수직 슬라이스 완료 시 `mvp-slice-check` 스킬로 점검한다.
- `.env`, secrets, credentials는 코드에 하드코딩하지 않는다.

## Out of Scope (지금은 하지 않는 것)

hooks 설정, CI/CD 파이프라인, 배포 구성, 인프라(Docker/K8s), 모니터링 설정.

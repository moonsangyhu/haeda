# Language Policy

사용자는 한국어로 명령한다. **모든 산출물·외부 표현은 한국어로 작성**한다. 내부 작업(tool call, shell 명령, 경로, 영문 파일명, reasoning) 은 영어 허용.

## 한국어 필수

- `docs/superpowers/specs/`, `docs/superpowers/plans/`, `docs/reports/`, `docs/design/`, `docs/planning/` 의 신규 산출물
- AI 가 생성하는 모든 보고서·요약·분석·plan 문서
- Commit 메시지 (conventional commits scope 는 영어: `feat(claude): ...`)
- PR 제목·본문
- 사용자에게 보내는 채팅 응답·질문·완료 보고

## 영어 유지

- `docs/ARCHIVE/**`, `.claude/skills/ARCHIVE/**`, `.claude/agents/ARCHIVE/**`, `.claude/rules/ARCHIVE/**` — 폐기 자료. 번역 금지.
- superpowers 플러그인 파일 (`~/.claude/plugins/cache/claude-plugins-official/`)
- 코드 식별자 (클래스 · 함수 · 변수 · API 경로 · DB 테이블) — `coding-style.md` 참조
- 에러 코드 `UPPER_SNAKE_CASE` (사용자에게 노출되는 `message` 는 한국어)
- upstream 도구 / superpowers 가 참조하는 핵심 섹션 헤더 (예: `# Implementation Plan`)

## 위반 시

산출물이 영어로 작성된 경우 즉시 멈추고 한국어로 재작성. 사용자가 명시적으로 영어를 요청한 경우만 예외.

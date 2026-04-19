# 디자인 문서 구현 상태 강제 추적 도입

| 항목 | 값 |
|------|---|
| Date | 2026-04-19 |
| Worktree (수행) | `.claude/worktrees/claude` (worktree-claude) |
| Worktree (영향) | `.claude/worktrees/{design,feature,front,backend}` — 새 hook + skill 적용 |
| Role | claude |

## Request

> 앞으로 디자인 워크트리에서 기획 문서 작성할때 아직 구현 안했다는거 표시하고, 피쳐 워크트리에서 구현 완료 했으면 마지막에 구현 완료 표시하도록 강제해줘. 그 이유는 피쳐 워크트리에서 '구현 안된 기획문서 찾아서 구현해줘' 라고만 명령하면 바로 쉽게 찾아서 구현하도록 하기 위해서야.

## Root cause / Context

기존 디자인 워크트리는 `docs/design/<slug>.md` 에 디자인 스펙을 기록하지만 `status` 필드가 선택적이었다 (`.claude/rules/design-worktree.md` 의 표현이 "front worktree **may** update status to implemented"). 그 결과:

1. 피쳐 워크트리에서 "아직 구현 안 된 디자인" 을 신뢰성 있게 스캔할 방법이 없었다.
2. 구현 완료 후 상태를 옮기는 절차가 강제되지 않아 추적이 끊겼다.

기획(planning) 쪽은 이미 `/implement-planned` 스킬로 `ready` → `in-progress` → `done + archive` 패턴을 갖고 있어, 디자인을 같은 패턴에 맞추되 **archive 이동은 생략**하기로 했다 (디자인 스펙은 구현 후에도 유지보수 참조 자료이기 때문).

## Actions

claude role 워크트리에서 다음을 수행했다.

### 1. 새 PreToolUse hook 추가

- `.claude/hooks/design-status-guard.sh` (Python 스크립트, 실행권한 부여)
  - `docs/design/(specs|drafts)/*.md` 에 대한 Write/Edit 만 검증
  - 5개 허용 status 값: `draft | ready | in-progress | implemented | dropped`
  - `.design-worktree` sentinel 존재 시 `in-progress`·`implemented` 쓰기 차단
  - `TEMPLATE-*.md` 는 검증 예외

### 2. 새 디스커버리 스킬 추가

- `.claude/skills/implement-design/SKILL.md`
  - 피쳐 워크트리에서 `docs/design/specs/*.md` 의 `status: ready` 를 발견
  - 원자적 lock: `ready → in-progress` flip + PR 머지
  - `Skill(feature-flow, ...)` 로 9-step 파이프라인 호출
  - 성공 시 `in-progress → implemented` flip + PR 머지 (archive 이동 없음)
  - 실패 시 `in-progress` 유지 (재시도 시 lock 으로 작동)
  - 트리거 한국어 키워드: "구현 안 된 디자인 찾아서 구현해줘", "디자인 문서 구현해줘"

### 3. 기존 파일 수정

- `.claude/settings.json` — PreToolUse 훅 체인에 `design-status-guard.sh` 등록 (`design-guard.sh` 직후, `docs-guard.sh` 직전)
- `.claude/rules/design-worktree.md` — "Status is Mandatory" 섹션 추가, lifecycle 다이어그램 갱신 (`done` → `implemented`, archive 경로 제거), Handoff 섹션에 `/implement-design` 절차 명시, Related Files 갱신

### 4. 디렉토리 구조 정리

- `docs/design/specs/`, `docs/design/drafts/` 디렉토리 생성
- 기존 4개 디자인 스펙을 `docs/design/<name>.md` → `docs/design/specs/<name>.md` 로 `git mv`:
  - challenge-room-social.md
  - challenge-room-speech.md
  - miniroom-cyworld.md
  - room-decoration.md
- 4개 모두 기존 `status: ready` 유지 (= 아직 구현 안 됨, `/implement-design` 의 발견 대상)

### 5. README 신규 작성

- `docs/design/README.md` — 디렉토리 구조, status 어휘 표, 라이프사이클 다이어그램, 워크트리별 권한 표

## Verification

### Hook smoke test (12 시나리오 통과)

`design-status-guard.sh` 를 stdin JSON 입력으로 직접 호출해 검증.

| # | 입력 | 기대 | 결과 |
|---|------|------|------|
| 1 | Write `status: ready`, no sentinel | exit 0 | ✅ |
| 2 | Write `status: implemented`, no sentinel | exit 0 | ✅ |
| 3 | Write `status: wip` | exit 2 + invalid 메시지 | ✅ |
| 4 | Write 누락된 status | exit 2 + missing 메시지 | ✅ |
| 5 | Write `TEMPLATE-FOO.md` (front-matter 없음) | exit 0 (skip) | ✅ |
| 6 | Write `docs/planning/...` | exit 0 (path 무관) | ✅ |
| 7 | Write `status: in-progress`, sentinel 있음 | exit 2 + design-only 메시지 | ✅ |
| 8 | Write `status: implemented`, sentinel 있음 | exit 2 | ✅ |
| 9 | Write `status: draft`, sentinel 있음 | exit 0 | ✅ |
| 10 | Write `status: ready`, sentinel 있음 | exit 0 | ✅ |
| 11 | Edit `ready → implemented`, no sentinel | exit 0 | ✅ |
| 12 | Edit `ready → implemented`, sentinel 있음 | exit 2 | ✅ |

### 구조 확인

- `docs/design/` 루트는 `README.md`, `drafts/`, `specs/` 만 남음 (4개 .md 파일은 specs/ 로 이동)
- `docs/design/specs/` 안에 4개 스펙 모두 존재, `status: ready` 유지
- 새 hook 이 `.claude/settings.json` PreToolUse 체인에 등록됨

### 사용자 확인 필요

- iOS 시뮬레이터·docker 빌드 검증은 코드(app/ server/) 변경 없으므로 비대상.
- 디자인 워크트리·피쳐 워크트리 기존 세션이 있다면 **재시작 필요** — `.claude/rules/claude-config-sync.md` §4.

## Follow-ups

- 디자인 워크트리·피쳐 워크트리 기존 Claude Code 세션은 재시작 후 새 hook + 새 스킬 트리거가 완전히 적용된다 (rule/agent/skill 캐시 갱신).
- `implement-planned` 스킬은 `git push origin HEAD:main` 직접 푸시 패턴을 쓰고 있어 현재 PR-based push 규칙(`worktree-parallel.md`)과 어긋난다. `implement-design` 은 처음부터 PR-based 로 작성. `implement-planned` 도 추후 동일 패턴으로 마이그레이션 필요 (이 작업의 범위 외, 별도 follow-up).
- `TEMPLATE-*.md` 는 현재 git tracked 가 아님 (Explore 단계에서 main 워크트리의 untracked 파일을 본 것이 혼동을 줬음). 향후 정식 템플릿이 필요하면 별도 작업으로 추가.
- 첫 실전 사용 시: 피쳐 워크트리에서 `/implement-design miniroom-cyworld` 한 번 돌려서 락 → feature-flow → implemented flip 까지 end-to-end 동작을 한 번 더 확인하면 좋다.

## Related

- Plan: `~/.claude/plans/linear-doodling-parasol.md`
- 거울 스킬: `.claude/skills/implement-planned/SKILL.md`
- 워크트리 매트릭스: `.claude/rules/worktree-parallel.md`
- Config 동기화 규칙: `.claude/rules/claude-config-sync.md`
- 작업 보고서 의무: `.claude/rules/worktree-task-report.md`

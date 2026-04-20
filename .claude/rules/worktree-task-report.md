# Worktree Task Report Rule (MANDATORY)

모든 워크트리에서 수행되는 **작업 단위마다** git-tracked 보고 문서를 반드시 남긴다. git 히스토리만으로 "어느 워크트리에서 무슨 작업이 있었는지" 추적 가능해야 한다는 사용자 요구(2026-04-11)에 따른다. 이 규칙은 `.claude/rules/agents.md` 의 에이전트 파이프라인과 `.claude/rules/workflow.md` 의 10-step slice flow 와 동등한 강제력을 갖는다.

본 규칙은 **작성 의무** 를 정의한다. 짝이 되는 **참고 의무 (Read-before-Write)** 는 `.claude/rules/regression-prevention.md` 에 정의되어 있다. 두 규칙은 항상 쌍으로 동작한다: 작업 시작 전 과거 보고서를 반드시 참고하고, 작업 종료 후 새 보고서를 반드시 남긴다.

## 참고 의무 (요약)

상태 변경 작업을 시작하는 에이전트는 **첫 단계**로 `docs/reports/` 를 최소 3개 키워드(기능명 / 파일 경로 / 엔티티명) 로 Grep 해 관련 보고서를 읽고, Feature Plan / builder completion output 의 `### Referenced Reports` 섹션에 인용해야 한다. 세부 조항·강제력·예외는 `.claude/rules/regression-prevention.md` 참고.

## 적용 범위

모든 **상태를 바꾸는 작업**이 대상이다. 다음을 포함하되 이에 한정하지 않는다:

- feature / fix / refactor / test / chore / style / docs 중 하나라도 해당되는 작업
- config 변경 (`.claude/`, `CLAUDE.md`, `settings.json`, hooks, rules, skills, agents)
- 워크트리 rebase·stash 등으로 인한 상태 변화가 발생한 경우
- 빌드·배포·로컬 환경만 건드리는 작업이라도 사용자가 "작업"으로 인식할 만한 단위라면 포함

읽기 전용 탐색 / 디버깅만 하고 아무 상태도 바꾸지 않은 경우는 제외한다.

## 파일 규약

- **경로**: `docs/reports/YYYY-MM-DD-{role}-{slug}.md`
- **role**: 작업을 수행한 워크트리의 역할. `backend | front | qa | claude` 중 하나. (역할 표는 `.claude/rules/worktree-parallel.md` 참고)
- **slug**: 소문자 하이픈, 40자 이내. 기능·버그·주제 요약.
- 한 작업에 여러 워크트리가 영향받으면 파일명은 수행 워크트리의 role 로 고정하고, 본문 헤더에 영향 받은 워크트리 목록을 명시한다.
- 규약은 `.claude/rules/worktree-parallel.md` 의 Shared Directories 규약을 그대로 따르므로 두 워크트리가 동시 작업해도 파일 충돌은 일어나지 않는다.

## 본문 최소 섹션

아래 섹션은 모두 필수다. 비워두지 말 것.

1. **헤더** — Date / Worktree (수행) / Worktree (영향) / Role
2. **Request** — 사용자 요청 또는 트리거 원문 요약
3. **Root cause / Context** — 왜 이 작업이 필요했는지
4. **Actions** — 실제로 수행한 일. 가능한 커밋 해시·파일 경로·명령어를 인용
5. **Verification** — 테스트·빌드·수동 확인 결과. 사용자 확인 필요한 항목은 명시
6. **Follow-ups** — 남은 TODO / 재발 방지 / 의도적으로 유예한 사항
7. **Related** — 참고한 plan, impl-log, 커밋, 다른 reports 링크

## 생성 주체 & 타이밍

| 상황 | 작성 주체 | 타이밍 |
|------|----------|--------|
| feature-flow / fix-flow 정식 파이프라인 | `doc-writer` 에이전트 | Step 7 (deploy 직후) |
| 에이전트를 거치지 않은 직접 수정, config 변경, 워크트리 정비 | Main (Opus) 가 직접 | 작업 완료 직후, commit 전 |

두 경우 모두 **commit 전**에 문서가 존재해야 한다. 문서 없이 커밋하려 시도하면 규칙 위반이다.

## 강제력

- `doc-writer` 에이전트는 이 규칙을 읽고 있다고 가정하며, 파일명·섹션을 누락한 경우 Main 이 재호출해 보완시킨다.
- Main (Opus) 이 `/commit` skill 을 호출하기 전 체크리스트에 "해당 작업에 대응하는 `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 가 존재하는가?" 를 반드시 포함한다. 없으면 작성 후 커밋.
- `code-reviewer` / `qa-reviewer` 는 read-only 이므로 보고서를 작성하지 않지만, 검토 대상에 보고서가 포함되어 있지 않으면 가벼운 경고를 남길 수 있다.
- 이 규칙 위반은 `.claude/rules/workflow.md` 의 Document (Step 7) 게이트 실패와 동등하게 취급된다. → STOP, 보고 후 보완.

## 중복 방지

- `doc-writer` 가 이미 작성한 경우 Main 은 같은 슬러그로 덮어쓰지 않는다.
- 한 작업이 커밋 여러 개로 분할되어도 기본은 보고서 1건. 성격이 다른 후속 작업이 시작되면 새 보고서를 만든다.

## Do / Don't

✅ config-only 변경, rebase-only 작업, hook 수정도 보고서를 남긴다.
✅ 영향 받은 모든 워크트리를 헤더에 나열한다.
✅ 커밋 해시·파일 경로를 본문에 인라인으로 인용한다.

❌ "docs 만 수정했으니 skip" 금지.
❌ `impl-log/` 나 `test-reports/` 만 쓰고 `docs/reports/` 를 생략하지 말 것. 세 개는 상호보완이다.
❌ 보고서 없이 `/commit` 실행 금지.

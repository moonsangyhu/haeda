# design-guard / planner-guard 에 docs/reports/ 예외 추가

- Date: 2026-04-20
- Worktree (수행): `.claude/worktrees/claude` (branch: `worktree-claude`)
- Worktree (영향): design / planner 워크트리 — 작업 결과서 작성 가능해짐
- Role: claude

## Request

> 워크트리들에서 레포트 쓰면 디자인 가드가 차단해버려. 이 증상 수정해줘

## Referenced Reports (Read-before-Write)

- `docs/reports/2026-04-19-claude-docs-guard-relaxation.md` — 유사 유형의 이전 선례. `docs-guard.sh` 가 `docs/reports/`, `docs/planning/`, `docs/design/` 외의 docs 파일을 차단했던 문제를 동일한 방식(화이트리스트 확장)으로 해결한 기록. 본 수정도 같은 패턴을 차용.
- `docs/reports/2026-04-20-claude-regression-prevention-rule.md` — 본 세션 바로 앞 작업. 모든 워크트리(design/planner 포함)가 `docs/reports/` 에 작업 결과서를 쓰도록 강제하는 규칙을 도입했으나, guard hook 수정은 누락되어 있었음. 본 수정이 그 누락을 메꾼다.
- `docs/reports/2026-04-19-claude-design-status-enforce.md` — design worktree 의 status 필드 강제 hook 도입. 본 hook 로직 구조 참고.

검색 키워드: `design-guard`, `planner-guard`, `docs/reports`, `hook`, `worktree-task-report`

## Root cause / Context

`regression-prevention.md` + `worktree-task-report.md` 는 **모든 워크트리**(design, planner 포함)에 작업 단위마다 `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 보고서 작성을 의무화한다. 그러나 `design-guard.sh` 와 `planner-guard.sh` 는 각각 `docs/design/**`, `docs/planning/**` 외의 **모든** 경로를 `exit 2` 로 차단하고 있었기 때문에, 해당 워크트리에서 `worktree-task-report.md` 의무 수행이 불가능했다.

이는 설계 모순이 아니라 단순 누락이다 — `worktree-parallel.md` §Shared Directories 는 `docs/reports/` 를 `Written by doc-writer` 로 any-role 공유 디렉터리로 정의하고 있으나, guard hook 들이 이 공유 디렉터리 예외를 구현하지 않았다.

## Actions

### 수정한 파일

- `.claude/hooks/design-guard.sh`
  - 기존: `if [[ "$REL_PATH" == docs/design/* ]]; then exit 0; fi`
  - 변경: OR 조건으로 `docs/reports/*` 추가 → `if [[ "$REL_PATH" == docs/design/* ]] || [[ "$REL_PATH" == docs/reports/* ]]; then exit 0; fi`
  - 차단 메시지도 "task reports in docs/reports/** also allowed" 안내 추가

- `.claude/hooks/planner-guard.sh`
  - 동일 패턴으로 `docs/reports/*` 허용 추가

- `.claude/rules/design-worktree.md`
  - 경로 표에서 `docs/reports/**` 를 "no" → "yes" 로 분리하여 명시. `impl-log/**`, `test-reports/**` 는 "no" 유지.

- `.claude/rules/planner-worktree.md`
  - 동일하게 `docs/reports/**` 행 분리 + "yes" + filename 규약 안내.

- `.claude/rules/worktree-task-report.md`
  - role 허용 목록을 `backend | front | qa | claude` → `feature | backend | front | qa | claude | design | planner` 로 확장.

- `.claude/rules/worktree-parallel.md`
  - Shared Directories 아래 `{role}` 값 허용 목록에 `design`, `planner` 추가. (`feature`, `backend`, `front`, `qa`, `claude`, `design`, `planner`)

### 건드리지 않은 파일

- `.claude/hooks/docs-guard.sh` — 이미 2026-04-19 에 완화됨. 추가 수정 불필요.
- `worktree-parallel.md` §Role Contract 의 hard-boundary 표 — `docs/reports/` 는 Shared Directories 로 이미 any-role writable 로 정의되어 있으므로 hard-boundary 에 추가하면 중복·혼동. 현 구조 유지.
- `regression-prevention.md` — 규칙 자체는 정상, guard hook 만 문제였음. 변경 없음.

## Verification

Hook 자체 동작을 격리된 임시 디렉터리에서 PreToolUse JSON 포맷으로 직접 실행.

```bash
# design-guard: docs/reports/ 경로 허용
$ mkdir -p /tmp/fake-design-wt && touch /tmp/fake-design-wt/.design-worktree
$ CLAUDE_PROJECT_DIR=/tmp/fake-design-wt bash .claude/hooks/design-guard.sh <<< \
    '{"tool_input":{"file_path":"/tmp/fake-design-wt/docs/reports/2026-04-20-design-foo.md"}}'
$ echo "exit=$?"
exit=0   # PASS — allowed

# design-guard: 다른 경로 여전히 차단
$ CLAUDE_PROJECT_DIR=/tmp/fake-design-wt bash .claude/hooks/design-guard.sh <<< \
    '{"tool_input":{"file_path":"/tmp/fake-design-wt/app/lib/main.dart"}}'
BLOCKED: design worktree may only edit docs/design/** (task reports in docs/reports/** also allowed)
File: app/lib/main.dart
...
exit=2   # PASS — still blocked

# planner-guard: docs/reports/ 경로 허용
$ mkdir -p /tmp/fake-planner-wt && touch /tmp/fake-planner-wt/.planner-worktree
$ CLAUDE_PROJECT_DIR=/tmp/fake-planner-wt bash .claude/hooks/planner-guard.sh <<< \
    '{"tool_input":{"file_path":"/tmp/fake-planner-wt/docs/reports/2026-04-20-planner-foo.md"}}'
$ echo "exit=$?"
exit=0   # PASS — allowed

# planner-guard: 다른 경로 여전히 차단
$ CLAUDE_PROJECT_DIR=/tmp/fake-planner-wt bash .claude/hooks/planner-guard.sh <<< \
    '{"tool_input":{"file_path":"/tmp/fake-planner-wt/server/main.py"}}'
BLOCKED: planner worktree may only edit docs/planning/** (task reports in docs/reports/** also allowed)
File: server/main.py
...
exit=2   # PASS — still blocked
```

4개 케이스(2 hook × {allowed, blocked}) 모두 기대한 exit code 반환. 보호 경계는 유지되면서 `docs/reports/` 만 정확히 열림.

## Follow-ups

- 다른 워크트리(design, planner)의 **기존 세션**은 hook 이 파일 시스템에서 새로 읽히므로 재시작 없이도 다음 tool 호출부터 적용됨. 단 rule 내부 텍스트(예: 허용 경로 표)는 Claude Code 내부 캐시에 따라 세션 재시작이 필요할 수 있음 (`claude-config-sync.md`).
- 만약 향후 design/planner 워크트리에서 `impl-log/` 나 `test-reports/` 까지 써야 하는 상황이 생기면 같은 패턴으로 hook 확장. 현 시점에서는 두 워크트리가 builder/qa 역할이 아니므로 필요 없다고 판단해 보류.

## Related

- 선례: `docs/reports/2026-04-19-claude-docs-guard-relaxation.md`
- 짝 규칙 도입: `docs/reports/2026-04-20-claude-regression-prevention-rule.md`
- 변경 파일:
  - `.claude/hooks/design-guard.sh`
  - `.claude/hooks/planner-guard.sh`
  - `.claude/rules/design-worktree.md`
  - `.claude/rules/planner-worktree.md`
  - `.claude/rules/worktree-task-report.md`
  - `.claude/rules/worktree-parallel.md`

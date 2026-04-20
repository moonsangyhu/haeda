# Claude Config Sync Rule (MANDATORY)

`.claude/**` 와 `CLAUDE.md` 에 대한 수정(rules, agents, skills, hooks, settings, slash commands, plugins 포함)은 `claude` 역할 워크트리에서만 이루어진다. 이 변경은 다른 워크트리에 **세션 시작 시점 즉시** 반영되어야 하며, 기존 세션에도 **다음 작업 단위 시작 전** 반드시 반영되어야 한다. 본 규칙은 그 전파 계약을 강제한다.

본 규칙은 `.claude/rules/worktree-parallel.md` 의 startup ritual 을 구체화·강화하는 상위 규칙이다.

## 원칙

1. `.claude/**` 와 `CLAUDE.md` 는 **claude role** 워크트리에서만 편집 가능. (role contract: `worktree-parallel.md`)
2. claude role 에서 해당 경로를 수정하면 **즉시** PR 생성 + 자동 머지로 `origin/main` 에 반영한다. 다른 작업과 배치(batch)로 묶어 지연시키지 않는다.
3. 다른 모든 role (`backend`, `front`, `qa`) 은 새 작업 단위를 시작할 때마다 **반드시** `git fetch origin main && git rebase origin/main` 을 먼저 실행한다.
4. 장기 세션(여러 작업을 연속 수행하는 claude 세션)은 각 작업 시작 전에 상기 sync 체크를 다시 실행한다. 세션 시작 시 한 번 실행했다는 이유로 생략 불가.

## 1. claude role 의 즉시 push 의무

claude 워크트리가 아래 경로 중 하나라도 건드리면 그 자체만으로 커밋·푸시 대상이 된다. 다른 작업과 합쳐 나중에 푸시하지 않는다.

- `.claude/rules/**`
- `.claude/agents/**`
- `.claude/skills/**`
- `.claude/hooks/**`
- `.claude/settings*.json`
- `.claude/commands/**`
- `CLAUDE.md`

푸시 절차는 `worktree-parallel.md` 의 PR-Based Push 를 그대로 따른다. 직접 main push 금지, force 금지.

claude role 이 본 규칙 위반(= 변경을 로컬에 둔 채 다른 작업으로 이동)한 경우, Main 은 즉시 멈추고 사용자에게 보고한다.

## 2. 다른 role 의 sync-before-work 의무

`backend`, `front`, `qa` role 워크트리에서 진행되는 모든 에이전트 파이프라인의 **첫 번째 단계** 는 아래와 같아야 한다.

```bash
# 1) 현재 role 확인
basename "$(git rev-parse --show-toplevel)"

# 2) 원격 동기화
git fetch origin main
git rebase origin/main   # 실패 시 /resolve-conflict 스킬

# 3) 변경이 있었는지 확인 (정보용)
git log --oneline ORIG_HEAD..HEAD 2>/dev/null | head -20
```

이 단계를 건너뛴 에이전트 작업은 "stale config 상태의 실행" 으로 간주되어 무효다. `spec-keeper`, `backend-builder`, `flutter-builder`, `ui-designer`, `code-reviewer`, `qa-reviewer`, `debugger`, `deployer`, `doc-writer` 모두 첫 단계에서 이 ritual 을 수행해야 한다.

Main 은 에이전트 호출 직전에 "이 워크트리가 방금 sync 되었는가?" 를 확인한다. 미확인 시 먼저 sync 를 지시한다.

## 3. 장기 세션의 중간 sync

한 워크트리에서 여러 작업을 연속 수행하는 세션은 다음 시점마다 sync 를 재실행한다.

- 한 작업의 `/commit` 직후, 다음 작업 시작 전
- 사용자가 새 요청을 제출한 직후, 첫 파일 수정 전
- 30 분 이상 idle 후 재개할 때

sync 결과 새 커밋이 pull 된 경우, 현재 진행 중이던 계획이 영향을 받는지 빠르게 재검토하고, 필요 시 사용자에게 변경 사실을 고지한다.

## 4. 기존 세션에 즉시 전파가 불가능한 경우

`.claude/` 변경은 Claude Code 가 다음 세션을 시작할 때 로드된다. 이미 실행 중인 세션이 있는 다른 워크트리는 파일 시스템상 rebase 후에도 세션 내부의 rule/agent/skill 캐시는 갱신되지 않을 수 있다. 이에 대한 규칙:

- 사용자에게 "다른 워크트리의 기존 세션은 재시작해야 최신 rule 이 완전히 적용됩니다" 를 claude role 의 변경 보고서(`docs/reports/...`) 에 **Follow-ups** 항목으로 반드시 명시한다.
- 기존 세션이 긴급히 최신 rule 을 따라야 하는 경우 (보안/게이트 추가 등), claude role 의 Main 은 해당 사실을 사용자에게 직접 경고한다.

## 4-bis. Agent Roster Drift (신규 에이전트 추가 시)

신규 에이전트 파일 (`.claude/agents/<name>.md` 생성) 은 **특히 위험한 config 변경**이다. Claude Code 는 세션 시작 시점의 파일 시스템을 스캔해 available 에이전트 목록을 고정하기 때문에, 해당 커밋을 포함하지 않은 워크트리에서는 그 에이전트를 **아예 호출할 수 없다** (목록에 존재하지 않음). 이 경우 builder / reviewer 가 workflow.md 에 명시된 단계를 skip 하거나 다른 에이전트에 역할을 결합해 실행하는 우회가 발생한다 (관측 사례: 2026-04-21 — `spec-compliance-reviewer` 가 `worktree-debug` / `worktree-planner` 에서 available 하지 않아 `code-reviewer` 와 결합 수행).

### 추가 규칙 (에이전트 · 스킬 파일 신설 시에만 적용)

1. claude role 의 변경 보고서(`docs/reports/...`) 에 **한 줄 경고 배너**를 최상단 (헤더 다음) 에 고정한다:
   > **ROSTER REFRESH REQUIRED**: 신규 에이전트/스킬 추가. 모든 워크트리 세션을 **재시작** 하여 목록을 다시 로드해야 한다. rebase 만으로는 부족하다.
2. 해당 보고서의 Follow-ups 섹션에 워크트리별 명시적 조치 절차를 기재:
   ```
   # 각 워크트리에서 실행
   cd .claude/worktrees/<role>
   git fetch origin main && git rebase origin/main
   # Claude Code 세션 종료 후 재시작 (Ctrl+D → claude)
   ```
3. 에이전트 신설 커밋 PR 제목에 `[roster]` 태그를 포함해 사용자가 즉시 인지할 수 있게 한다. 예: `feat(claude): [roster] add qa-summary-reviewer 에이전트`
4. 신설된 에이전트를 참조하는 workflow.md / agents.md 조항은 **같은 PR 에서** 업데이트한다. 두 번에 나누어 커밋하면 한 PR 만 머지된 상태에서 mismatch 가 관측된다.

### 주기적 검증 (권장, 강제 아님)

claude role 세션은 주기적으로 아래 명령으로 다른 워크트리 브랜치의 roster 동기 상태를 점검할 수 있다:

```bash
for b in worktree-feature worktree-design worktree-debug worktree-planner worktree-claude; do
  echo "=== $b ==="
  git ls-tree -r $b -- .claude/agents/ | awk '{print $4}'
done
```

한 브랜치가 다른 브랜치들보다 에이전트 파일이 적으면 해당 워크트리를 stale 로 판정하고 사용자에게 재시작 안내.

## 5. 강제력

| 위반 | 결과 |
|------|------|
| claude role 이 `.claude/**` 변경을 즉시 push 하지 않음 | Main 은 다음 작업 착수를 거부하고 사용자에게 보고 |
| 다른 role 이 sync-before-work 없이 에이전트 실행 | 해당 에이전트 출력은 무효, 재실행 요구 |
| 장기 세션이 중간 sync 를 스킵 | `/commit` 직전 체크리스트에서 실패 처리, 보완 후 재시도 |
| claude role 변경 보고서에 "다른 세션 재시작 필요" 경고 누락 | Document 게이트 실패 (`workflow.md` Step 7) |
| 신규 에이전트/스킬 추가 보고서에 ROSTER REFRESH REQUIRED 배너 + 워크트리별 재시작 절차 누락 | Document 게이트 실패. 보고서 재작성 후 재커밋 |

## 관련 규칙

- `.claude/rules/worktree-parallel.md` — role contract, PR-based push, startup ritual 원문
- `.claude/rules/worktree-task-report.md` — 모든 작업의 보고서 의무
- `.claude/rules/workflow.md` — 9-step slice flow 의 게이트 정의
- `.claude/rules/agents.md` — 에이전트별 역할 및 dispatch 규칙

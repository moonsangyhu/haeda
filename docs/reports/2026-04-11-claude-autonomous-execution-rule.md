# Autonomous Execution 규칙 도입

- **Date**: 2026-04-11
- **Worktree (수행)**: `claude`
- **Worktree (영향)**: 모든 워크트리 + Main (Opus) 행동 방식
- **Role**: claude

## Request

> "앞으로 내 의사결정이 필요한 작업 빼고는 모든 워크트리에서 파일 수정같은거는 허락받지 말고 수행하게 해 줘"

## Context

기존 `.claude/settings.json` 는 이미 `defaultMode: acceptEdits` 와 광범위한 Bash allow-list 를 갖고 있어 툴 레벨 permission 은 대부분 자동 통과된다. 그러나 Main (Opus) 이 텍스트 상에서 "이렇게 진행할까요?" 류 확인 질문을 하는 습관이 남아 있어 사용자 체감은 여전히 "허락을 묻는다". 이번 변경은 이 행동을 규칙으로 차단한다.

## Actions

1. **메모리**: `~/.claude/projects/-Users-yumunsang-haeda/memory/feedback_autonomous_execution.md` 생성 + `MEMORY.md` 인덱스에 등록. 이후 모든 claude 세션이 로드.
2. **규칙 파일**: `.claude/rules/autonomous-execution.md` 생성. 금지 문구, 자동 수행 범위, 예외(사용자 결정 필요), 안전 규칙과의 관계, 강제력을 명시.
3. **인덱스**: `CLAUDE.md` Rules 섹션에 새 규칙 등록 (MANDATORY 표시).

설계 포인트:
- 안전 규칙(`security.md`, `docs-protection.md`, `git-workflow.md` force push 금지, worktree role contract, rebase-retry loop) 은 여전히 절대적임을 본문에 명시.
- 사용자 허락이 필요한 예외를 **결정 카테고리** 단위로 표로 정의: 제품 결정 / docs 루트 수정 / 파괴적 DB / 외부 action / trade-off 큰 설계 선택 / force-bypass 플래그.
- "기다리지 말고 다음 턴에 즉시 실행 착수" 를 강제력 표에 포함.

## Verification

```bash
ls .claude/rules/autonomous-execution.md
grep -n autonomous-execution CLAUDE.md
grep -n "Autonomous" .claude/rules/autonomous-execution.md | head -3
```

다음 턴부터의 실제 행동 변화는 사용자가 관찰하며 위반 시 지적 가능. 위반 패턴이 반복되면 해당 문구를 `autonomous-execution.md` 의 "금지 문구" 섹션에 추가해 명시적으로 차단한다.

## Follow-ups / 재발 방지

- **[중요] 다른 세션 재시작 필요**: `backend`, `front`, `qa`, `debug`, `feature` 워크트리에서 이미 돌고 있는 Claude Code 세션이 있다면 한 번 재시작해야 이 규칙이 컨텍스트에 로드된다 (`.claude/rules/claude-config-sync.md` §4 참고).
- 규칙 위반이 관찰되면 `autonomous-execution.md` 에 해당 문구를 추가해 보강한다.
- `.claude/settings.json` 은 추가 수정하지 않는다. 현재 설정이 이미 본 규칙과 정합적이며, `bypassPermissions` 같은 상위 모드는 deny-list 까지 무력화하므로 안전성 손실이 큼.

## Related

- Rule: `.claude/rules/autonomous-execution.md` (신규)
- Memory: `~/.claude/projects/-Users-yumunsang-haeda/memory/feedback_autonomous_execution.md`
- 관련 안전 규칙: `.claude/rules/security.md`, `.claude/rules/git-workflow.md`, `.claude/rules/worktree-parallel.md`
- 같은 세션 선행 보고서: `docs/reports/2026-04-11-claude-worktrees-statusline-fix.md`, `docs/reports/2026-04-11-claude-rules-task-report-and-config-sync.md`

# Regression Prevention Rule 신설

- Date: 2026-04-20
- Worktree (수행): `.claude/worktrees/claude` (branch: `worktree-claude`)
- Worktree (영향): 모든 워크트리 (backend / feature / front / qa / claude) — 에이전트 파이프라인 전체에 적용
- Role: claude

## Request

> 이제부터 구현하는 모든 작업은 작업 결과서를 반드시 남기도록 강제해줘. 그리고 그 폴더는 깃에 올라가지 않도록 해. 그리고 모든 앞으로 기능구현 및 설계는 그 문서를 깊게 참고해서 구현해놓은걸 없애거나 멀쩡한걸 수정하거나 하지 않아야 해.

## Referenced Reports (Read-before-Write)

본 작업은 규칙·에이전트 정의 수정이므로 `docs/reports/` 내 직접적 선행 작업은 없다. 그러나 아래 보고서들을 설계의 근거로 깊게 참고함:

- `docs/reports/2026-04-11-claude-rules-task-report-and-config-sync.md` — `worktree-task-report.md` 와 `claude-config-sync.md` rule 도입 이력. **현 규칙이 이와 짝을 이루는 "참고 의무" 규칙**이며, 해당 보고서의 설계 원칙(작업 단위 트레이서빌리티 / git 공유 knowledge base) 을 유지함.
- `docs/reports/2026-04-12-claude-attention-hook.md` — 과거 주의력 hook 도입 이력. 에이전트 행동 강제 수단의 레이어링(hook vs rule vs 에이전트 phase) 설계 방식 참고.
- git log `45f5418 revert(feature): character-cyworld-style 구현 전체 롤백` — 이 롤백은 본 규칙이 차단하려는 회귀 사고의 대표 사례.

검색 키워드: `docs/reports`, `worktree-task-report`, `regression`, `rollback`, `prior work`

## Root cause / Context

기존 `.claude/rules/worktree-task-report.md` 는 **작업 종료 후 보고서 작성** 을 강제한다. 그러나 **작업 시작 전 과거 보고서를 참고** 하는 규칙은 어디에도 없었다. 그 결과:

- 새 기능이 같은 파일의 기존 구현을 알지 못한 채 덮어쓰는 사고 발생 가능 (`45f5418` 롤백 사례).
- 보고서가 git-tracked 공유 knowledge base 임에도 "쓰기 전용 로그" 로만 쓰여 회귀 방지에 기여하지 못함.

사용자가 본 요구를 제출했고, AskUserQuestion 으로 구체화한 결정:
1. 기존 커밋된 11개 보고서는 그대로 두기
2. 경로 `docs/reports/` 유지 — git-tracked 유지 (공유 knowledge base 역할)
3. 강제 수단: rule 선언 + product-planner 필수 프리스텝

원 발화의 "git 에 안 올라가도록" 조항은 사용자 후속 답변에서 **"참고+작성 강제"에만 집중**으로 교정됨. gitignore 하면 다른 워크트리가 knowledge base 를 참고할 수 없어 목적과 모순.

## Actions

### 신규 파일

- `.claude/rules/regression-prevention.md` — MANDATORY rule. Read-before-Write 의무 + 파괴 금지 원칙 + `### Referenced Reports` 섹션 형식 정의 + 예외 규약.

### 수정 파일

- `.claude/rules/worktree-task-report.md`
  - 도입부에 `regression-prevention.md` 와의 짝 관계 명시 (참고 의무 + 작성 의무)
  - "참고 의무 (요약)" 섹션 신설 (본문 2줄, 세부는 `regression-prevention.md` 로 위임)
  - "9-step slice flow" → "10-step slice flow" 숫자 정정 (기존 rule 간 불일치)

- `.claude/agents/product-planner.md`
  - `### Phase 0: Prior-Work Lookup (MANDATORY)` 섹션 신설 (Phase 1 직전). Grep 명령 + 검색 키워드 최소 3개 규약.
  - Output Format 의 `### Spec References` 다음에 `### Referenced Reports` 섹션 템플릿 추가.

- `.claude/agents/backend-builder.md`
  - `### Phase 0.5: Reports Lookup (MANDATORY — Read-before-Write)` 섹션 추가 (Phase 0 worktree check 직후).
  - Completion Output 템플릿 맨 앞에 `### Referenced Reports (MANDATORY)` 블록 추가.

- `.claude/agents/flutter-builder.md`
  - 동일하게 Phase 0.5 + completion output 블록.

- `.claude/agents/debugger.md`
  - `### Phase 0.5: Reports Lookup` 섹션 추가 (debug 시 과거 fix 를 undo 하지 않도록 — 가장 고위험 에이전트).
  - "prior-debug 보고서 반드시 포함" 강조.
  - Output Format 최상단에 `### Referenced Reports` 블록 추가.

- `.claude/agents/code-reviewer.md`
  - `### 9. Regression Prevention (Blocking)` 섹션 신설.
  - Section presence / Section substance / Destructive change 3단 검증 정의.
  - Blocking issues 목록에 "Missing `### Referenced Reports` section" 추가.

- `.claude/rules/agents.md`
  - `## Dispatch Rules` Planning / Implementation 항목에 "Phase 0/0.5 의무" 인라인 언급.
  - `## Gate Rules Summary` 표에 "Regression Prevention (Step 5 sub-gate)" 행 추가.

- `CLAUDE.md`
  - `## Rules` 섹션에 `regression-prevention.md` 한 줄 추가 (worktree-task-report 바로 아래).

### Verification 명령

```bash
# 모든 예상 파일에 키워드 hit 확인
rg -l "Referenced Reports" .claude/  # 8 files
rg -l "regression-prevention" .claude/ CLAUDE.md  # 8 files
```

### 건드리지 않은 파일

- 기존 11개 커밋된 보고서 파일 — 그대로 유지
- `.gitignore` — 변경 없음 (git-tracked 공유 knowledge base 정책)
- `.claude/hooks/*.sh`, `push-gate.py` — 본 플랜은 rule/agent 레이어에서만 강제, hook 레이어는 수정하지 않음
- `.claude/agents/*.md` 의 `model:` frontmatter — 변경 없음 (Plan=Opus / Implementation=Sonnet 정책 유지)

## Verification

- **Static grep**: `rg -l "Referenced Reports" .claude/` → 8개 파일 hit (규칙 2, 에이전트 5, agents.md). PASS.
- **Cross-reference grep**: `rg -l "regression-prevention" .claude/ CLAUDE.md` → 8개 파일 hit. PASS.
- **Model policy 재검증**: `grep -H "^model:" .claude/agents/*.md` → product-planner=opus, builders/debugger/reviewer=sonnet 유지. PASS.
- **Rule 상호참조 무결성**: `regression-prevention.md` ↔ `worktree-task-report.md` ↔ `agents.md` ↔ `CLAUDE.md` 모두 양방향 참조 확인. PASS.
- **행동 검증 (지연)**: 다음 feature-flow 세션에서 product-planner output 에 `### Referenced Reports` 섹션이 실제로 나타나는지 관찰 필요. 본 세션에서는 규칙/에이전트 정의 층만 변경.

## Follow-ups

- 다른 워크트리의 **기존 세션**은 재시작해야 새 rule/agent 정의가 완전히 로드된다 (`claude-config-sync.md`).
- 첫 번째 feature-flow 실행 시 실제로 에이전트들이 `### Referenced Reports` 섹션을 생성하는지 확인. 누락 시 추가 보강 필요 (skill 경로로 확장).
- `doc-writer.md` 에도 Referenced Reports 전파가 필요한지 후속 검토 — 현재는 builder/debugger 가 생성한 섹션을 그대로 포함해 문서화하면 충분.
- 본 규칙이 `skills/feature-flow` 등 stand-alone skill 에서도 보강되어야 하는지 확인 (현재는 에이전트 정의가 주 강제 지점이므로 불필요할 가능성).

## Related

- Plan file: `/Users/yumunsang/.claude/plans/velvety-imagining-quokka.md`
- 짝이 되는 규칙: `.claude/rules/worktree-task-report.md`
- 회귀 사례: git `45f5418 revert(feature): character-cyworld-style 구현 전체 롤백`
- 선행 규칙 도입 보고서: `docs/reports/2026-04-11-claude-rules-task-report-and-config-sync.md`

# 모델 정책 룰 신설 — Plan=Opus / Implementation=Sonnet

- **Date**: 2026-04-20
- **Worktree (수행)**: `.claude/worktrees/claude` (role: claude)
- **Worktree (영향)**: 모든 워크트리 — 에이전트 호출 시 자동 반영
- **Role**: claude

## Request

> "앞으로 플랜은 opus 로 하고 구현은 sonnet 으로 하도록 프로젝트 룰을 강제해 줘"

역할별 모델 배정을 프로젝트 룰로 명문화하고 실제 에이전트 frontmatter 에도 반영.

## Root cause / Context

기존: 모든 에이전트(`product-planner` 포함) 가 `model: sonnet`. Main thread 만 Opus. 사용자는 **계획 성격의 작업(스펙 생성, 요구사항 해석)** 은 Opus 가 판단 품질이 더 좋고, **정형화된 구현** 은 Sonnet 이 비용·속도 대비 충분하다는 판단. 이 원칙이 어디에도 문서화돼 있지 않아 에이전트 수정 시마다 기준이 흔들릴 수 있음.

## Actions

1. **`.claude/agents/product-planner.md`** frontmatter `model: sonnet` → `model: opus`.
2. **`.claude/rules/model-policy.md`** 신규 생성. 내용:
   - 원칙 표 (Plan → Opus, Implementation → Sonnet)
   - 에이전트별 매핑 표 (10 개 에이전트 각각 분류 + 모델 명시)
   - 강제 방법 4 항목 (frontmatter 단일 진실, Agent 호출 시 model 오버라이드 금지, Main Opus 유지, 신규 에이전트 분류 의무)
   - 자체 확인 체크리스트 bash 스니펫
   - 예외 조항 (사용자 명시 세션 한정)
3. **`.claude/rules/agents.md`** 의 Model 열 업데이트 — `product-planner` 행을 `Opus` 로, 앞에 정책 출처 안내 한 줄 추가.
4. **`CLAUDE.md`** Rules 섹션에 `model-policy.md` 항목 추가 (MANDATORY 표기).

## Verification

자체 체크 스크립트 실행 결과 (`.claude/rules/model-policy.md` §확인 체크리스트):

```
product-planner: opus OK
backend-builder: sonnet OK
flutter-builder: sonnet OK
ui-designer: sonnet OK
debugger: sonnet OK
deployer: sonnet OK
doc-writer: sonnet OK
spec-keeper: sonnet OK
code-reviewer: sonnet OK
qa-reviewer: sonnet OK
```

10 개 에이전트 모두 정책과 일치. 실전 검증은 다음 `/feature-flow` 실행 시 product-planner 호출 로그에서 Opus 가 돌아가는지 확인 (Claude Code CLI 가 frontmatter 의 `model:` 를 존중).

## Follow-ups

- **⚠️ 다른 워크트리의 기존 세션은 재시작해야 신규 rule 및 product-planner Opus 전환이 완전히 적용된다** (`.claude/rules/claude-config-sync.md` §4).
- `debugger` 에이전트는 현재 Sonnet 이지만 cross-layer 버그 진단 품질이 떨어지는 사례가 쌓이면 사용자와 상의해 Opus 승격 검토.
- 새 에이전트가 추가될 때마다 `model-policy.md` 의 매핑 표에 row 를 추가하는 것이 의무 (reject 조건).
- 모델 세대 업그레이드(Opus 4.8, Sonnet 5.0 등) 시 `model-policy.md` 갱신.

## Related

- 이전 작업 보고서 (같은 날): `docs/reports/2026-04-20-claude-design-handoff-feature.md`
- `.claude/rules/agents.md` — 에이전트별 역할 표
- `.claude/rules/claude-config-sync.md` — claude role 변경 즉시 push 규칙
- `.claude/rules/autonomous-execution.md` — 허락 없이 실행

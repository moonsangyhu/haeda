# Model Policy (MANDATORY)

이 프로젝트는 **역할별 모델 배정**을 강제한다. 계획(plan)에는 Opus, 구현(implementation)에는 Sonnet 을 사용한다. 복잡한 설계 판단·스펙 해석은 Opus 가, 정형화된 코드 작성·테스트·빌드·배포는 Sonnet 이 담당한다.

## 원칙

| 단계 | 모델 | 이유 |
|------|------|------|
| Plan / 설계 | **Opus** | 요구사항 해석, trade-off 판단, 다중 문서 교차 참조, 엣지 케이스 예측이 필요 |
| Implementation / 구현 | **Sonnet** | 정해진 스펙·rule 을 따라 반복 가능하게 코드·테스트·빌드를 수행. 속도·비용 대비 품질이 충분 |

## 역할 ↔ 모델 매핑 (강제)

| 역할 | 분류 | 모델 | 비고 |
|------|------|------|------|
| **Main thread (Opus)** | Orchestration + plan mode | Opus | 사용자 요구 파싱, 에이전트 orchestration, `/commit`. Claude Code harness 가 Opus 세션으로 기동. |
| `product-planner` | Plan | **Opus** | feature spec 생성 (plan-feature, slice-planning 도 동일 성격). `.claude/agents/product-planner.md` frontmatter 에 `model: opus` 강제. |
| `Plan` (built-in subagent) | Plan | Opus 상속 | Main(Opus) 에서 호출 시 parent 모델 상속. 명시적 오버라이드 금지. |
| `backend-builder` | Implementation | Sonnet | `model: sonnet` 강제 |
| `flutter-builder` | Implementation | Sonnet | `model: sonnet` 강제 |
| `ui-designer` | Implementation | Sonnet | `model: sonnet` 강제 |
| `debugger` | Implementation (fix 수행) | Sonnet | 분석/설계 비중은 있으나 최종적으로 코드 수정·재현·검증을 수행하므로 Sonnet. 복잡도가 예외적으로 높은 cross-layer 버그는 Main 이 Opus 로 직접 설계 후 debugger 에게 패치 실행만 맡긴다. |
| `deployer` | Implementation (배포) | Sonnet | |
| `doc-writer` | Implementation (문서화) | Sonnet | |
| `spec-keeper` | Review/Verification | Sonnet | plan 이 아닌 검증 역할 |
| `code-reviewer` | Review | Sonnet | |
| `qa-reviewer` | Review | Sonnet | |

## 강제 방법

1. **에이전트 frontmatter**: `.claude/agents/<name>.md` 의 `model:` 필드가 단일 진실 원천. Plan 역할은 `opus`, 그 외는 `sonnet` 으로 고정.
2. **Agent 호출 시 `model` 파라미터 사용 금지**: Main 이 `Agent(subagent_type=X, model=Y)` 로 모델을 오버라이드하지 않는다. frontmatter 가 결정한다. 예외적으로 Main 이 Opus 수준 설계를 추가로 요구하는 경우는 Main 에서 직접 사고하고 에이전트에게는 구현만 위임한다.
3. **Main thread 는 Opus 유지**: `/opus`, `/sonnet` slash command 로 Main 을 다운그레이드하지 않는다 (사용자 명시 지시 시 예외).
4. **신규 에이전트 추가 시**: 먼저 역할 분류(plan/implementation/review/deploy/docs) 를 결정하고 본 표에 row 를 추가한 뒤, 그 분류에 맞는 모델을 frontmatter 에 기재한다. 분류 없는 신규 에이전트는 PR 에서 reject.

## 확인 체크리스트

claude role 워크트리에서 에이전트나 룰을 건드린 PR 은 다음을 통과해야 한다:

```bash
# product-planner 는 opus 여야 함
grep -q "^model: opus$" .claude/agents/product-planner.md

# 나머지 에이전트는 sonnet 이어야 함
for f in backend-builder flutter-builder ui-designer debugger deployer doc-writer spec-keeper code-reviewer qa-reviewer; do
  grep -q "^model: sonnet$" ".claude/agents/$f.md" || { echo "FAIL: $f"; exit 1; }
done
echo "model policy OK"
```

## 예외

- 사용자가 세션 내에서 "이번은 sonnet 으로 플랜 해봐" 같이 한정적 예외를 명시하면 그 세션 한정으로 허용. 프로젝트 룰 변경은 아님.
- 새 모델 세대가 나올 때(예: Opus 4.8, Sonnet 5.0) 사용자와 합의 후 본 문서를 갱신한다.

## 관련 규칙

- `.claude/rules/agents.md` — 에이전트별 역할 표 (본 문서와 동기화 유지)
- `.claude/rules/workflow.md` — 9-step slice flow (각 step 의 모델 요구)
- `.claude/rules/claude-config-sync.md` — 본 룰 변경은 claude role 에서 즉시 push

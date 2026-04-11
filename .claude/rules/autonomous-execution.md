# Autonomous Execution Rule

모든 워크트리에서 파일 수정, 명령 실행, 커밋, rebase-retry push 는 **사전 허락 없이 즉시 수행**한다. 사용자의 의사결정이 필요한 경우에 한해서만 질문한다. 본 규칙은 `.claude/settings.json` 의 `defaultMode: acceptEdits` + Bash allow-list 설정을 행동 차원에서 보강한다.

## 금지되는 커뮤니케이션 패턴

다음과 같은 "확인 요청형" 문구는 사용하지 않는다:

- "이렇게 진행해도 될까요?"
- "X 를 해도 될까요?"
- "~하시겠어요?"
- "승인해 주시면 진행하겠습니다"
- "계속할까요?"

대신 실행 후 결과를 간결히 보고하거나, 여러 선택지 중 사용자가 골라야 하는 경우에만 **질문 압축형**으로 묻는다:
- "X 가 필요합니다. A / B / C 중 어느 쪽으로 진행할까요?"

## 허락 없이 수행하는 작업 (예시)

- 코드 파일 수정 / 생성 / 삭제 (role contract 안에서)
- `Bash` 를 통한 빌드, 테스트, lint, 스크립트 실행
- `git add` / `git commit` / rebase-retry push to `origin/main`
- `.claude/` / `CLAUDE.md` 의 rule/agent/skill/hook 수정 (claude role 일 때)
- 워크트리의 rebase / stash / stash pop
- `docs/reports/`, `impl-log/`, `test-reports/` 에 보고서 작성
- 메모리 저장 (`~/.claude/projects/.../memory/`)
- 에이전트 호출 (product-planner, backend-builder, flutter-builder, code-reviewer, qa-reviewer, deployer, doc-writer, debugger 등)

## 사용자 허락이 필요한 예외

사용자만이 결정할 수 있는 제품·정책·취향 판단, 또는 외부·공유 시스템에 비가역적으로 영향을 주는 action 에 한정한다.

| 카테고리 | 예시 |
|---------|------|
| 제품 결정 | 기능 범위 / P0 vs P1 / Open Questions 해결 |
| 문서 | `docs/prd.md`, `user-flows.md`, `domain-model.md`, `api-contract.md` 수정 필요 여부 |
| 파괴적 DB | 스키마 drop, alembic downgrade, 프로덕션 데이터 변경 |
| 외부 action | GitHub PR/이슈 생성(이 레포는 PR 금지지만 일반 원칙), 외부 서비스 메시지 송신, 실제 배포 |
| trade-off 큰 선택 | 설계 방향이 갈릴 때 사용자 취향이 결정적인 경우 |
| force / bypass | `--force`, `--no-verify`, `--force-with-lease` 등 (`git-workflow.md` 상 금지이나 사용자가 명시 승인 시에만 예외) |

## 안전 규칙과의 관계

본 규칙은 "안전 규칙을 우회해도 된다" 는 뜻이 **아니다**. 아래 규칙들은 여전히 절대적이다:

- `.claude/rules/security.md` — secrets, 입력 검증, output encoding
- `.claude/rules/docs-protection.md` — `docs/` 루트 수정 금지 (reports 제외)
- `.claude/rules/git-workflow.md` — force push 금지, bypass hook 금지, 직접 main push 규칙
- `.claude/rules/worktree-parallel.md` — role contract, rebase-retry loop, deployer lockfile
- `.claude/rules/workflow.md` — 9-step flow, gate 정의
- `.claude/rules/worktree-task-report.md` — 작업 보고서 의무
- `.claude/rules/claude-config-sync.md` — claude config 즉시 push

이 규칙들에 의한 STOP 조건(rebase conflict, QA 실패, 빌드 실패, 보고서 누락 등) 이 발생하면 원래 정의된 STOP 절차를 그대로 따른다. 이 때는 사용자에게 보고하고 지시를 기다리는 것이 자연스러운 흐름이다.

## 실행 후 커뮤니케이션

- 복잡한 다단계 작업은 착수 전 한 줄로 "무엇을 하려는지" 선언 (예: "debug 워크트리를 rebase 하고 보고서를 쓰겠습니다").
- 중요 분기·결과·블로커는 즉시 보고.
- 종료 시 1–2 문장으로 무엇이 바뀌었는지 요약.

## 강제력

| 위반 | 결과 |
|------|------|
| 허락 요청형 문구로 사용자에게 질문 | Main 은 질문을 취소하고 곧바로 실행으로 전환 |
| "기다리라" 는 지시 없이 텍스트로만 대기 상태 유지 | 다음 턴 즉시 실행 착수 |
| 안전 규칙 위반을 "허락 없이" 라는 이유로 정당화 | 안전 규칙이 우선, 본 규칙으로 우회 불가 |

## 관련 규칙

- `.claude/rules/worktree-parallel.md`
- `.claude/rules/workflow.md`
- `.claude/rules/git-workflow.md`
- `.claude/rules/worktree-task-report.md`
- `.claude/rules/claude-config-sync.md`

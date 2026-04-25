# Haeda

Collaborative challenge app — calendar-based motivation service. Flutter + FastAPI + PostgreSQL + Kakao OAuth. Hospital pilot MVP (4 weeks).

## Workflow

기본 워크플로우는 **superpowers** 플러그인 (`@claude-plugins-official/superpowers`). 흐름:

```
brainstorming → writing-plans → (executing-plans | subagent-driven-development)
              → test-driven-development + verification-before-completion
              → finishing-a-development-branch + commit
```

자세한 트리거 색인은 `.claude/rules/superpowers-default.md`.

폐기:
- AI-DLC adaptive workflow (2026-04-25)
- 11-agent feature-flow dispatch
- 10-step slice flow
- 워크트리 role contract (planner / design / claude / feature 분리)

폐기된 자료는 `.claude/{agents,skills,rules}/ARCHIVE/` 와 `docs/ARCHIVE/`. 참조 자료일 뿐, 실행 대상 아님.

## Source of Truth (read-only)

- `docs/ARCHIVE/prd.md` — features, P0/P1 scope, NFRs, success metrics
- `docs/ARCHIVE/user-flows.md` — screen flows
- `docs/ARCHIVE/domain-model.md` — entities, fields, business rules
- `docs/ARCHIVE/api-contract.md` — REST endpoints, schemas, error codes

코드와 docs 가 충돌하면 docs 우선. `docs/ARCHIVE/**` 는 사용자 승인 없이 수정 금지 (`docs-guard.sh` hook 강제).

## MVP Guardrails

- P0 features only. P1+ implemented on user request.
- Open Questions (`docs/ARCHIVE/prd.md` section 9): confirm with user before deciding.

## Rules (`.claude/rules/`)

- **superpowers-default.md** — 기본 워크플로우 + 자동 발동 트리거 색인
- **language-policy.md** — 한국어 산출물 정책 (MANDATORY)
- **local-build-verification.md** — server/** 변경 후 docker rebuild + health check (MANDATORY)
- **ios-simulator.md** — app/** 변경 후 simulator clean install (MANDATORY)
- **coding-style.md** — terminology, API format, season icons, file size limits
- **git-workflow.md** — conventional commits, PR-based merge
- **security.md** — secrets, validation, encoding (hooks 로 강제)
- **docs-protection.md** — docs/ARCHIVE/ immutability (hook 으로 강제)

## Local Skills (`.claude/skills/`)

| 스킬 | 용도 |
|------|------|
| `commit` | stage + commit + PR 자동 머지 |
| `resolve-conflict` | rebase conflict lossless 해결 |
| `local`, `smoke-test` | docker compose 라이프사이클 + 통합 검증 |
| `haeda-build-verify` | server/** 변경 후 자동 빌드 검증 |
| `haeda-ios-deploy` | app/** 변경 후 simulator clean install |
| `haeda-domain-context` | 도메인 용어 / 시즌 아이콘 / MVP scope |
| `fastapi-mvp`, `flutter-mvp` | 스택별 구현 가이드 |
| `frontend-design` | UI 디자인 |
| `using-skills` | "skip is failure" 메타 스킬 |
| `set` | Claude Code 설정 변경 |
| `skill-creator` | 새 스킬 작성 (또는 `superpowers:writing-skills`) |

## Out of Scope

CI/CD, 프로덕션 배포, K8s, monitoring. 로컬 docker compose 만.

## Rollback

`pre-aidlc-migration` git tag 가 본 superpowers 전환의 base. 전체 롤백: `git reset --hard pre-aidlc-migration`. 개별 파일 부분 롤백은 git 히스토리 참조.

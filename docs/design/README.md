# Design Specs

Haeda 앱의 시각/인터랙션 디자인 명세 저장소. `pixel-art-designer` 등 디자인 워크트리의 에이전트가 작성하고, 피쳐 워크트리(`feature` / `front` / `backend`)가 구현한다.

자세한 운영 규칙은 `.claude/rules/design-worktree.md` 를 따른다.

## 디렉토리 구조

```
docs/design/
  README.md            # 이 파일
  drafts/<slug>.md     # 작업 중 (status: draft)
  specs/<slug>.md      # 구현 대기 또는 구현 완료 (status: ready | in-progress | implemented | dropped)
```

`specs/` 는 살아있는 참조 자료다. 구현이 끝난 스펙도 archive 로 옮기지 않고 제자리에서 `status: implemented` 로만 표시한다 (기획 문서와 다른 점).

## 파일 네이밍

`<slug>.md` — slug 는 소문자 하이픈, 40자 이내.

예: `miniroom-cyworld.md`, `challenge-room-social.md`, `room-decoration.md`.

## Status 필드 (필수)

모든 `drafts/`·`specs/` 의 문서는 front-matter 에 `status` 가 반드시 있어야 한다. `.claude/hooks/design-status-guard.sh` 가 PreToolUse 에서 검증한다.

| Status | 의미 | 디자인 워크트리 | 피쳐 워크트리 |
|--------|------|-----------------|----------------|
| `draft` | 작업 중 | yes (보통 `drafts/`) | (보통 안 씀) |
| `ready` | 구현 대기 = **아직 구현 안 됨** | yes (보통 `specs/`) | (안 씀) |
| `in-progress` | 피쳐 워크트리가 lock | **no** (hook 차단) | yes (`/implement-design` 자동) |
| `implemented` | 구현 완료 | **no** (hook 차단) | yes (`/implement-design` 자동) |
| `dropped` | 폐기 | yes | yes |

`TEMPLATE-*.md` 가 있다면 검증 예외로 통과한다.

## 라이프사이클

```
디자인 워크트리:
  drafts/<slug>.md (status: draft)
        |  refine
        v
  specs/<slug>.md  (status: ready)        ← 여기서 commit + push

피쳐 워크트리:
  /implement-design
        |  (1) status: ready → in-progress  (atomic lock)
        |  (2) Skill(feature-flow, ...) 실행 — 9-step 파이프라인
        v  성공
  specs/<slug>.md  (status: implemented)  ← 제자리 유지
```

## 접근 권한

| Worktree | 읽기 | 쓰기 (path) | 쓰기 (status) |
|----------|------|-------------|---------------|
| design   | O    | O (`docs/design/**`만) | draft / ready / dropped |
| feature / front / backend | O | O (`docs/design/**`) | 모든 5개 값 |
| planner / claude / qa | O | (역할상 docs/design 변경 권장 X) | — |

## 관련 파일

- 규약: `.claude/rules/design-worktree.md`
- 작성 에이전트: `.claude/agents/pixel-art-designer.md`
- 디스커버리 스킬: `.claude/skills/implement-design/SKILL.md`
- Path-scope guard: `.claude/hooks/design-guard.sh`
- Status guard: `.claude/hooks/design-status-guard.sh`
- 상위 워크트리 매트릭스: `.claude/rules/worktree-parallel.md`

# Superpowers 기본 워크플로우 전환

- Date: 2026-04-25
- Worktree: claude (`.claude/worktrees/claude`)
- Role: claude

## Request

사용자: "이제 이 프로젝트에서 모든 작업을 할 때, superpowers 를 기본으로 쓰도록 설정하고 싶어." → "AIDLC 는 완전 폐기" → "git 을 AIDLC 적용 전 (HEAD 하나 전) 으로 롤백한 후 작업 진행"

## Context

- 직전 워크플로우: AI-DLC adaptive workflow + haeda 4 개 always-enforced extension (haeda-tdd / haeda-local-build / haeda-flutter-ios-sim / haeda-domain-context). 그 이전 (pre-aidlc-migration tag) 은 11-agent feature-flow + 10-step slice flow.
- superpowers 플러그인 (5.0.7) 이 `/plugin install` 로 추가되어 있었으나 비활성 상태.
- 사용자가 superpowers 를 "기본" 으로 쓰고 싶어함.

## Decisions

| Q | 선택 |
|---|------|
| Q1: AI-DLC 와 superpowers 의 관계 | A. 완전 교체 |
| Q2: haeda 고유 정책 보존 | B+C (룰 분리 + 로컬 스킬 변환) |
| Q3: 기존 AI-DLC 산출물 처리 | git reset --hard pre-aidlc-migration |
| Q4: 기본화 접근 | 1. 적극 교체 (feature-flow 11-agent 도 ARCHIVE) |
| 실행 방식 | 초기 1 (subagent-driven) → 사고 후 B (inline) 로 전환 |

상세 spec: `docs/superpowers/specs/2026-04-25-superpowers-default-design.md`
상세 plan: `docs/superpowers/plans/2026-04-25-superpowers-default.md`

## Actions

| 단계 | commit | 내용 |
|------|--------|------|
| Reset | (no commit) | `git reset --hard pre-aidlc-migration` (HEAD: dc99369) |
| Task 1A | `45781b1` | `.claude/agents/*` 11 개 → ARCHIVE/ |
| Task 1B | `469e89e` | `.claude/skills/*` 19 개 → ARCHIVE/ (중복 5 + feature-flow 14) |
| Task 1C | `f11fd65` | `.claude/rules/*.md` 15 개 → ARCHIVE/ |
| Task 2 | `bcc3d05` | git-workflow / resolve-conflict / fastapi-mvp / flutter-mvp / skill-creator / using-skills / commit / set 8 파일의 archived 참조 cleanup |
| Task 3 | `082b5d8` | 신규 룰 4 개: language-policy / local-build-verification / ios-simulator / superpowers-default |
| Task 4 | `82591a8` | 신규 로컬 스킬 2 개: haeda-build-verify / haeda-ios-deploy |
| Task 5 | `120e6c0` | CLAUDE.md 72 줄 superpowers 색인으로 재작성 |
| Task 6 | `b551c02` | settings.json `enabledPlugins` 에 superpowers 활성화 |
| Task 7 | (본 commit) | smoke test + 보고서 |

총 9 commit. force-with-lease push + PR 은 Task 8 에서 별도 진행.

## 사고 기록 (Task 1B)

Task 1B 실행 중 subagent-driven 모드의 haiku implementer 가 task scope 외 untracked 파일 (`docs/superpowers/specs/2026-04-25-superpowers-default-design.md`, `docs/superpowers/plans/2026-04-25-superpowers-default.md`) 을 "cleanup" 명목으로 삭제하고 unstaged `.claude/settings.json` 변경을 reset. archival 자체는 정확. controller 가 conversation context 의 원본 텍스트로 spec/plan/settings.json 재생성 후 Task 1C 부터는 inline 실행으로 전환.

교훈: 작은 mechanical task 에 subagent 를 쓰면 over-step risk 가 cost 보다 큼. 향후 비슷한 config 마이그레이션은 inline + 정적 검증 조합이 적합.

## Verification

- 정적 검증: agents top-level 0 / rules top-level 8 / skills top-level 13 ✓
- ARCHIVE 카운트: agents 11 + rules 15 + skills 19 = 45 ✓
- 신규 파일 6 개 모두 존재 + size > 500 bytes ✓
- stale 참조 grep: 출력 없음 ✓
- settings.json JSON 유효 + superpowers 활성: ✓
- 신규 스킬 description ≥ 30 자 (haeda-build-verify 166 / haeda-ios-deploy 173) ✓
- system-reminder 의 active skill 목록에 신규 스킬 등록 확인 (Task 4 후): ✓
- (사용자 검증 필요) 다음 세션 시작 시 superpowers description 트리거 자동 발동 — 예: "이 함수에 버그가 있는 것 같아" → `superpowers:systematic-debugging` 호출 여부

## Follow-ups

- Task 8 (force-with-lease push + PR + 자동 머지) 가 본 보고서 다음 단계.
- 본 PR 머지 후 다른 워크트리 (`feature`, `design`, `planner`, `debug` 가 있다면) 모두 `git fetch origin main && git rebase origin/main` 후 Claude Code 세션 재시작 필요. 룰/스킬/에이전트 목록은 세션 시작 시점에 로드된다.
- `aidlc-docs/` 디렉토리는 reset 으로 삭제됨. git 히스토리 (096a890 머지 직전) 에서 참조 가능.
- `worktree-parallel.md` 가 ARCHIVE 로 가면서 design-worktree / planner-worktree 도 함께 ARCHIVE. 만약 다시 워크트리 분리 운영이 필요하면 superpowers `using-git-worktrees` 로 신규 도입 또는 ARCHIVE 에서 부활시킨다.

## Related

- spec: `docs/superpowers/specs/2026-04-25-superpowers-default-design.md`
- plan: `docs/superpowers/plans/2026-04-25-superpowers-default.md`
- base: `pre-aidlc-migration` git tag → `dc99369`
- archived: `.claude/{agents,skills,rules}/ARCHIVE/`, `docs/ARCHIVE/`

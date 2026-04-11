# Debug / Feature 워크트리 statusline 복구

- **Date**: 2026-04-11
- **Worktree (수행)**: `claude`
- **Worktree (영향)**: `debug`, `feature`
- **Role**: claude

## Request

사용자 보고:
1. `cd /Users/yumunsang/haeda/.claude/worktrees/debug && claude` 실행 시 하단 statusline 빈 상태.
2. 이어서 `feature` 워크트리에서도 동일 증상. "전역으로 적용되어야 한다"는 요구.

## Root cause

commit `06fd777` (`chore(claude): remove repo-level statusLine in favor of user-level`)은 repo-level `.claude/settings.json` 의 `statusLine` 블록을 제거해 user-level statusline(`~/.claude/settings.json` → `/Users/yumunsang/.claude/bin/statusline.sh`)이 사용되도록 전환했다. 그러나 `debug` / `feature` 워크트리의 브랜치(`worktree-debug`, `worktree-feature`)는 해당 커밋 이전 상태여서 옛 `echo "..."` 기반 `statusLine` 블록이 git-tracked `.claude/settings.json` 에 그대로 남아 user-level 설정을 덮어썼다. 옛 명령이 참조하는 환경변수가 비어 사실상 공백 출력이 되어 "아무것도 안 보임" 으로 나타남.

`origin/main` 자체는 이미 `8393265` (HEAD) 까지 진행되어 있으며 `06fd777` 를 포함하고 있어, 모든 워크트리가 `origin/main` 에 rebase 되기만 하면 자동으로 해결된다.

## Actions

| 워크트리 | 브랜치 (before) | 조치 | 결과 |
|---------|-----------------|------|------|
| `debug` | `worktree-debug` @ `770c129` | `git fetch origin main && git rebase origin/main` | fast-forward, conflict 없음 |
| `feature` | `worktree-feature` @ `5a320c0` | dirty tree 로 인해 `git stash` 후 rebase, 이후 `git stash pop` | rebase 성공, stash pop 성공 |

`feature` 워크트리 rebase 중 untracked `app/lib/core/widgets/tappable_character.dart` 가 새 tracked 버전(commit `9f48845 fix(app): add missing TappableCharacter widget`)과 충돌. untracked 파일을 `/tmp/tappable_character.dart.feature-backup` 로 이동 후 rebase 진행. 두 버전 차이 요약:

- **local (backup)**: 단순 scale-down tap animation + `onTap` 콜백
- **main**: 6 종 랜덤 리액션(jump/wiggle/spin/squish/bounce/headBob), `enabled` 플래그, 직전 리액션 회피 로직

main 버전이 기능적으로 상위 집합이므로 별도 병합 불필요. 다만 사용자가 local 쪽 인터페이스(`onTap`)에 의존하는 미완성 코드가 있다면 확인 필요.

파일 직접 수정은 없음. 모든 `.claude/settings.json` 변경은 rebase 가 자동 반영했다.

## Verification

```bash
grep -c statusLine /Users/yumunsang/haeda/.claude/worktrees/debug/.claude/settings.json    # → 0
grep -c statusLine /Users/yumunsang/haeda/.claude/worktrees/feature/.claude/settings.json  # → 0
grep -c statusLine /Users/yumunsang/haeda/.claude/worktrees/claude/.claude/settings.json   # → 0
```

사용자 측 수동 확인 필요: 각 워크트리에서 `claude` 실행 후 하단 statusline 표시.

## Follow-ups / 재발 방지

- `.claude/settings.json` 의 repo-level `statusLine` 는 이후에도 추가하지 말 것. user-level (`~/.claude/settings.json`) 만 사용.
- 새 워크트리를 생성할 때마다 `worktree-parallel.md` 의 startup ritual(`git fetch origin main && git rebase origin/main`) 를 항상 먼저 실행.
- (선택) `feature` 워크트리의 `/tmp/tappable_character.dart.feature-backup` 정리.

## Related

- Plan: `/Users/yumunsang/.claude/plans/stateless-chasing-scone.md`
- Upstream fix commit: `06fd777 chore(claude): remove repo-level statusLine in favor of user-level`
- Related commit pulled into feature: `9f48845 fix(app): add missing TappableCharacter widget`

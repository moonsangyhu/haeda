---
name: role-scoped-commit-push
description: 역할별(front/backend/qa/claude) 허용 경로만 stage → commit → push 한다. 병렬 세션에서 다른 역할 파일이 섞여 커밋되는 사고를 방지한다.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "<front|backend|qa|claude> [커밋 메시지]"
---

# 역할별 Scoped Commit & Push

병렬 Claude 세션(front / backend / qa / claude)에서 각 역할이 자기 범위의 변경만 stage → commit → push 하도록 강제한다.

## 사용법

```
/role-scoped-commit-push front feat: 챌린지 상세 화면 구현
/role-scoped-commit-push backend fix: 인증 토큰 검증 로직 수정
/role-scoped-commit-push qa 챌린지 생성 테스트 추가
/role-scoped-commit-push claude skill 추가
```

커밋 메시지를 생략하면 staged diff 기반으로 자동 생성한다.

인자: `$ARGUMENTS`

---

## 역할별 허용 범위

| 역할 | 허용 경로 패턴 |
|------|---------------|
| `front` | `app/lib/**`, `app/pubspec.yaml`, `app/pubspec.lock` |
| `backend` | `server/app/**`, `server/alembic/**`, `server/alembic.ini`, `server/pyproject.toml`, `server/seed.py` |
| `qa` | `app/test/**`, `server/tests/**` |
| `claude` | `.claude/**`, `CLAUDE.md` |

### 공통 제외

- `docs/**` — 문서는 자동 커밋 범위에 포함하지 않는다. 수동으로만 커밋한다.

### 겹침 없음

위 4개 역할의 허용 범위는 서로 겹치지 않는다. 어떤 파일이든 최대 하나의 역할에만 속한다.

---

## 절대 금지

아래 명령은 **어떤 상황에서도 실행하지 않는다**:

- `git add .`
- `git add -A`
- `git add --all`
- `git commit -a`
- `git commit --all`

반드시 개별 파일을 명시적으로 `git add <파일>` 한다.

---

## 실행 절차

### Step 0: 인자 파싱

`$ARGUMENTS`에서 첫 번째 토큰을 역할로, 나머지를 커밋 메시지로 분리한다.

- 역할이 `front`, `backend`, `qa`, `claude` 중 하나가 아니면 → 에러 출력 후 중단:
  ```
  ❌ 알 수 없는 역할: {role}
  허용 역할: front | backend | qa | claude
  ```
- 역할이 없으면 → 에러 출력 후 중단:
  ```
  ❌ 역할을 지정해주세요.
  사용법: /role-scoped-commit-push <front|backend|qa|claude> [커밋 메시지]
  ```

### Step 1: Git 상태 사전 점검

```bash
git status --porcelain
git diff --cached --name-only
```

#### 1-1. merge/rebase 진행 중 확인

```bash
git status
```

출력에 `You have unmerged paths`, `rebase in progress`, `merge in progress` 등이 포함되면 → 즉시 중단:
```
❌ merge/rebase가 진행 중입니다. 먼저 해결한 뒤 다시 시도하세요.
```

#### 1-2. 이미 staged 된 파일 중 범위 밖 파일 확인

```bash
git diff --cached --name-only
```

staged 파일이 있으면, 각 파일이 현재 역할의 허용 범위에 속하는지 확인한다.
범위 밖 파일이 하나라도 있으면 → **unstage 하지 않고** 즉시 중단:

```
❌ 현재 staged 된 파일 중 [{role}] 범위 밖 파일이 있습니다:
  - server/app/main.py  (front 역할에서는 허용되지 않음)
  - docs/prd.md  (모든 역할에서 제외됨)

먼저 수동으로 unstage 하세요:
  git reset HEAD <파일>
```

### Step 2: 역할 범위의 변경 파일 수집

```bash
git status --porcelain
```

출력에서 변경된 파일(modified, added, deleted, untracked) 중 현재 역할의 허용 범위에 해당하는 파일만 필터링한다.

**경로 매칭 규칙:**

| 역할 | 매칭 조건 |
|------|----------|
| `front` | `app/lib/`로 시작하거나 `app/pubspec.yaml` 또는 `app/pubspec.lock`과 일치 |
| `backend` | `server/app/`으로 시작하거나, `server/alembic/`으로 시작하거나, `server/alembic.ini` 또는 `server/pyproject.toml` 또는 `server/seed.py`와 일치 |
| `qa` | `app/test/`로 시작하거나 `server/tests/`로 시작 |
| `claude` | `.claude/`로 시작하거나 `CLAUDE.md`와 일치 |

추가로, `docs/`로 시작하는 파일은 어떤 역할이든 항상 제외한다.

해당하는 변경 파일이 없으면 → 종료:
```
ℹ️ [{role}] 범위에 변경된 파일이 없습니다. 커밋할 내용이 없습니다.
```

### Step 3: Stage

필터링된 파일만 개별적으로 stage 한다:

```bash
git add app/lib/features/challenge/screens/challenge_screen.dart
git add app/lib/features/challenge/providers/challenge_provider.dart
# ... 각 파일을 하나씩
```

### Step 4: Staged 파일 최종 검증

```bash
git diff --cached --name-only
```

staged 된 모든 파일이 현재 역할의 허용 범위 안에 있는지 **다시 한 번** 확인한다.
범위 밖 파일이 발견되면 → 커밋하지 않고 중단:

```
❌ 검증 실패: staged 파일 중 범위 밖 파일이 발견되었습니다.
  - {파일 경로}
커밋을 중단합니다. `git reset HEAD`로 정리한 뒤 다시 시도하세요.
```

### Step 5: Commit

#### 5-1. 커밋 메시지 결정

인자에서 커밋 메시지가 주어졌으면:
- 역할별 prefix가 없으면 자동으로 붙인다:
  - `front` → `feat(front): ...` (기본 prefix, 메시지가 `fix:` 등으로 시작하면 `fix(front): ...`)
  - `backend` → `feat(backend): ...`
  - `qa` → `test(qa): ...`
  - `claude` → `chore(claude): ...`

메시지가 없으면:
- `git diff --cached --stat`으로 변경 요약을 보고 한 줄 메시지를 생성한다.

#### 5-2. 커밋 실행

```bash
git commit -m "$(cat <<'EOF'
{prefix}({role}): {메시지}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

커밋이 실패하면 (pre-commit hook 등) → 에러 출력 후 중단. 자동 재시도하지 않는다.

### Step 6: Push

```bash
git push
```

upstream이 설정되지 않아 실패하면:

```bash
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"
```

push 실패 시 에러를 그대로 출력하고 중단한다. `--force`는 절대 사용하지 않는다.

### Step 7: 결과 출력

```
## Role-Scoped Commit & Push 결과

| 항목 | 값 |
|------|-----|
| 역할 | {role} |
| 브랜치 | {branch} |
| 커밋 | {short-hash} {메시지} |
| 파일 수 | {N}개 |

### Staged 파일
- {파일1}
- {파일2}
- ...

### Push
✅ origin/{branch} 에 push 완료
```

---

## 에러 시나리오 요약

| 상황 | 행동 |
|------|------|
| 역할 인자 없음/잘못됨 | 에러 메시지 출력 후 중단 |
| merge/rebase 진행 중 | 에러 메시지 출력 후 중단 |
| 기존 staged 파일 중 범위 밖 존재 | 파일 목록 보여주고 중단 (unstage 안 함) |
| 역할 범위에 변경 파일 없음 | 안내 메시지 출력 후 종료 |
| 최종 검증에서 범위 밖 파일 발견 | 중단 (커밋 안 함) |
| pre-commit hook 실패 | 에러 출력 후 중단 |
| push 실패 (upstream 없음) | `push -u origin <branch>` 재시도 |
| push 실패 (기타) | 에러 출력 후 중단, `--force` 금지 |

---

## 주의사항

- 이 skill은 **side-effect가 있다** (commit + push). 실행 전 반드시 staged 파일을 확인한다.
- 다른 역할의 변경을 stage/commit/push 하는 것은 절대 허용하지 않는다.
- `docs/**`는 모든 역할에서 제외된다. docs 변경은 수동으로 커밋한다.
- `--force` push는 어떤 상황에서도 사용하지 않는다.

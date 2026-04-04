# Worktree 병렬 작업 Runbook

haeda에서 Claude Code worktree를 사용한 슬라이스 병렬 개발 가이드.

## 언제 쓰는가

- 서로 다른 슬라이스의 backend/frontend를 병렬로 작업할 때
- 한 슬라이스를 구현하면서 다른 슬라이스의 QA/test-report를 동시에 진행할 때
- 구현 중 spec 분석이 필요할 때 (분석 전용 세션 분리)

## 기본 명령

```bash
# worktree + 세션 이름 지정으로 시작
claude --worktree slice-05 -n slice-05-backend

# 기존 worktree 세션 재개
claude --resume slice-05-backend

# 일반 세션 (worktree 없이, 단일 작업 시)
claude -n slice-05-backend
```

worktree는 `.claude/worktrees/slice-05/`에 생성되고, `worktree-slice-05` 브랜치로 작업한다.

## 세션 네이밍 규칙

```
slice-{NN}-{layer}
```

| 예시 | 용도 |
|------|------|
| `slice-05-backend` | slice-05 서버 구현 |
| `slice-05-frontend` | slice-05 Flutter 구현 |
| `slice-05-qa` | slice-05 QA 리뷰 + test report |
| `analysis` | spec 분석, 코드 조사 전용 |

## 안전한 병렬 조합

### 안전 (충돌 위험 낮음)

| 세션 A | 세션 B | 이유 |
|--------|--------|------|
| slice-04-backend | slice-05-frontend | 서로 다른 디렉토리 (server/ vs app/) |
| slice-04-frontend | slice-05-backend | 서로 다른 디렉토리 |
| slice-05-backend | slice-05-qa | QA는 읽기 전용 |
| 구현 세션 | analysis | 분석은 읽기 전용 |

### 위험 (충돌 주의)

| 세션 A | 세션 B | 위험 |
|--------|--------|------|
| slice-04-backend | slice-05-backend | 같은 모델/마이그레이션 파일 수정 가능 |
| slice-04-frontend | slice-05-frontend | 같은 라우터/공통 위젯 수정 가능 |
| 두 세션이 같은 DB 스키마 변경 | — | Alembic 마이그레이션 충돌 |

### 위험 완화

- **같은 layer 병렬 시**: 공통 파일(main.py, app.dart, 라우터 설정)을 먼저 작업하는 쪽을 정하고, 나중 세션에서 rebase한다.
- **DB 스키마 충돌 시**: 한 슬라이스의 마이그레이션을 먼저 merge한 뒤 다른 슬라이스를 진행한다.
- **판단이 어려우면**: 병렬 대신 순차 진행. 병렬의 목적은 속도지, 충돌 해결에 시간을 쓰는 것이 아니다.

## 일반적인 병렬 작업 흐름

### 패턴 1: 한 슬라이스 구현 + 다른 슬라이스 QA

```
[터미널 탭 1] claude --worktree slice-05 -n slice-05-backend
  → /slice-planning 챌린지 완료
  → backend-builder로 구현

[터미널 탭 2] claude -n slice-04-qa
  → /slice-test-report slice-04
  → qa-reviewer로 리뷰
```

### 패턴 2: 같은 슬라이스 backend + frontend 순차 → 병렬 전환

```
# 먼저 backend 완료
[탭 1] claude -n slice-05-backend
  → backend 구현 + pytest 통과 확인

# backend 완료 후 frontend 시작, backend QA 병렬
[탭 1] claude -n slice-05-frontend
  → flutter-builder로 UI 구현

[탭 2] claude -n slice-05-qa
  → /docs-drift-check
  → qa-reviewer
```

### 패턴 3: Spec 분석 전용 세션

```
[탭 1] claude -n slice-05-backend  (구현 진행 중)
[탭 2] claude -n analysis          (spec-keeper로 다음 슬라이스 사전 분석)
```

## Worktree 정리

변경 없는 worktree는 자동 삭제된다. 변경이 있는 worktree는:

```bash
# worktree 브랜치를 main에 merge
cd .claude/worktrees/slice-05
git add -A && git commit -m "feat: implement slice-05"
git checkout main
git merge worktree-slice-05
git branch -d worktree-slice-05
```

## 주의사항

- worktree 세션에서도 `docs/`는 수정하지 않는다 (Source of Truth 보호).
- worktree 세션에서 `/smoke-test`를 실행하려면 별도 서버 인스턴스가 필요할 수 있다 (포트 충돌).
- 병렬 세션 수는 2~3개를 권장한다. 5개 이상은 context switching 비용이 이득을 초과한다.

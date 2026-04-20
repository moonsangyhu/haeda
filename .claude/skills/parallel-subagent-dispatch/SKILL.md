---
name: parallel-subagent-dispatch
description: Main 이 독립적인 여러 문제를 subagent 들에게 병렬로 맡길 때 쓰는 가이드. 도메인 분리 가능성 확인, 프롬프트 템플릿, 결과 통합 시 충돌 감지.
---

# Parallel Subagent Dispatch Skill

독립적인 3개 이상의 문제를 한 Main 세션에서 순차 처리하면 비효율적이다. Agent 를 병렬로 띄워 시간을 단축한다. 단 **병렬성은 자유가 아니라 규율**이다 — 독립성 확인, 범위 격리, 결과 통합이 엄격히 관리되어야 한다.

이 스킬은 Main (Opus) 이 직접 따른다. subagent 들은 자기 범위 안에서 일반 워크플로를 따른다.

## 병렬화가 적합한 경우

- **독립적 화면 여러 개 디자인** — 예: 홈 / 설정 / 프로필 각 화면을 별도 ui-designer 에 파견
- **독립적 백엔드 엔드포인트 여러 개 구현** — 예: `/challenges` `/verifications` `/members` 각각 별도 backend-builder
- **독립적 탐색 쿼리 여러 개** — 예: 여러 라이브러리 조사, 여러 파일 군집 분석
- **독립적 버그 수정 여러 개** — 공유 파일 없는 버그들

## 병렬화가 부적합한 경우

- 같은 파일을 두 곳에서 수정 — merge 충돌
- Agent A 의 결과가 Agent B 의 입력 — 순차 진행 필요
- 같은 docker/simulator 리소스를 동시에 요구 — `.deployer.lock` 충돌
- Spec 이 하나로 얽혀 있고 나누면 일관성 깨지는 경우

## 실행 체크리스트

### 1. 독립성 확인
- 각 subagent 가 **겹치지 않는 파일 집합**을 수정하는가?
- 한 subagent 의 실패가 다른 subagent 작업을 무효화하지 않는가?
- 공유 리소스 (deployer lock, DB migration lock) 를 필요로 하지 않는가?

조건 하나라도 안 맞으면 순차 처리한다.

### 2. 범위 격리
- 각 subagent 의 프롬프트에 **자기 범위만** 명시
- 다른 subagent 가 건드리는 파일/경로를 **명시적으로 제외**
- worktree-parallel role contract 와 충돌하지 않는지 재확인

### 3. 프롬프트 템플릿

각 subagent 에게 주는 프롬프트는 다음 형식을 따른다:

```
[Context]
- 현재 상태: {한 줄 요약 — 사용자 목표, 슬라이스/픽스 맥락}
- 이 subagent 의 범위: {정확히 무엇을 할지}
- 범위 밖 (절대 건드리지 말 것): {다른 subagent 가 맡은 경로 / 공유 파일}

[Task]
{해야 할 구체 작업 — 목표 / 제약 / 예상 산출물}

[Constraints]
- worktree role: {role}
- 허용 경로: {path glob}
- 금지 행동: {예: "다른 구현자의 파일 수정 금지"}

[Output format]
- {기대 출력 구조 — 섹션, 길이 상한}
- 응답 상한: {예: under 300 words}

[Stop criteria]
- 성공: {완료 조건}
- 실패: {멈춰야 할 조건 — 사용자 결정 필요 상황 등}
```

**응답 길이 상한** 은 반드시 명시. "under 200 words" / "under 300 words" 등. 미명시 시 subagent 가 장문 산출물을 돌려 Main 컨텍스트를 빠르게 소진한다.

### 4. 병렬 발사

한 메시지 안에서 여러 Agent tool call 을 동시에 보낸다. 순차 보내면 병렬성 효과 없음.

```
# 올바른 병렬
<Agent call 1>
<Agent call 2>
<Agent call 3>
# (한 메시지, 세 개 함수 호출)
```

### 5. 결과 통합

각 subagent 의 결과가 돌아오면 Main 이:

1. **충돌 감지**: 각자 수정한 파일 목록을 모아 중복 확인. 중복 발견 시 `systematic-debugging` 으로 전환 (어느 쪽이 옳은지 확정 후 수정).
2. **정합성 확인**: spec 대비 각 결과가 일관된지 대조.
3. **후속 체인 진입**: 통합된 결과로 code-reviewer → qa-reviewer → deployer 체인 진입.

## 예시

### 예시 1 — 독립 화면 3개 디자인
```
Agent(ui-designer, prompt A: 홈 화면 디자인, 범위: docs/design/home.md)
Agent(ui-designer, prompt B: 설정 화면 디자인, 범위: docs/design/settings.md)
Agent(ui-designer, prompt C: 프로필 화면 디자인, 범위: docs/design/profile.md)
```
각자 다른 파일에 쓰고, 상호 의존 없음. 결과 통합은 필요 없음.

### 예시 2 — 독립 버그 3개 진단
```
Agent(Explore, "bug 1 재현 로그 수집", under 200 words)
Agent(Explore, "bug 2 재현 로그 수집", under 200 words)
Agent(Explore, "bug 3 재현 로그 수집", under 200 words)
```
진단 결과를 받아 Main 이 우선순위 정하고 `fix` 스킬 순차 진행.

### 예시 3 — 부적합 케이스 (순차로)
```
# ❌ 병렬 금지
Agent A: backend 엔드포인트 신규 추가 (server/app/routers/challenge.py)
Agent B: 같은 엔드포인트의 테스트 추가 (server/tests/test_challenge.py)
```
같은 feature 를 두 조각으로 쪼개면 둘 다 `feature` role 워크트리에서 순차로 하는 게 맞다. TDD 원칙상 test 먼저 (RED) → 구현 (GREEN) 이므로 이는 본질적으로 순차.

## Main 의 의무

- 병렬 발사 전 체크리스트 (독립성, 범위, 프롬프트) 모두 통과했는지 확인
- 각 subagent 결과는 **짧은 요약 1-2문장**으로 정리해 사용자에게 보고 (원본 그대로 쏟지 않기)
- 충돌 발견 시 즉시 STOP, systematic-debugging

## Never Do

- 같은 파일을 두 subagent 에 맡기기 — merge 충돌 필연
- 응답 길이 상한 없이 subagent 파견 — context 소진
- 병렬 결과를 그대로 사용자에게 복붙 — 통합 후 요약 필요
- 순차가 필요한 흐름(TDD RED→GREEN, planner→builder)을 억지로 병렬화

## 관련

- `.claude/rules/worktree-parallel.md` — worktree role contract 와 deployer lock
- `.claude/skills/systematic-debugging/SKILL.md` — 충돌 발견 시 호출
- `.claude/rules/agents.md` — dispatch chain (대부분은 순차)

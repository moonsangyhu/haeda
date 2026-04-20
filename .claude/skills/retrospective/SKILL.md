---
name: retrospective
description: slice / fix / config 변경 종료 직후 "무엇이 잘 됐고 무엇을 개선할지" 회고 섹션을 docs/reports/ 의 기존 보고서 말미에 append. 학습 루프를 작업 흐름에 연결.
---

# Retrospective Skill

모든 상태 변경 작업(feature, fix, config, rebase 포함) 은 `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 보고서를 남긴다 (`.claude/rules/worktree-task-report.md`). 이 스킬은 그 보고서 **말미**에 회고 3섹션을 의무적으로 붙이는 프로토콜을 정의한다.

별도 파일을 만들지 않는다. 기존 보고서의 마지막 부분에 덧붙인다.

## 왜 필요한가

`impl-log/` 는 사실 기록 (무엇을 고쳤는가), `test-reports/` 는 검증 로그 (무엇이 통과했는가), `docs/reports/` 는 통합 보고서. 이 중 어디에도 **"다음 번에 무엇을 다르게 할까"** 를 기록할 곳이 없었다.

회고가 없으면:
- 같은 종류 버그가 반복됨 (rule 에 반영 안 됨)
- 잘 통한 패턴이 공유 안 됨 (memory 나 rule 로 승격 안 됨)
- agent / skill 개선 신호가 소실됨

## 회고 3섹션

보고서 말미에 다음 형식으로 추가한다:

```markdown
## Retrospective

### What worked (반복 재현할 패턴)
- {구체적 패턴 / 행동 / 도구 — file/command/skill 인용}
- {이것이 왜 잘 작동했는지 1-2줄}
...

### What could improve (다음 슬라이스에 반영)
- {무엇이 매끄럽지 않았는지}
- {어떻게 고쳐야 할지 구체 제안}
...

### Process signal (rule/agent/skill 추가·수정 후보)
- [ ] {제안 1} — 예: "X 상황을 감지하는 hook 추가 필요"
- [ ] {제안 2} — 예: "Y skill 에 Z 조항 추가"
- [ ] (없으면 "None this round" 로 표기)
```

## 각 섹션 작성 가이드

### What worked
- 구체적으로. "잘 됐다" 만으로는 안 됨. **무엇을**, **언제**, **왜** 잘 됐는지.
- 재현 가능한 패턴에 집중. "운이 좋았다" 는 여기 안 씀.
- 예: "QA 전에 `flutter analyze` 를 builder 가 직접 돌렸더니 code-reviewer 왕복이 한 번 줄었다. `flutter-builder.md` 체크리스트 참고."

### What could improve
- 구체적 통증 포인트. "뭔가 어색했다" 는 안 씀.
- 이미 알고 있는 개선 방향도 적음 — 나중에 process signal 에 반영.
- 예: "feature-flow 의 Step 3 에서 backend builder 가 먼저 끝나고 flutter builder 가 뒤늦게 끝날 때 sync 가 어색. 명시적 join 지점 필요."

### Process signal
- **체크박스 형태**로 작성. 다음 `claude` role 세션이 이걸 읽고 처리 가능.
- rule / agent / skill / hook 중 무엇을 바꿔야 할지 명시.
- "None this round" 표기도 OK — 억지로 쥐어짜지 않는다.

## 호출 주체

| 상황 | 작성 주체 | 언제 |
|------|----------|------|
| feature-flow / fix-flow 정식 파이프라인 | `doc-writer` 에이전트 | Step 7 (Document) — impl-log + test-report + docs/reports 3개 파일 작성 시 docs/reports 말미에 함께 |
| 직접 수정 / config 변경 / 워크트리 정비 | Main 이 직접 | 작업 완료 직후, commit 전 |
| debugger 작업 | `debugger` 에이전트의 Phase 7 보고서 말미 | 자동 |

## 품질 기준

회고가 다음 조건을 충족해야 유효로 간주된다:

- **What worked ≥ 1 항목** 또는 명시적 "Nothing new learned this round"
- **What could improve ≥ 1 항목** 또는 명시적 "Flow was smooth"
- **Process signal** 섹션은 반드시 존재 (없으면 "None this round")
- 각 항목은 **file:line 또는 command 인용** 을 포함하면 좋음 (의무는 아님)

품질이 낮은 회고 예:
- "잘 됐다 / 어색한 것 없다" 만 쓴 경우 — 구체성 부족
- 이미 `impl-log` 에 적은 내용을 복붙 — 회고가 아님

## Process signal 의 후속 처리

`Process signal` 섹션에 체크박스 항목이 쌓이면 `claude` role 세션에서 주기적으로 스윕해 실제 rule/agent/skill 변경을 수행한다. 처리 완료 항목은 `[x]` 로 마킹.

전용 skill 은 없다 — `claude` role 에서 수동으로 `Grep "Process signal" docs/reports/` 로 미처리 항목을 모으면 됨.

## Never Do

- 별도 파일 생성 (retrospective-<slug>.md 같은 것 금지 — 기존 보고서 말미에만)
- 회고를 "모든 일이 완벽했음" 으로 일반화 — 최소 한 가지는 개선점 찾기
- Process signal 을 개인 의견으로 채움 — 구체적 hook/rule/agent 변경 제안만
- 사용자 비난 / agent 비난 — 시스템 관점 유지

## 관련

- `.claude/rules/worktree-task-report.md` — 보고서 의무의 원천
- `.claude/agents/doc-writer.md` — feature-flow 에서 본 스킬 호출
- `.claude/agents/debugger.md` Phase 7 — fix-flow 에서 본 스킬 호출
- `docs/reports/` — 산출물 위치

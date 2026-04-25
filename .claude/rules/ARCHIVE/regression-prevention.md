# Regression Prevention Rule (MANDATORY)

이 레포의 모든 상태 변경 작업은 **과거에 이미 구현·검증된 결과를 파괴하지 않도록** 설계·구현한다. 구체적 강제 수단은 "작업 시작 전 관련 `docs/reports/` 보고서를 반드시 읽고 참고" 하는 Read-before-Write 규약이다.

본 규칙은 `.claude/rules/worktree-task-report.md` 의 "작성 의무" 와 짝을 이루는 "참고 의무" 를 정의한다. 둘은 상호 참조되며, 어느 한쪽이 빠지면 무의미하다.

## 배경

- `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 는 모든 작업이 남기는 공식 작업 결과서다 (`worktree-task-report.md`).
- git 에 tracked 되어 모든 워크트리가 공유 knowledge base 로 사용한다.
- 과거 사례: `45f5418 revert(feature): character-cyworld-style 구현 전체 롤백` 처럼 기존 구현을 모르고 덮어써 롤백이 필요했던 사고가 발생했다.
- 본 규칙은 그 구조적 원인을 제거한다: "작업 시작 시점에 반드시 관련 보고서를 검색·정독·인용한다."

## 제1원칙 — 파괴 금지

- 멀쩡히 동작하는 기존 구현을 **제거·재작성·비활성화·축소하지 않는다**.
- 수정이 불가피한 경우 Feature Plan / builder completion output 에 다음을 **반드시** 명시한다:
  1. 수정 대상이 되는 기존 구현을 설명한 보고서 경로
  2. 해당 보고서에서 왜 이 구현이 필요했는지(Request / Root cause 섹션 인용)
  3. 그 목적을 유지한 채 수정해야 하는 이유
- 사용자 명시 승인 없이 제거 금지. 되돌리기는 `/rollback` 스킬로만 수행한다.

## 제2원칙 — Read-before-Write (참고 의무)

상태 변경 작업을 시작하는 **모든 에이전트**는 첫 번째 단계로 `docs/reports/` 에서 관련 과거 보고서를 조사한다.

### 검색 키워드 (최소 3개)

- 기능명 / 슬러그 (예: `character`, `calendar`, `verification`)
- 수정 대상 파일 경로 조각 (예: `app/lib/features/calendar`, `server/app/services/challenge`)
- 관련 엔티티명 (예: `Challenge`, `DayCompletion`)

### 실행 방법

```bash
# 예: 챌린지 캘린더 관련 새 작업 시작 시
rg -l "challenge|calendar|DayCompletion" docs/reports/
```

hit 된 모든 보고서의 본문을 Read. hit 이 없으면 범위를 넓혀 재검색한다 (상위 도메인 키워드, 관련 화면명 등). 그래도 없으면 "관련 선행 작업 없음" 으로 확정.

## 제3원칙 — 인용 의무

### Feature Plan (product-planner)

`### Referenced Reports` 섹션을 필수 출력. 형식:

```
### Referenced Reports
- docs/reports/2026-04-11-feature-character-background-color.md — "캐릭터 배경 계절 아이콘 매핑" (Actions §2). 재사용 대상: `app/lib/features/character/season_icon.dart`
- docs/reports/2026-04-05-emoji-to-material-icons.md — material icon 정책. 본 작업에서도 동일 원칙 적용.

— 검색 키워드: character, season, icon, app/lib/features/character
```

hit 이 없으면:

```
### Referenced Reports
관련 선행 작업 없음 — 검색 키워드: {나열}
```

### Builder / Debugger completion output

builder 와 debugger 는 구현 완료 시 동일 `### Referenced Reports` 섹션 출력. product-planner 가 전달한 목록 + 자신의 수정 파일 경로로 추가 검색한 결과 합집합.

빈 섹션은 허용되지 않는다. 항상 "hit 목록" 또는 "없음 — 키워드 나열" 중 하나.

## 강제력

| 시점 | 체크 | 실패 시 |
|------|------|--------|
| product-planner 실행 | Feature Plan output 에 `### Referenced Reports` 섹션 존재 | Main 이 product-planner 재호출 |
| backend-builder / flutter-builder / debugger 완료 | completion output 에 `### Referenced Reports` 섹션 존재 | 다음 에이전트(code-reviewer) 가 reject, 해당 builder 재호출 |
| code-reviewer gate | `### Referenced Reports` 섹션 존재 + (기존 파일 수정/삭제가 있으면 그에 대한 관련 보고서 인용이 포함) | **blocking** → builder 재호출 (max 1 retry) |

위반 시 처리 흐름은 `.claude/rules/agents.md` §Gate Rules Summary 의 "Regression Prevention" 행 참고.

## 예외 (Read 없이 작업 가능)

Read-before-Write 를 생략해도 되는 작업 유형:

- 오타·포맷·주석만 수정 (production 로직 변경 없음)
- `.env.example` / 설정 기본값 변경
- 순수 탐색 / 디버깅 세션 (어떤 파일도 수정하지 않음)
- 이번 세션 안에서 방금 만든 신규 파일에 대한 후속 편집 (관련 보고서가 존재할 수 없음)

위 예외는 completion output 의 `### Referenced Reports` 섹션에 "예외 해당 — {이유}" 로 한 줄만 적으면 된다. 섹션 자체를 생략하지 않는다.

## Do / Don't

✅ 과거 보고서에 남은 설계 판단을 존중하고, 바꿔야 한다면 이유를 보고서를 인용해 명시
✅ 최소 3개 키워드로 Grep, hit 없으면 범위 확장 재검색
✅ Feature Plan / completion output 에 Referenced Reports 섹션 유지

❌ "빠르게 수정하면 되니 생략" 으로 과거 보고서 검색 건너뛰기
❌ 기존 구현을 삭제·재작성하면서 Referenced Reports 에 해당 구현의 보고서가 빠짐
❌ "관련 보고서 없음" 을 기본값으로 적어두기 (최소 검색 키워드 3개를 시도하지 않은 상태에서)

## 관련 규칙

- `.claude/rules/worktree-task-report.md` — 작성 의무 (본 규칙의 짝)
- `.claude/rules/workflow.md` — 10-step slice flow 의 게이트 정의
- `.claude/rules/agents.md` — 에이전트 dispatch + Gate Rules Summary
- `.claude/skills/verification-before-completion/SKILL.md` — completion output 의 증거 형식

---
slug: your-feature-slug
status: idea          # idea | ready | in-progress | done | dropped
created: YYYY-MM-DD
area: front           # front | backend | full-stack
priority: P0          # P0 | P1 | P2
---

# {Feature title}

## 1. Executive Summary

{경영진이 30초 안에 파악할 수 있는 한 줄 요약. "누구에게, 무엇을, 왜" 형식.}

## 2. Problem / Why (문제 정의)

### 현재 상황

{사용자가 지금 겪고 있는 구체적인 불편함이나 pain point. 실제 사용 맥락에서 서술.}

### 문제의 크기

{이 문제가 얼마나 많은 사용자에게 영향을 미치는가. 가능하면 데이터/수치 근거 제시. MVP 파일럿 기준 병원 스태프 규모 등 맥락 활용.}

### 관련 문서

{`docs/prd.md` 의 해당 섹션. P0/P1 스코프 연결. 기존 스코프 밖이면 명시.}

## 3. User Scenarios (유저 시나리오)

### 시나리오 A: {시나리오 제목}

**인물**: {이름}, {나이}, {직업/역할}, {성격·동기 한 줄}

**상황**: {이 사람이 처한 구체적 상황. 시간, 장소, 맥락.}

**행동 흐름**:
1. {첫 번째 행동 — 무엇을 보고, 무엇을 탭하는지}
2. {두 번째 행동}
3. {세 번째 행동}
4. …

**감정 변화**: {시작 감정} → {중간 감정} → {결과 감정}

**결과**: {이 시나리오의 성공 상태. 사용자가 얻는 것.}

---

### 시나리오 B: {시나리오 제목}

**인물**: {이름}, {나이}, {직업/역할}, {성격·동기 한 줄}

**상황**: {다른 유형의 사용자 또는 엣지 케이스 상황}

**행동 흐름**:
1. …
2. …

**감정 변화**: {시작} → {결과}

**결과**: {성공 또는 실패 케이스에서 사용자가 겪는 것}

---

{필요시 시나리오 C, D 추가. 최소 2개 필수.}

## 4. Planning Rationale (기획 의도)

### 왜 이 기능을, 왜 지금

{MVP 목표와의 정렬, 병원 파일럿 성공을 위해 이 기능이 필수인 이유. 전략적 맥락.}

### 대안 검토

| 접근법 | 장점 | 단점 | 선택 여부 |
|--------|------|------|-----------|
| {현재 제안} | … | … | **채택** |
| {대안 A} | … | … | 기각 — {이유} |
| {대안 B} | … | … | 기각 — {이유} |

### 우선순위 근거

{다른 기능 대비 이 기능을 지금 구현해야 하는 이유. 의존성, 사용자 임팩트, 구현 비용 관점.}

## 5. Expected Impact (기대 효과)

### 정량적 기대 효과

| 지표 | 현재 (추정) | 기대 변화 | 측정 방법 |
|------|-------------|-----------|-----------|
| {예: 일일 인증 완료율} | {예: 60%} | {예: → 80%} | {예: 서버 로그 집계} |
| … | … | … | … |

### 정성적 기대 효과

- {사용자 경험 측면의 변화}
- {팀/조직 측면의 변화}
- {브랜드/서비스 인식 변화}

### 리스크와 완화 방안

| 리스크 | 영향도 | 완화 방안 |
|--------|--------|-----------|
| {예: 알림 피로} | 중 | {예: 하루 1회 제한 + 설정에서 끄기 가능} |
| … | … | … |

## 6. User-facing Behavior (사용자 경험 상세)

`docs/user-flows.md` 의 스크린 이름을 참조하여 기술.

- **Entry point(s)**: {사용자가 이 기능에 진입하는 경로}
- **Main flow**: {핵심 흐름 단계별 서술}
- **Edge cases**: {비정상 경로, 네트워크 오류, 빈 상태 등}
- **Success state**: {정상 완료 시 사용자가 보는 화면/상태}
- **Failure state**: {실패 시 사용자가 보는 화면/상태}

## 7. Scope

**In scope**
- …

**Out of scope**
- …

**Deferred (P1+)**
- …

## 8. Technical Handoff (개발 핸드오프)

### Affected Files (best-effort)

| Layer | Path | Change |
|-------|------|--------|
| front | `app/lib/features/.../...dart` | … |
| backend | `server/app/routers/....py` | … |
| backend | `server/app/models/....py` | … |

### API Contract / Domain Model Deltas

`docs/api-contract.md` / `docs/domain-model.md` 에서 업데이트가 필요한 부분. **플래너 워크트리에서는 해당 파일을 수정하지 않는다** — 필요한 변경을 명시하여 `spec-keeper`가 feature-flow에서 검증할 수 있게 한다.

- Endpoints (new/changed):
- Fields (new/changed):
- Error codes:
- Domain rules:

### Acceptance Criteria (testable)

- [ ] …
- [ ] …
- [ ] …

각 기준은 `qa-reviewer`가 실행할 수 있는 구체적 테스트(유닛, 통합, 수동 스모크)에 매핑 가능해야 한다.

### Handoff Notes

- Primary builder: `backend-builder` | `flutter-builder` | both (parallel)
- Recommended worktree: `.claude/worktrees/feature` (or a dedicated slice worktree)
- Pre-reads: 관련 impl-log 항목이나 선행 스펙
- Risks: debugger/QA가 주의해야 할 사항

## 9. Open Questions

- …

구현 시작 전 사용자 확인이 필요한 질문. 이 섹션이 비어있지 않으면 `status: idea`로 유지.

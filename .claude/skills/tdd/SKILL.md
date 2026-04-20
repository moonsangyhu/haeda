---
name: tdd
description: RED-GREEN-REFACTOR 루프 강제. backend-builder / flutter-builder가 production 코드 작성 전 반드시 호출. 예외는 오타/포맷/코멘트만.
---

# Test-Driven Development (TDD) Skill

"**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**"

이 원칙은 예외 없이 적용된다. 다만 **오타 수정, 포맷팅, 코멘트 변경** 은 TDD 생략을 허용한다. 그 외 모든 production 코드 변경은 RED → GREEN → REFACTOR 사이클을 따른다.

이 스킬은 `backend-builder`, `flutter-builder`, 그리고 `debugger`가 fix 를 실행할 때 참조한다. builder completion output 에 반드시 **RED/GREEN 증거**를 인용해야 한다. 인용 누락 시 `code-reviewer` 가 blocking issue 로 처리한다.

## 3단계 사이클

### Phase 1 — RED (실패하는 테스트 먼저)

1. **테스트 파일 작성**: 앞으로 구현할 동작(endpoint, widget, service 함수 등)에 대응하는 테스트를 먼저 쓴다.
2. **실제 실패 실행**: 테스트를 실행해 **실패하는 것을 직접 확인**한다. 실패 없는 테스트는 RED 가 아니다.
3. **실패 출력 캡처**: 실패 메시지 3-10줄을 completion output 에 인용한다.

| Stack | RED 실행 명령 | 기대 결과 |
|-------|--------------|----------|
| Backend (FastAPI) | `cd server && uv run pytest <test_file>::<test_name> -x --tb=short` | `FAILED ... AssertionError / ImportError / ...` |
| Frontend (Flutter) | `cd app && flutter test <test_file>` | `FAILED: ... (1 failed, 0 passed)` |

금지:
- 구현부터 작성하고 테스트를 나중에 덧붙이기 — **RED 가 아님**
- "이미 실패할 것이라고 확신하므로 실행 생략" — 실제 실행 출력만 증거로 인정
- 무조건 fail 하는 `assert False` 로 RED 흉내 — 의도한 기능의 부재를 증명하는 단언이어야 함

### Phase 2 — GREEN (최소한의 구현)

1. **테스트를 통과시키는 가장 작은 코드**를 작성한다. 과설계 금지.
2. **동일한 테스트 재실행**: RED 단계와 동일한 명령으로 실행해 PASS 확인.
3. **통과 출력 캡처**: `N passed` 출력을 completion output 에 인용한다.

금지:
- RED 에서 쓴 테스트보다 범위 큰 구현 — "나중을 위해" 같은 과설계
- 다른 테스트가 같이 깨지는 구현 — 회귀는 REFACTOR 전에 금지
- 테스트를 우회하는 구현 (테스트 수정, skip 마크 등)

### Phase 3 — REFACTOR (테스트 통과 유지하며 정리)

1. **코드 중복 제거 / 명명 개선 / 구조 정리** — 기능 변경 없이.
2. 매 변경마다 테스트 전체를 재실행해 통과 유지 확인.
3. 리팩터 산출물을 completion output `### Refactor Notes` 로 간단히 기술.

REFACTOR 단계에서 새 동작이 필요하다면 새 RED 사이클로 진입하라. 리팩터 안에서 기능 추가 금지.

## Builder Completion Output 템플릿

builder 에이전트는 구현 보고 시 다음 섹션을 반드시 포함한다:

```
### TDD Cycle Evidence

#### RED — {test_file}::{test_name}
Command: {exact command}
Output (failing):
    {3-10 line failure excerpt}

#### GREEN — same test
Command: {same command}
Output (passing):
    {3-10 line pass excerpt, e.g. "1 passed in 0.42s"}

#### Refactor Notes (optional)
- {refactor 1 — e.g., extracted helper _build_query}
- {refactor 2 — e.g., renamed x → verification_id}
```

## 적용 예외 (명시적 허용)

TDD 생략이 허용되는 경우:
- **오타 수정** — 문자열, 주석, 변수명 오타
- **코드 포맷팅** — whitespace, import 순서, 줄바꿈
- **주석 변경** — docstring, 인라인 주석
- **테스트 파일 자체의 수정** — 테스트 자체를 고칠 때 (단, 테스트를 느슨하게 만드는 변경은 금지)
- **설정 파일 값 변경** — `.env.example`, 환경변수 default 값

그 외 모든 변경은 TDD 의무. 애매하면 RED 부터 작성한다.

## 실패 시나리오

| 상황 | 대응 |
|------|------|
| RED 단계에서 테스트가 **예상과 다른 방식**으로 실패 | 테스트를 먼저 수정해 의도대로 실패하게 한 뒤 진행. 코드부터 손대지 않는다. |
| GREEN 단계 진입 후 구현이 너무 커진다고 느낌 | 현재 테스트 하나만 통과시키는 데 집중. 다른 테스트는 다음 RED 사이클. |
| REFACTOR 중 실수로 테스트 깨짐 | 즉시 `git diff` 로 변경 되돌린 뒤, 더 작은 리팩터 단위로 재시도. |
| 실패 출력이 10줄 이상으로 길고 복잡 | 핵심 3-5줄만 발췌. `...` 로 중략 표시. |

## Cross-Skill 연동

- `systematic-debugging` 이 진단한 버그를 고칠 때도 이 스킬 적용. debugger 의 Phase 5 (Execute) 가 곧 RED→GREEN 사이클이 되어야 함.
- `verification-before-completion` 은 TDD 완료 후 호출. "테스트 passed" 주장에 반드시 출력 인용.
- `retrospective` 섹션 작성 시 TDD 사이클 중 깨달은 "더 작은 단위로 쪼개는 법" 을 기록할 수 있음.

## Never Do

- production 코드를 테스트 없이 작성 (예외 목록 외)
- 통과하는 테스트를 먼저 쓰고 "RED 가 있었던 셈 치기"
- RED/GREEN 출력을 **인용 없이** 요약만 기술 ("테스트 추가함" 만 쓰고 출력 없음 → 규칙 위반)
- 여러 기능을 하나의 RED 로 한꺼번에 포함 — 한 사이클은 하나의 의도된 실패만

## 관련 규칙

- `.claude/rules/tdd.md` — 이 스킬의 의무화 레벨
- `.claude/rules/verification.md` — "완료" 주장 시 증거 형식
- `.claude/agents/code-reviewer.md` §8 Test Coverage — TDD 증거 누락 시 blocking
- `.claude/agents/backend-builder.md`, `flutter-builder.md` — Execution Contract 첫 항목으로 본 스킬 참조

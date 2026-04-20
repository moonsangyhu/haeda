# TDD Rule

Haeda 에서 **모든 production 코드 변경**은 Test-Driven Development 사이클 (RED → GREEN → REFACTOR) 을 따른다. 예외는 오타·포맷·코멘트·테스트 파일 자체의 수정·설정값 변경 뿐이다. 본 규칙은 `.claude/skills/tdd/SKILL.md` 의 실행 지침을 "의무화 레벨" 로 선언한다.

## 적용 범위

| 코드 영역 | TDD 의무 |
|----------|---------|
| `server/app/routers/**` | **필수** |
| `server/app/services/**` | **필수** |
| `server/app/models/**` + alembic migration | 필수 (migration 변경분은 데이터 상태 테스트) |
| `app/lib/features/**` screens/providers/widgets | **필수** |
| `app/lib/core/**` shared utilities | 필수 |
| 테스트 파일 자체 (`server/tests/**`, `app/test/**`) | 예외 |
| `.env.example`, 설정 기본값 | 예외 |
| 주석 / 문서 / 포맷 / 오타 | 예외 |
| `.claude/**`, `CLAUDE.md`, `docs/**` | 비-프로덕션 — 본 규칙 비적용 |

## 강제력 (강한 권고 수준 + 후속 gate 블록)

TDD 미수행 자체는 "hard block" 으로 파이프라인을 멈추지 않는다. 단 **증거 누락은 code-reviewer 의 blocking issue** 로 이어진다.

| 시점 | 체크 | 실패 시 |
|------|------|--------|
| Builder 구현 완료 | completion output 에 `### TDD Cycle Evidence` 섹션 존재 + RED/GREEN 로그 인용 | code-reviewer §8 에서 "TDD 증거 누락" blocking, builder 재호출 |
| Code review | 새 production 파일 / 엔드포인트 / 화면에 대응 테스트 존재 여부 | code-reviewer §8 Test Coverage blocking |
| QA | 추가된 테스트가 **실제로 PASS** 하는지 pytest/flutter test 로 확인 | qa-reviewer fail → debugger |

결과적으로 builder 가 TDD 를 건너뛰려 해도 code-reviewer 가 이를 잡아내 재호출을 요구하게 된다.

## Builder 의무

`backend-builder`, `flutter-builder`, `debugger` 는 모든 production 코드 변경 시작 전 `.claude/skills/tdd/SKILL.md` 를 참조한다. completion output 에 **RED 명령/출력 + GREEN 명령/출력** 을 반드시 인용한다. 구체 형식은 tdd skill 의 "Builder Completion Output 템플릿" 참고.

## 예외 처리

예외 영역의 변경만 포함된 PR/커밋은 `### TDD Cycle Evidence` 섹션을 생략해도 된다. 단 commit message 에 "docs only", "typo fix", "format only" 등 의도를 명시해 code-reviewer 가 혼동하지 않게 한다.

프로덕션 변경이 하나라도 섞여 있으면 그 변경분에 대해서는 TDD 증거를 요구한다. "전체 중 일부만 예외" 는 허용되지 않는다.

## Superpowers 와의 관계

superpowers 의 `test-driven-development` 스킬이 채택한 "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" 원칙을 haeda MVP 스피드와 균형 맞추어 수용했다:

- **Strict (superpowers)**: 생산 코드 1줄도 RED 없이 작성 불가
- **Haeda (현 수준)**: 예외 목록(오타/포맷/코멘트/설정) 외 production 코드 전부 적용, code-reviewer 가 실제 gate

향후 MVP pilot 종료 후 strict 모드로 승격 검토 가능.

## 관련

- `.claude/skills/tdd/SKILL.md` — 실행 지침
- `.claude/skills/verification-before-completion/SKILL.md` — 검증 증거 형식
- `.claude/agents/code-reviewer.md` §8 Test Coverage — gate 강제
- `.claude/agents/backend-builder.md`, `flutter-builder.md` — Execution Contract
- `.claude/rules/workflow.md` Step 3 — implementation 단계의 TDD 의무

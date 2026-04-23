# Verification Rule

모든 agent (그리고 Main) 는 **"완료", "성공", "pass"** 를 주장하기 전 `.claude/skills/verification-before-completion/SKILL.md` 에 정의된 5단계 체크리스트를 통과해야 한다. 증거 없이 내리는 완료 선언은 워크플로 위반이다. 본 규칙은 `workflow.md` 의 "Prove it works." 원칙을 실행 가능한 형태로 고정한다.

## 핵심 원칙

1. 모든 "OK/PASS/COMPLETE" 주장은 **명령 + 출력 발췌** 로 뒷받침된다.
2. 금지 어휘 사용 = verification 실패.
3. 부분 검증이 불가피할 때는 unverified 항목을 명시적으로 표시.

## 금지 어휘 (등장 시 verification 실패로 간주)

- "아마 작동할 것"
- "should work"
- "probably works"
- "likely passes"
- "에러 없을 거라 예상"
- "빌드는 됐으니 실행도 될 것"
- "동일한 패턴이므로 같은 결과일 것"

대신 실제 명령 실행 결과를 인용한다. 실행 불가능한 환경이면 `verification incomplete — {이유}` 로 명시.

## 에이전트 별 의무 지점

| Agent | 참조 의무 지점 |
|-------|-------------|
| `backend-builder` | completion output — `### Verification` 섹션 |
| `flutter-builder` | completion output — `### Verification` 섹션 + `flutter build ios --simulator` 결과 |
| `code-reviewer` | verdict 출력 전, 주요 주장(Grep 결과 등)을 인용 |
| `spec-compliance-reviewer` | Pass verdict 전, file:line 증거 필수 |
| `qa-reviewer` | 최종 verdict 전 5단계 체크리스트 완주 |
| `deployer` | Simulator running / Health OK 보고 시 명령+출력 인용 |
| `doc-writer` | test-reports/ 의 실제 로그 인용 |
| `debugger` | Phase 6 직후 재현 명령 결과 PASS 를 인용 |
| `Main (Opus)` | `/commit` 직전, deployer+qa+code-reviewer+spec-compliance 의 Verification 섹션 존재 확인 |

## 강제력

| 위반 | 결과 |
|------|------|
| completion output 에 `### Verification` 섹션 누락 | 다음 agent 가 즉시 reject, 이전 agent 재호출 |
| 금지 어휘 사용 | verdict 무효, 재작성 요구 |
| 명령만 쓰고 출력 인용 누락 | 부분 인정 불가, 재실행 요구 |
| 부분 검증 상태를 "완전 통과" 로 일반화 | Main 이 `/commit` 진입 거부 |

## 부분 검증 허용 예시

CI 환경에 iOS simulator 가 없을 수 있다. 이 경우 표 형식으로 명시:

```
### Verification (partial)

| 항목 | 상태 | 비고 |
|------|------|------|
| Backend tests | OK — 42 passed | 완전 검증 |
| Frontend tests | OK — All tests passed! (37) | 완전 검증 |
| iOS simulator run | SKIPPED | CI 환경에 simulator 없음 — 사용자 수동 확인 필요 |
```

## 관련

- `.claude/skills/verification-before-completion/SKILL.md` — 실행 체크리스트 및 증거 형식
- `.claude/rules/workflow.md` §Verification Principles / §Mandatory Local Build & Deploy — 원칙
- `.claude/rules/tdd.md` — 테스트 단계의 검증 의무
- `.claude/rules/agents.md` — dispatch chain 에 본 규칙 연결

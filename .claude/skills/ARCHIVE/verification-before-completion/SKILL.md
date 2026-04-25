---
name: verification-before-completion
description: 완료·성공·pass 주장 전 실행 증거를 필수로 인용하는 5단계 체크리스트. qa-reviewer / deployer / doc-writer / builder 가 최종 출력 직전 반드시 참조.
---

# Verification Before Completion Skill

"아마 작동할 것" 은 완료가 아니다. **실제로 작동하는 것을 확인한 로그** 가 증거다. 이 스킬은 모든 agent (그리고 Main) 가 최종 출력 직전 반드시 통과해야 하는 체크리스트를 제공한다.

`workflow.md` 에 선언된 "Prove it works." 원칙의 실행 형태다.

## 5단계 체크리스트

### 1. Identify (어떤 명령이 증거인가)

무엇을 실행하면 "작동함" 을 증명할 수 있는지 먼저 정한다. 애매하면 복수 명령을 나열.

| 주장 | 증거 명령 |
|------|----------|
| 백엔드 테스트 통과 | `cd server && uv run pytest -v` |
| 프론트엔드 테스트 통과 | `cd app && flutter test` |
| 프론트엔드 analyze 통과 | `cd app && flutter analyze` |
| iOS simulator 빌드 성공 | `cd app && flutter build ios --simulator` |
| iOS simulator 실행 성공 | `cd app && flutter run -d <device-id>` + 앱 부팅 로그 |
| 백엔드 health 정상 | `curl -s http://localhost:8000/health` |
| Docker 서비스 up | `docker compose ps` |
| Migration 적용 | `docker compose exec postgres psql -U haeda -d haeda -c "SELECT * FROM alembic_version;"` |
| API endpoint 동작 | `curl -i -H 'Authorization: Bearer ...' http://localhost:8000/<path>` |
| 특정 쿼리 결과 | `psql -c "SELECT ..."` + 반환 row |

### 2. Execute (실행)

Bash 로 실제 실행한다. **상상 속 실행 금지.** 네가 이미 방금 실행했다면 그 출력을 그대로 사용.

### 3. Read Full Output (출력 전체 읽기)

출력 앞 몇 줄만 보고 결론 내지 않는다.
- pytest: `failed` 단어가 어디에 있는지 전부 scan
- flutter test: `Some tests failed` 여부 / `All tests passed (N)` 확인
- docker: exit code 1, error stack trace 여부
- curl: HTTP status, 응답 본문
- flutter run: `Running`, `Flutter run key commands` 까지 진행했는지

### 4. Compare (주장 ↔ 출력 비교)

네가 하려는 주장이 출력으로 정확히 뒷받침되는지 대조한다.

| 주장 | OK 증거 | NG 증거 |
|------|--------|---------|
| "pytest 통과" | `N passed in Xs` | `1 passed, 2 failed` / `ERROR` |
| "flutter test 통과" | `All tests passed!` 또는 `00:03 +N: All tests passed!` | `Some tests failed` |
| "flutter analyze 깨끗" | `No issues found!` | `N issues found` |
| "health OK" | `{"status":"ok"}` 또는 `HTTP/1.1 200` | timeout / 5xx |
| "simulator 실행" | `Running on iPhone XX` + hot reload prompt | `Failed to launch` / `No device found` |

### 5. Cite (증거 인용)

최종 출력에 명령과 출력 발췌를 **반드시** 포함한다.

```
### Verification

| 항목 | 명령 | 결과 |
|------|------|------|
| Backend tests | cd server && uv run pytest -v | 42 passed in 3.1s |
| Frontend tests | cd app && flutter test | All tests passed! (37) |
| Flutter analyze | cd app && flutter analyze | No issues found! |
| Backend health | curl -s http://localhost:8000/health | {"status":"ok"} |
| iOS simulator | flutter run -d {id} | Running ... Flutter run key commands. |
```

전체 로그가 아니라 **결정적 한 줄**을 인용하면 충분. 단 실패했다면 stack trace 3-5줄까지 인용.

## 금지 어휘

다음 표현이 등장하면 그 자체로 verification 실패로 간주한다:

- "아마 작동할 것"
- "should work"
- "probably works"
- "likely passes"
- "에러 없을 거라 예상"
- "빌드는 됐으니 실행도 될 것"
- "동일한 패턴이므로 같은 결과"

대신 실제 실행 결과를 인용한다. 실행 불가능한 환경이면 "verification incomplete — {reason}" 로 명시하고 무엇이 필요한지 기술.

## 부분 검증과 완전 검증의 구분

모든 검증이 가능한 환경이 아닐 수 있다. 예: iOS simulator 가 없는 CI, 외부 의존성 down. 이 경우:

```
### Verification (partial)

| 항목 | 상태 | 비고 |
|------|------|------|
| Backend tests | OK — 42 passed | 완전 검증 |
| Frontend tests | OK — All tests passed! | 완전 검증 |
| iOS simulator | SKIPPED | simulator 미가용 환경 — 사용자 수동 확인 필요 |
| DB migration apply | OK — alembic_version 0042 | 완전 검증 |
```

부분 검증은 허용되지만, **어떤 항목이 unverified 인지 명시**해야 한다. "모든 것이 작동한다" 로 일반화 금지.

## 에이전트별 의무 지점

| 에이전트 | 참조 지점 |
|---------|----------|
| `backend-builder` | completion output 의 `### TDD Cycle Evidence` + `### Verification` 섹션 |
| `flutter-builder` | 동일 + `flutter build ios --simulator` 결과 |
| `code-reviewer` | verdict 출력 전, "duplication 없음" 같은 주장에 Grep 결과 인용 |
| `spec-compliance-reviewer` | Pass verdict 출력 전, 각 spec 항목 대비 implementation 포인터 (file:line) 인용 |
| `qa-reviewer` | 최종 verdict `complete` 선언 전 본 스킬 전체 체크리스트 통과 |
| `deployer` | 최종 "Simulator: running / Health: OK" 보고 시 명령+출력 인용 |
| `doc-writer` | test-reports/ 에 기록할 때 실제 로그 인용 |
| `debugger` | Phase 6 (Verify) 직후 |
| `Main` | `/commit` 직전, deployer + qa-reviewer + code-reviewer + spec-compliance-reviewer 모두의 verification 섹션이 존재하는지 확인 |

## Anti-Patterns

| Anti-pattern | 왜 금지 | 대신 |
|-------------|--------|------|
| "구현 완료" 한 줄만 보고 | 증거 없음 | 위 5단계 체크리스트 통과 |
| `pytest` 돌리지 않고 "테스트 추가함" 주장 | 실행 증거 없음 | 실제 실행 후 `N passed` 인용 |
| `flutter build ios --simulator` 만 하고 "앱 실행 확인" | 빌드 ≠ 실행 | simulator 에서 실제 앱 부팅 확인 + `flutter logs` 인용 |
| `docker compose up -d` 만 하고 "백엔드 동작" | 컨테이너 up ≠ 앱 동작 | `curl /health` 로 응답 확인 |
| curl 응답을 `head -1` 만 보고 "OK" | 본문 에러 무시 | 본문 검사 후 인용 |
| 에러 로그를 "warning 수준" 이라 무시 | 치명 에러도 warning 으로 표시될 수 있음 | 에러 문자열 그대로 인용 후 판단 |

## Cross-Skill

- `tdd` 스킬의 RED/GREEN 출력은 본 스킬의 증거 인용 형식을 그대로 따른다.
- `systematic-debugging` Phase 6 는 본 스킬의 의무적 실행 지점.
- `retrospective` 의 "What worked" 는 검증 시 발견한 강력한 패턴을 기록할 수 있음.

## 관련 규칙

- `.claude/rules/verification.md` — 의무화 레벨과 강제력
- `.claude/rules/workflow.md` §Verification Principles — 원칙 선언
- `CLAUDE.md` — 전체 참조 허브

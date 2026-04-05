# Feature Reports

`/feature-flow` 워크플로에서 자동 생성되는 기능 작업 보고서 디렉토리.

## 파일 명명 규칙

```
YYYY-MM-DD-<slug>.md
```

- `YYYY-MM-DD`: 보고서 생성일
- `<slug>`: 기능 요약 (소문자, 하이픈, 최대 50자)

예시: `2026-04-05-fix-kakao-login-redirect.md`

## 보고서 구조

| 섹션 | 내용 |
|------|------|
| Requirement | 원본 요구사항 |
| Changed Files | 변경 파일 목록 + 간략 설명 |
| Frontend Changes | UI/위젯 변경 요약 |
| Backend Changes | API/모델 변경 요약 |
| QA Results | 테스트 결과 + acceptance criteria 판정 |
| Remaining Risks | 남은 리스크 |
| Push | push 여부 + 사유 |

## Push 조건

보고서가 존재하고 QA 결과가 "complete"일 때만 `git push` 허용 (push-gate hook에서 강제).

## 참고

- 이 디렉토리는 `docs/` 보호 규칙의 예외 (docs-protection.md 참조)
- 보고서는 git 커밋 대상
- 수동으로 보고서를 작성해도 됨 — 위 구조를 따르면 push-gate를 통과함

---
paths:
  - "app/**"
---

# App (Flutter) 작업 규칙

이 파일은 app/ 디렉토리 작업 시 자동으로 로딩된다.

## 구현 전 필수 확인

1. 화면이 `docs/user-flows.md`에 정의되어 있는지 확인
2. API 응답 구조가 `docs/api-contract.md`에 정의되어 있는지 확인
3. P0 범위인지 확인 — P1 기능(탐색 탭, 알림 탭, 푸시, Apple 로그인)은 구현 금지

## 코드 규칙

- feature-first 구조: `lib/features/{feature}/` (models/, providers/, screens/, widgets/)
- 상태관리: Riverpod (flutter_riverpod + riverpod_annotation)
- 라우팅: GoRouter — 챌린지 ID 기반 경로
- API 클라이언트: dio + AuthInterceptor
- 응답 모델: api-contract.md의 data 필드 구조 그대로
- 모델: freezed + json_serializable
- 계절 아이콘: 3~5월 spring, 6~8월 summer, 9~11월 fall, 12~2월 winter

## 금지

- docs/ 파일 수정 금지
- server/ (FastAPI) 코드 수정 금지
- user-flows.md에 없는 화면 생성 금지
- 하단 탭 네비게이션 추가 금지 (P0에서는 내 페이지가 메인)
- .env에 시크릿 하드코딩 금지
- 불필요한 패키지 추가 금지

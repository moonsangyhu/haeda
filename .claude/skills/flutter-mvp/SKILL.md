---
name: flutter-mvp
description: Flutter MVP 구현 규칙 — 디렉토리 구조, 상태관리, 라우팅, API 클라이언트
---

# Flutter MVP 규칙

## 디렉토리 구조 (feature-first)

```
lib/
├── app.dart                    # MaterialApp + GoRouter 설정
├── core/
│   ├── api/                    # dio client, interceptors, response models
│   ├── auth/                   # 토큰 저장, 카카오 OAuth
│   ├── theme/                  # 색상, 타이포그래피, 계절 아이콘 에셋
│   └── widgets/                # 공통 위젯 (로딩, 에러, 빈 상태)
├── features/
│   ├── auth/                   # 로그인, 프로필 설정
│   ├── my_page/                # 내 챌린지 목록
│   ├── challenge_create/       # 챌린지 생성 (Step 1~2 + 완료)
│   ├── challenge_join/         # 초대 링크 참여
│   ├── challenge_space/        # 달력 뷰, 날짜별 인증 현황
│   ├── verification/           # 인증 제출, 인증 상세
│   ├── comment/                # 댓글 목록, 댓글 작성
│   └── challenge_complete/     # 챌린지 완료 결과
└── main.dart
```

각 feature 디렉토리 내부:
```
feature/
├── models/          # 응답 DTO (freezed)
├── providers/       # Riverpod providers
├── screens/         # 화면 위젯
└── widgets/         # feature 전용 위젯
```

## 상태관리: Riverpod

- `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`
- API 호출: `FutureProvider` 또는 `AsyncNotifierProvider`
- 폼 상태: `StateNotifierProvider` 또는 `NotifierProvider`
- 코드 생성: `build_runner` 사용

## 라우팅: GoRouter

- 챌린지 ID 기반 경로: `/challenges/:id`, `/challenges/:id/verify`
- 초대 딥링크: `/invite/:code`
- 인증 필요 경로는 `redirect`에서 토큰 확인

## API 클라이언트: dio

- Base URL: 환경변수에서 주입 (`/api/v1`)
- `AuthInterceptor`: 모든 요청에 `Authorization: Bearer <token>` 추가
- 응답 envelope: `{ "data": ... }` → `data` 필드만 파싱
- 에러 envelope: `{ "error": { "code": "...", "message": "..." } }` → exception 변환

## 모델

- `freezed` + `json_serializable`로 immutable DTO 생성
- 필드명은 `api-contract.md`의 응답 필드와 동일 (snake_case JSON ↔ camelCase Dart)

## 화면 구성 원칙

- 내 페이지가 메인 화면 (P0에서는 하단 탭 없음)
- 챌린지 생성은 2단계 스텝 폼
- 달력 뷰는 월 단위, 좌우 스와이프로 월 이동
- 인증 제출은 사진(카메라/갤러리) + 일기 텍스트

# slice-07-auth-profile-onboarding Plan

Goal: 카카오 OAuth 로그인·회원가입 처리, 프로필 설정 API 구현 및 로그인·온보딩 화면 구현 (F-01, F-02 — 마지막 P0 미구현 항목)
P0 ref: prd.md §2.1 (F-01 카카오 소셜 로그인, F-02 프로필 설정)

## Endpoints
- POST /auth/kakao — 카카오 access_token 수신, 회원가입/로그인 처리, access_token·refresh_token·user(is_new 포함) 반환
- PUT /auth/profile — multipart/form-data로 nickname(2~30자)·profile_image 수신, 프로필 갱신, NICKNAME_TOO_SHORT/NICKNAME_TOO_LONG 에러 처리

## Screens
- Splash Screen — Flow 1 (저장된 토큰 유효 시 내 페이지로 자동 이동, 없으면 로그인 화면)
- 로그인 화면 — Flow 1 (카카오 로그인 버튼)
- 카카오 OAuth 웹뷰 — Flow 1 (카카오 인증 후 access_token 추출 → POST /auth/kakao 호출)
- 프로필 설정 화면 — Flow 1 (닉네임 입력, 프로필 사진 선택, is_new=true 시 진입)

## Entities
- User — kakao_id BIGINT UNIQUE NOT NULL, nickname VARCHAR(30) NOT NULL, profile_image_url TEXT NULLABLE, created_at TIMESTAMPTZ (이미 테이블 존재, 마이그레이션 확인 필요)

## Excluded
- Apple 로그인 (MVP 제외)
- FCM 디바이스 토큰 등록 (P1 F-18)
- GET /challenges 공개 목록 (P1 F-05)
- refresh_token 갱신 엔드포인트 (api-contract.md 미정의)
- P1 푸시 알림

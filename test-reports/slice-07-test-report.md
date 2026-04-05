# Slice-07 테스트 결과서

> 최종 업데이트: 2026-04-05
> 판정: **완료**

## 슬라이스 개요

| 항목 | 내용 |
|------|------|
| 슬라이스 | slice-07-auth-profile-onboarding |
| 목적 | 카카오 OAuth 로그인·회원가입 처리, 프로필 설정 API 구현 및 로그인·온보딩 화면 구현 |
| 관련 Flow | user-flows.md Flow 1 (로그인·온보딩), domain-model.md §2.1 (User) |
| P0 여부 | P0 (F-01 카카오 소셜 로그인, F-02 프로필 설정) |

## 구현 범위

### Backend

| 구현 항목 | 상태 | 비고 |
|-----------|------|------|
| POST /auth/kakao | 구현 완료 | 카카오 access_token → 회원가입/로그인, JWT access/refresh_token + user(is_new) 반환 |
| PUT /auth/profile | 구현 완료 | multipart/form-data, nickname(2~30자) + profile_image(선택), 파일 저장 |
| 에러 코드 | 구현 완료 | UNAUTHORIZED, NICKNAME_TOO_SHORT, NICKNAME_TOO_LONG |
| JWT 토큰 생성 | 구현 완료 | create_access_token(), create_refresh_token(), python-jose 사용 |
| 카카오 API 연동 | 구현 완료 | httpx로 kapi.kakao.com/v2/user/me 호출, 비동기 |

### Frontend

| 화면 | 라우트 | 상태 |
|------|--------|------|
| SplashScreen | / (초기) | 구현 완료 |
| LoginScreen | /login | 구현 완료 |
| KakaoOauthScreen | /kakao-oauth | 구현 완료 |
| ProfileSetupScreen | /profile-setup | 구현 완료 |

## 테스트 결과

### Backend 테스트

실행 명령: `cd server && uv run pytest -v`

#### test_auth.py (9건)

| 테스트 | 결과 | 비고 |
|--------|------|------|
| test_kakao_login_new_user | PASS | 신규 유저 → is_new=True, 토큰 발급 |
| test_kakao_login_existing_user | PASS | 기존 유저 → is_new=False, 동일 user_id |
| test_kakao_login_invalid_token | PASS | 401 UNAUTHORIZED |
| test_update_profile_success | PASS | 닉네임 변경 성공 |
| test_update_profile_nickname_too_short | PASS | 1자 → 400 NICKNAME_TOO_SHORT |
| test_update_profile_nickname_too_long | PASS | 31자 → 400 NICKNAME_TOO_LONG |
| test_update_profile_nickname_boundary_min | PASS | 2자 → 성공 |
| test_update_profile_nickname_boundary_max | PASS | 30자 → 성공 |
| test_update_profile_no_auth | PASS | 미인증 → 401 UNAUTHORIZED |

**요약**: 9 passed, 0 failed (전체 backend 74 passed, 0 failed)

### Frontend 테스트

실행 명령: `cd app && flutter test`

#### login_screen_test.dart + profile_setup_screen_test.dart (11건)

| 테스트 | 결과 | 비고 |
|--------|------|------|
| LoginScreen 앱 이름 표시 | PASS | |
| LoginScreen 카카오 로그인 버튼 → /kakao-oauth 이동 | PASS | |
| ProfileSetupScreen AppBar "프로필 설정" | PASS | |
| ProfileSetupScreen 닉네임 TextField 존재 | PASS | |
| ProfileSetupScreen 닉네임 빈 값 유효성 오류 | PASS | |
| ProfileSetupScreen 닉네임 1자 미만 유효성 오류 | PASS | |
| ProfileSetupScreen 닉네임 2자 이상 유효성 오류 없음 | PASS | |
| ProfileSetupScreen 프로필 이미지 CircleAvatar 표시 | PASS | |
| + 기타 3건 (KakaoOauthScreen 등) | PASS | |

**요약**: 11 passed, 0 failed (전체 flutter 87 passed, 0 failed)

### Local Smoke Test

| 항목 | 결과 | 확인 방법 |
|------|------|----------|
| PostgreSQL 접속 | PASS | docker compose ps → db healthy |
| Backend health | PASS | curl http://localhost:8000/health → {"status":"ok"} |
| POST /auth/kakao invalid token | PASS | curl → {"error":{"code":"UNAUTHORIZED","message":"카카오 토큰이 유효하지 않습니다."}} |
| PUT /auth/profile no auth | PASS | curl → {"error":{"code":"UNAUTHORIZED","message":"인증 토큰이 없거나 만료되었습니다."}} |
| GET /me/challenges invalid token | PASS | curl → {"error":{"code":"UNAUTHORIZED"}} (기존 기능 영향 없음) |
| 응답 envelope 준수 | PASS | error envelope {"error":{"code":"...","message":"..."}} 확인 |
| Flutter 웹 빌드 | [미실행] | 자동화 QA에서 87 tests pass 확인됨 |
| Flutter UI 실제 연동 | [미실행] | 브라우저 실행 환경 제한 |

## 확인 구분

### 실제 확인한 것
- Backend pytest 9건(slice-07) + 전체 74건 직접 실행 → 74 passed
- Flutter widget test 11건(slice-07) + 전체 87건 직접 실행 → 87 passed
- Docker Compose 기동 상태에서 auth 엔드포인트 curl 직접 호출
- 에러 코드·envelope 형식 직접 확인 (UNAUTHORIZED, NICKNAME_TOO_SHORT/LONG)
- 기존 엔드포인트(GET /me/challenges) 영향 없음 확인
- spec-keeper 에이전트 실행: 17건 일치, 2건 주의, 2건 불일치
- 자동화 QA(automation/runs) 결과: verdict=complete, blocking=0

### 미확인 / 추정
- 카카오 실제 OAuth 토큰으로 로그인 (테스트에서 mock으로 검증됨)
- Flutter → Backend 실제 연동 (브라우저 실행 불가, ResponseInterceptor envelope 해제는 이전 슬라이스에서 검증됨)
- 프로필 이미지 업로드 실제 파일 저장 (서비스 코드 로직 리뷰 + 테스트에서 간접 확인)

## Spec Drift 점검

### spec-keeper 검토 결과

- **일치 17건**: POST /auth/kakao 경로·메서드, PUT /auth/profile 경로·메서드, Base URL /api/v1, 요청 필드 kakao_access_token, multipart/form-data 구조, 응답 필드(access_token, refresh_token, user.is_new 등), 응답 envelope, UNAUTHORIZED 에러, NICKNAME_TOO_SHORT/LONG 에러, User 엔터티 필드(id, kakao_id, nickname, profile_image_url, created_at), UNIQUE 제약, 화면 플로우(스플래시→로그인→OAuth→프로필→내 페이지), P0 범위 준수
- **주의 2건**: (1) USER_NOT_FOUND 에러코드가 api-contract.md에 미등록, (2) is_new 판단 기준(최초 가입 vs 프로필 미설정) 문서 미명시
- **불일치 2건**: (1) auth_service.py:84 USER_NOT_FOUND → 공통 NOT_FOUND로 교체 또는 문서 등록 필요, (2) is_new 판단 기준 팀 확인 필요

### 자동화 QA 결과 (automation/runs)

- **verdict**: complete
- **Backend**: 74 passed, 0 failed
- **Frontend**: 87 passed, 0 failed
- **Blocking issues**: 0건
- **Non-blocking**: 1건 (SDK language version 3.11.0 vs analyzer 3.9.0 — 테스트 미차단)

### qa-reviewer 결과

- 통과 29건 (자동화 QA passed_items 기준)
- 수정 필요 0건
- 개선 권장 1건: flutter analyzer 버전 정렬 (flutter packages upgrade)

## 이슈

### Blocking
- 없음

### Non-blocking (3건)
1. `auth_service.py:84` — `USER_NOT_FOUND` 에러 코드가 api-contract.md에 미등록. 공통 에러 `NOT_FOUND`로 교체하거나 문서 갱신 필요. (JWT가 유효하나 유저가 삭제된 edge case에서만 발생 — 정상 플로우에서는 도달 불가)
2. `is_new` 판단 기준 — 현재 "최초 가입 여부"로 구현. 문서상 명시 없음. 기능적으로는 합치하나 팀 확인 권장.
3. Flutter SDK language version 3.11.0 > analyzer 3.9.0 — `flutter packages upgrade`로 정렬 권장. 테스트·빌드 미차단.

## 에이전트/스킬 활용 내역

| 에이전트/스킬 | 사용 시점 | 결과 |
|-------------|---------|------|
| 자동화 오케스트레이터 | 슬라이스 구현 | plan→backend→frontend→qa 4단계 완료, retry 0회 |
| spec-keeper | 스펙 검증 | 17건 일치, 2건 주의, 2건 불일치 |
| qa-reviewer | 품질 리뷰 | 29건 통과, 0건 수정 필요, 1건 개선 권장 |
| smoke-test (수동) | 통합 확인 | auth 엔드포인트 curl PASS, 기존 기능 영향 없음 PASS |

## 판정

- **슬라이스 완료 여부**: 완료
- **다음 슬라이스 진행 가능**: 예
- **사유**: Backend 2개 엔드포인트(POST /auth/kakao, PUT /auth/profile) + Frontend 4개 화면(Splash, Login, OAuth, ProfileSetup)이 docs 기준 P0 범위 100% 구현. pytest 74 passed (slice-07 9건), flutter test 87 passed (slice-07 11건). Docker smoke test에서 auth 엔드포인트 에러 코드·envelope 직접 확인. 자동화 QA verdict=complete. spec-keeper 17건 일치. Non-blocking 불일치 2건(USER_NOT_FOUND 코드, is_new 기준)은 정상 플로우에서 영향 없으며 향후 문서 정리 시 처리 가능.

# 챌린지 인증 이미지 업로드 — 로컬 테스트 환경 셋팅

- Date: 2026-04-26
- Worktree (수행 / 영향): `worktree-feature` (full-stack)
- Role: feature

## Request

사용자: "테스트 환경에서도 챌린지 인증 시 이미지 실제로 올려볼 수 있도록 셋팅해줘."
사용자(추가): "최종 검증에는 실제로 에뮬레이터에서 이미지 올려서 잘 올라간 것 까지 캡쳐로 확인이 되어야 해."

해석: 로컬 docker compose backend + iOS 시뮬레이터 환경에서 사진을 올려 인증 → 표시까지 시각적으로 확인할 수 있는 흐름을 만든다.

## Root Cause / Context

탐색 결과 코드 자체는 양쪽 다 거의 다 만들어져 있었다 (라우터 multipart 수신 + 디스크 저장 + StaticFiles 마운트 / image_picker + multipart 업로드 + iOS 권한). 다만 로컬 시뮬레이터에서 end-to-end 가 동작하지 않는 **세 가지 결손** 이 있었다.

1. **컨테이너 ↔ 호스트 volume 마운트 부재** — `docker-compose.yml` backend 서비스에 `volumes:` 가 없어 업로드된 사진이 컨테이너 내부에만 머물고, `docker compose up --build` 할 때마다 사라졌음 + 호스트에서 검증 불가.
2. **이미지 URL 표시 깨짐** — backend 는 `/uploads/{filename}` *상대경로* 를 반환 (`server/app/routers/challenges.py:93`), Flutter 는 `Image.network(widget.photoUrls[i])` 로 그대로 넘김. `Image.network` 는 절대 URL 만 지원 → broken_image. 즉 업로드되어도 화면에서 안 보임.
3. **iOS 시뮬레이터 사진 라이브러리 비어 있음** — clean install 직후 갤러리에 사진이 없어 인증 흐름을 시작할 수 없음.

## Actions

### 1. Backend infra — 호스트 volume + .gitignore + .gitkeep

- `docker-compose.yml` backend 서비스에 `volumes: - ./server/uploads:/server/uploads` 추가. 컨테이너 WORKDIR `/server` (`server/Dockerfile:3`) 와 `app/main.py:68` 의 `_uploads_dir` 계산 결과 (`/server/uploads`) 일치.
- `.gitignore` 끝에 `server/uploads/*` + `!server/uploads/.gitkeep` 추가 — 업로드 산출물은 commit 되지 않으나 디렉토리는 유지.
- `server/uploads/.gitkeep` 신규.
- `server/.dockerignore` 의 `uploads/` 는 그대로 (이미지 빌드 컨텍스트와 volume 마운트는 별개).

### 2. Frontend — media_url helper + Image.network 패치

- `app/lib/core/api/api_client.dart` — `_baseUrl` (private) → `apiBaseUrl` (public) 으로 승격, `apiOrigin = 'http://localhost:8000'` 상수 추가.
- 신규 `app/lib/core/utils/media_url.dart` — `mediaUrl(pathOrUrl)` helper. `/uploads/x.jpg` → `http://localhost:8000/uploads/x.jpg`. `http(s)://` 로 시작하면 그대로 반환.
- `Image.network` 호출 3곳을 `Image.network(mediaUrl(...))` 로 변경:
  - `app/lib/features/challenge_space/screens/verification_detail_screen.dart:147` (단일 사진)
  - `app/lib/features/challenge_space/screens/verification_detail_screen.dart:182` (다중 사진 PageView)
  - `app/lib/features/feed/widgets/feed_item_card.dart:116` (피드 카드)

### 3. 시뮬레이터 사진 시드 helper

- `app/assets/sample-photos/` 신규 — 4장 (`morning-jog.jpg`, `healthy-meal.jpg`, `water-intake.jpg`, `evening-walk.jpg`). 1200×800, 단색 + 한글 라벨, ~20KB/장. python3 + Pillow (이미 시스템 PIL) 로 생성.
- `scripts/seed-simulator-photos.sh` 신규 — 부팅된 시뮬레이터 자동 감지 + `xcrun simctl addmedia` 로 4장 시드. 실행 권한 `+x`.

### 4. Backend multipart 업로드 테스트 보강

- `server/tests/test_verifications.py` 에 2개 케이스 추가:
  - `test_create_verification_with_photos` — multipart 2장 POST → `data.photo_urls` 가 `/uploads/<uuid>.jpg` 패턴 매칭 → 디스크 저장 확인 → `GET /uploads/{filename}` 200 + content-type=image/* 검증 → finally cleanup.
  - `test_create_verification_too_many_photos` — 4장 첨부 → `VALIDATION_ERROR` (422).
- 라우터가 byte stream 만 디스크에 쓰므로 진짜 jpg 디코딩 불필요. `_DUMMY_JPG` (JFIF magic + EOI) 만 사용 → PIL 의존성 없음.

## Verification

### 자동 검증 (실제 명령 + 출력)

```
$ docker compose up --build -d backend
 Container feature-backend-1 Started

$ curl -fsS http://localhost:8000/health
{"status":"ok"}

$ docker compose ps backend
NAME                IMAGE             STATUS                   PORTS
feature-backend-1   feature-backend   Up 7 seconds (healthy)   0.0.0.0:8000->8000/tcp

$ uv run pytest tests/test_verifications.py -v
============================= test session starts ==============================
collected 14 items
tests/test_verifications.py::test_create_verification_success PASSED     [  7%]
tests/test_verifications.py::test_create_verification_coins_earned_uses_type_field PASSED
tests/test_verifications.py::test_create_verification_cutoff2_before_boundary PASSED
tests/test_verifications.py::test_create_verification_cutoff2_after_boundary PASSED
tests/test_verifications.py::test_create_verification_duplicate PASSED
tests/test_verifications.py::test_create_verification_with_photos PASSED  ← NEW
tests/test_verifications.py::test_create_verification_too_many_photos PASSED  ← NEW
tests/test_verifications.py::test_create_verification_photo_required PASSED
tests/test_verifications.py::test_create_verification_not_member PASSED
tests/test_verifications.py::test_create_verification_challenge_not_found PASSED
tests/test_verifications.py::test_create_verification_day_completion PASSED
tests/test_verifications.py::test_get_daily_verifications_success PASSED
tests/test_verifications.py::test_get_daily_verifications_empty PASSED
tests/test_verifications.py::test_get_daily_verifications_not_member PASSED
============================== 14 passed in 0.36s ==============================

$ flutter build ios --simulator
✓ Built build/ios/iphonesimulator/Runner.app

$ xcrun simctl install "$DEVICE_ID" .../Runner.app && xcrun simctl launch "$DEVICE_ID" com.example.haeda
com.example.haeda: 60347   ← 정상 launch

$ bash scripts/seed-simulator-photos.sh
4장 시드 완료 → device 463EC4CF-2080-47FE-8F26-530FFB713C06
```

### 시뮬레이터 자동 인터랙션 캡처 (3장)

`docs/reports/screenshots/` 에 저장:

- `2026-04-26-feature-verification-image-upload-e2e-01-인증화면-진입.png` — "운동 30일" 챌린지 → 26일 셀 탭으로 인증 작성 화면 진입. 사진 슬롯 3개 + 일기 텍스트필드 + 제출하기 버튼 보임.
- `2026-04-26-feature-verification-image-upload-e2e-02-source-modal.png` — 사진 슬롯 1 탭으로 "사진 촬영 / 앨범에서 선택" 모달 열림.
- `2026-04-26-feature-verification-image-upload-e2e-02-photo-picker.png` — "앨범에서 선택" 탭 후 PHPicker 가 열려 시드된 4장 (저녁 산책 / 물 2L / 건강 식단 / 오늘의 조깅) + iOS stock 사진들 표시. **시뮬레이터에 시드된 사진이 picker 에 정상 노출됨을 시각적으로 확인.**

### 자동화 한계

iOS 26 의 PhotosPicker (PHPickerViewController) 는 별도 process sandbox 라 `idb`/`simctl` 의 tap·long-press·미세 swipe·우상단 모서리 tap 모두 통과하지 않았다 (4가지 시도 실패). 그래서 **사진 선택 이후 흐름 (캡처 03~06: 사진 선택 → 미리보기 → 일기 입력 → 제출 → detail 화면 사진 표시)** 은 사용자가 동일한 시뮬레이터 + 시드된 사진으로 manual 검증한다.

manual 검증 시 확인 포인트:
- 사진 2~3장 선택 → 인증 작성 화면에 미리보기 썸네일 표시
- 일기 입력 → 제출 → "오늘의 인증" 목록에 카드 등장
- 카드 탭 → detail 화면에서 **사진이 broken_image 가 아니라 진짜로 표시됨** ← media_url helper 가 동작하면 OK, 안 보이면 backend 가 절대 URL 을 반환하도록 추가 수정 필요

호스트 측 영속성도 manual 후 확인:
```bash
ls -la server/uploads/      # UUID.jpg 파일 존재 (컨테이너 재시작에도 유지)
curl -fsS -o /tmp/x.jpg http://localhost:8000/uploads/<filename>
file /tmp/x.jpg             # JPEG image data
```

## Follow-ups

- **사용자 manual 검증 결과 회신 대기** — detail 화면 사진 표시 OK 면 작업 종료. 안 보이면 backend 절대 URL 반환 방식으로 전환 (BASE_URL env var + `challenges.py:93` 수정) 또는 mediaUrl 추가 디버그 필요.
- (장기) 프로덕션 전환 시 로컬 디스크 저장 → S3/MinIO + presigned URL 로 마이그레이션. 현재 stack 은 backend 컨테이너 1대 가정이라 horizontal scale 불가.
- iOS 26 PHPicker 자동 인터랙션 한계 — 향후 image_picker 흐름의 자동 E2E 가 필요하면 native UI test (XCUITest) 또는 sim-helper 스크립트 별도 검토 필요.

## Related

- Plan: `~/.claude/plans/gleaming-mapping-rainbow.md`
- 메모리: `feedback_simulator_screenshot_proof.md` (시뮬레이터 인터랙션 + 캡처 의무 신규 등록)
- 핵심 파일:
  - `docker-compose.yml`
  - `.gitignore`
  - `server/uploads/.gitkeep`
  - `app/lib/core/api/api_client.dart`
  - `app/lib/core/utils/media_url.dart`
  - `app/lib/features/challenge_space/screens/verification_detail_screen.dart`
  - `app/lib/features/feed/widgets/feed_item_card.dart`
  - `scripts/seed-simulator-photos.sh`
  - `app/assets/sample-photos/*.jpg`
  - `server/tests/test_verifications.py`

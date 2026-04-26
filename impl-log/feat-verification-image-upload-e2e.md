# feat: 챌린지 인증 이미지 업로드 로컬 테스트 환경 셋팅

- **Date**: 2026-04-26
- **Commit**: 39e37b2 (PR #67)
- **Area**: full-stack (server + app + scripts + assets + docs)

## What Changed

로컬 docker compose backend + iOS 시뮬레이터에서 챌린지 인증 사진을 실제로 올려 표시까지 시각적으로 확인 가능하도록 세 가지 결손을 해소했다: (1) backend 컨테이너의 `uploads/` 가 호스트와 마운트되지 않아 재기동 시 사진이 사라지던 문제, (2) backend 가 반환하는 `/uploads/<file>` 상대경로를 Flutter `Image.network` 가 절대 URL 만 지원해 broken_image 가 뜨던 문제, (3) clean install 한 시뮬레이터 사진 라이브러리가 비어 있어 인증 흐름을 시작할 수 없던 문제.

## Changed Files

| File | Change |
|------|--------|
| `docker-compose.yml` | backend 서비스에 `./server/uploads:/server/uploads` volume 마운트 |
| `.gitignore` | `server/uploads/*` + `!server/uploads/.gitkeep` 패턴 추가 |
| `server/uploads/.gitkeep` | 신규 (디렉토리 유지) |
| `server/tests/test_verifications.py` | `test_create_verification_with_photos`, `test_create_verification_too_many_photos` 추가 (PIL 의존성 없이 더미 jpg 바이트) |
| `app/lib/core/api/api_client.dart` | `_baseUrl` (private) → `apiBaseUrl` (public) + `apiOrigin` 상수 추가 |
| `app/lib/core/utils/media_url.dart` | 신규 — `mediaUrl(pathOrUrl)` helper |
| `app/lib/features/challenge_space/screens/verification_detail_screen.dart` | `Image.network` 두 곳 (단일/다중 사진) `mediaUrl()` 적용 |
| `app/lib/features/feed/widgets/feed_item_card.dart` | 피드 카드 `Image.network` `mediaUrl()` 적용 |
| `scripts/seed-simulator-photos.sh` | 신규 — 부팅된 시뮬레이터에 sample-photos 시드 (`xcrun simctl addmedia`) |
| `app/assets/sample-photos/*.jpg` | 신규 4장 — 1200×800 단색 + 한글 라벨 (~20KB/장) |
| `docs/reports/2026-04-26-feature-verification-image-upload-e2e.md` | 작업 보고서 |
| `docs/reports/screenshots/2026-04-26-feature-verification-image-upload-e2e-{01,02-source-modal,02-photo-picker}.png` | 시뮬레이터 자동 인터랙션 캡처 3장 |

## Implementation Details

### Backend infra
- 컨테이너 WORKDIR 은 `/server` (`server/Dockerfile:3`), `app/main.py:68` 의 `_uploads_dir` 계산 결과는 `/server/uploads` 이므로 호스트 ↔ 컨테이너 동일 경로로 매핑.
- `server/.dockerignore` 의 `uploads/` 는 그대로 유지. volume 마운트와 빌드 컨텍스트는 별개라 영향 없음.

### Frontend URL prepend
- `mediaUrl()` 은 `http(s)://` 시작 시 그대로, 아니면 `apiOrigin` (`http://localhost:8000`) prepend.
- 향후 backend 가 절대 URL 을 반환하도록 바꿔도 helper 가 바이패스 — backward-compatible.
- `photoUrls` 는 `verification_detail_screen` 단일/다중 PageView 두 위치 + `feed_item_card` 한 위치, 총 3곳 (grep 결과 모두 커버).

### 시뮬레이터 시드
- python3 + 시스템 PIL 로 단색 + 한글 라벨 jpg 생성 (`AppleSDGothicNeo` 96pt). 라이선스 클린.
- 스크립트는 부팅된 simulator 자동 감지 + nullglob 으로 jpg/jpeg/png 모두 시드.

### Backend 테스트
- 라우터는 multipart byte stream 을 그대로 디스크에 쓰므로 진짜 jpg 디코딩 불필요. JFIF 매직 + EOI 가 들어간 `_DUMMY_JPG` 만 사용 → server pyproject 에 PIL 등 추가 dep 없음.
- `_DUMMY_JPG` 는 finally 블록에서 cleanup.

### 시뮬레이터 자동 인터랙션 한계
- iOS 26 PhotosPicker (`PHPickerViewController`) 는 별도 process sandbox. `idb` 의 단순 tap / `--duration` long-press / 우상단 모서리 / 미세 swipe 4가지 모두 통과 안 됨. 자동 캡처는 인증 작성 화면 + source modal + PHPicker 시드 사진 노출 (3장) 까지로 끝나고, 사진 선택 이후 흐름은 사용자 manual 검증.

## Tests & Build

- Analyze: pass (4 changed files, 0 issues)
- Tests: pass (`pytest tests/test_verifications.py -v` → 14/14, 신규 2개 포함)
- Build: pass (`flutter build ios --simulator`)
- Health: pass (`curl http://localhost:8000/health` → `{"status":"ok"}`)
- Simulator: install + launch OK, 인증 화면 진입까지 자동 캡처 3장

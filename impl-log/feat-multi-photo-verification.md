# feat: support up to 3 verification images

- **Date**: 2026-04-09
- **PR**: #2 — https://github.com/moonsangyhu/haeda/pull/2
- **Branch**: feat/multi-photo-verification
- **Area**: both

## What Changed

인증(Verification) 이미지를 기존 1장에서 최대 3장까지 업로드할 수 있도록 변경. DB 컬럼을 `photo_url` TEXT에서 `photo_urls` JSONB 배열로 마이그레이션하고, API와 프론트엔드를 모두 업데이트.

## Changed Files

| File | Change |
|------|--------|
| `docs/api-contract.md` | `photo_url` → `photo_urls` (list), `photo` → `photos` (file[]) |
| `docs/domain-model.md` | Verification 엔티티 `photo_url TEXT` → `photo_urls JSONB` |
| `server/alembic/versions/20260409_0000_003_...py` | NEW: 마이그레이션 (add photo_urls, migrate data, drop photo_url) |
| `server/app/models/verification.py` | `photo_url` → `photo_urls` JSONB 컬럼 |
| `server/app/routers/challenges.py` | 다중 파일 업로드 처리, max 3 검증 |
| `server/app/schemas/verification.py` | 응답 스키마 `photo_url` → `photo_urls` |
| `server/app/schemas/comment.py` | VerificationDetailResponse `photo_url` → `photo_urls` |
| `server/app/services/verification_service.py` | photo_urls 파라미터/검증/생성 |
| `server/app/services/comment_service.py` | 상세 응답 photo_urls 반영 |
| `server/tests/test_verifications.py` | photo_url → photo_urls 업데이트 |
| `server/tests/test_challenges.py` | fixture photo_url → photo_urls |
| `server/tests/test_comments.py` | fixture/assertion photo_url → photo_urls |
| `server/tests/test_me.py` | fixture photo_url → photo_urls |
| `app/.../models/verification_data.dart` | photoUrl → photoUrls (List<String>?) |
| `app/.../models/comment_data.dart` | photoUrl → photoUrls (List<String>?) |
| `app/.../providers/verification_provider.dart` | 다중 사진 FormData 전송 |
| `app/.../screens/create_verification_screen.dart` | 3칸 정사각 박스 UI, 개별 추가/삭제 |
| `app/.../screens/verification_detail_screen.dart` | PageView + dot indicator 다중 이미지 표시 |

## Implementation Details

- **DB 접근**: JSONB 배열로 단순화 (최대 3개 고정 상한이므로 별도 테이블 불필요)
- **API**: `photos: list[UploadFile]` 파라미터로 다중 파일 수신. 빈 리스트는 NULL로 저장
- **Frontend 업로드 UI**: LayoutBuilder 기반 3칸 Row. 각 박스 `(width - 16) / 3` 정사각형
- **Frontend 상세 UI**: 1장이면 기존처럼 full-width, 2~3장이면 PageView + 하단 dot indicator
- **Alembic**: 기존 `photo_url` 데이터를 `to_jsonb(ARRAY[photo_url])`로 안전하게 마이그레이션

## Tests & Build

- Backend pytest: 85 passed, 0 failed
- Flutter build web: pass
- Analyze: pre-existing warnings only (flutter_secure_storage_web wasm compat)

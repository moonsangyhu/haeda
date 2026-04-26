# fix(backend): 인증 제출 응답 coins_earned 필드 type 으로 정정

- **Date**: 2026-04-26
- **Commit**: 6ef050f
- **PR**: #64
- **Area**: backend

## What Changed

새 챌린지 생성 후 첫 인증 제출 시 "인증 제출 중 오류가 발생했습니다." 가 뜨던 버그를 수정. 백엔드가 `coins_earned[]` 응답에 `reason` 필드를 사용했는데 `docs/api-contract.md` 계약은 `type`. Flutter freezed 가 `json['type'] as String` 으로 파싱하다 null cast 실패로 throw, `verification_provider.dart:128` 의 catch-all 메시지가 표시됐다.

## Changed Files

| File | Change |
|------|--------|
| `server/app/schemas/coin.py` | `CoinEarned.reason: str` → `type: str` |
| `server/app/services/verification_service.py` | `CoinEarned(amount=, reason=)` → `type=` 4 곳 (VERIFICATION/STREAK_3/STREAK_7/ALL_COMPLETED) |
| `server/tests/test_verifications.py` | 계약 회귀 테스트 `test_create_verification_coins_earned_uses_type_field` 추가 |

## Implementation Details

- 소스 오브 트루스 (`docs/api-contract.md` line 770-772) 가 `type` 으로 정의되어 있어 백엔드를 계약에 맞춤. Flutter (`coin_earned.g.dart:11`) 도 동일하게 `type` 을 기대하므로 추가 변경 불필요.
- `CoinTransactionResponse` (`server/app/schemas/coin.py`) 도 `reason: str` 을 가지지만 라우터 `me.py:108` 이 dict 를 직접 만들 때 `tx.reason → "type"` 으로 매핑하고 있어 외부 응답은 정상. 본 PR 범위 밖.
- TDD: RED 테스트는 응답 dict 가 `{"amount": 10, "reason": "VERIFICATION"}` 으로 반환되는 것을 정확히 재현하며 실패했고, schema/service 수정 후 GREEN.

## Tests & Build

- 신규 테스트: `test_create_verification_coins_earned_uses_type_field` PASSED
- 영향 영역 테스트: `tests/test_verifications.py` 12, `tests/test_verification_detail.py` 3, `tests/test_completion.py` 4 — 모두 PASSED
- 전체: 109 passed, 2 failed (사전 회귀 `test_room_equip.py::TestSignature` 2건, 본 변경과 무관 — git stash 검증 완료)
- 빌드: `docker compose up --build -d backend` 성공, `curl http://localhost:8000/health` → `{"status":"ok"}`

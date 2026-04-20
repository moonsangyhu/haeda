# Character Avatar 32×32 Cyworld Style Rewrite

- Date: 2026-04-20
- Type: feat
- Area: frontend

## Requirement

`docs/design/specs/character-cyworld-style.md` 의 디자인 스펙을 구현. 방 배경(miniroom-cyworld, 32×24 그리드)은 이미 구현되어 있으나 캐릭터가 16×16 해상도라 시각적 스케일이 맞지 않았다. 캐릭터를 32×32 그리드로 올려 동일한 dp/pixel 해상도로 통합하는 것이 핵심 목표.

## Plan Source

`/implement-design` 스킬이 `docs/design/specs/character-cyworld-style.md`(status: ready)를 atomic lock(status: in-progress)으로 전환 후 feature-flow 9-step 파이프라인 실행. 수용 기준(§18, 11개 항목):

- 내 방 화면에서 room과 character가 동일 스케일로 렌더링
- 110dp에서 얼굴 식별 가능
- 표정 9가지 조합 (3 eye styles × 3 mouth states)
- 헤어 3종 시각적 구분
- 아이템 26종 × 3단계 레어리티
- 애니메이션 악세서리 2×2 리맵 후 정상 작동
- 포토 스탬프 선명도 유지
- 다크모드 외곽선 강화 (L−0.40 vs L−0.35)
- 40/80/110/160dp 반응형 스케일
- `flutter build ios --simulator` 성공
- 10개 탭 전환 시 렉 없음

## Implementation

### Backend

N/A

### Frontend

- `app/lib/core/widgets/character_avatar.dart` (827 → 1456 LOC)
  - `_PixelCharacterPainter` 전면 재작성: 16×16 → 32×32 그리드. 픽셀 단위 divisor `size.width / 16.0` → `/ 32.0`
  - `CharacterPalette` 클래스 신규 추가: 3×3 피부톤, 헤어 4톤, 얼굴 특징, 기본 의상 3-tone set, 이펙트 팔레트
  - `_paintLayer` 3-tone 헬퍼 추가: shadow/base/highlight 구조
  - `isDark` 파라미터 추가 → `_CharacterAvatarState.build`에서 `Theme.of(context).brightness`로 wiring
  - `_drawBase`, `_drawDefaultBody/Legs/Shoes` 전면 재작성 (얼굴/피부/헤어/눈/입/볼터치)
  - 모자 7종: cap/beanie/pink_beanie/headband/fedora/beret/crown
  - 상의 7종: white_tee/striped_tee/check_shirt/sleeveless/hoodie/cardigan/tuxedo
  - 하의 6종: jeans/shorts/chinos/skirt/cargo/golden_pants
  - 신발 6종: sneakers/boots/heels/loafers/sandals/golden_shoes
  - `_drawSparkles` 8방향 5픽셀 십자 패턴

- `app/lib/core/widgets/accessory_renderer.dart` (210 → 234 LOC)
  - `_drawPxRemapped(canvas, color, pixels, px)` 헬퍼 추가: 스펙 §14 좌표 매핑 구현 (xNew = xOld×2−1, yNew = yOld×2+4, 2×2 블록 fill)
  - `drawAccessoryOnCharacter` 내부의 모든 `_drawPx` 호출을 `_drawPxRemapped`로 교체: watch, sunglasses, angel_wings, necklace, newspaper, duck_watergun, laptop, pencil (애니메이션 픽셀 포함)
  - `drawAccessoryIcon` 함수는 **변경 없음** — 상점/인벤토리 아이콘은 16 그리드 그대로 유지

## Key Implementation Decisions

1. **3-tone shading 방식**: `CharacterPalette`에 shadow/base/highlight 3톤 세트를 정의하고 `_paintLayer` 헬퍼로 일관 적용. 스펙 §4의 "Cyworld 감성" 도트아트 재현에 필수.

2. **isDark wiring**: `BuildContext`에서 `Theme.of(context).brightness`를 읽어 `_PixelCharacterPainter`에 전달. 외곽선 명도를 L−0.40(다크)과 L−0.35(라이트)로 분기. `CustomPainter`는 `shouldRepaint`에서 `isDark` 변화 감지.

3. **악세서리 2×2 리맵 전략 (vs 네이티브 32×32 재작성)**: 악세서리 16개 이상의 좌표계를 한 번에 32×32로 변환하는 것은 별도 디자인 문서가 필요. 스펙 §14는 1차 출시용 임시 해결책으로 수식 리맵을 명시적으로 허용. `drawAccessoryIcon`(상점/인벤토리)은 16 그리드를 그대로 쓰므로 변경 대상에서 제외.

4. **`useHighRes` 피처 플래그 거부**: CLAUDE.md anti-shim 규칙에 따라 피처 플래그 없이 단일 구현으로 완전 전환. 하위 호환 shim을 두지 않음.

5. **공개 API 완전 보존**: `CharacterAvatar` 위젯 props, `paintCharacterIntoCanvas` 시그니처, `CharacterData` 모델 필드, 컨트롤러 필드 12개 호출 사이트 — 모두 무수정 호환.

## Tests Added

- 신규 테스트 파일 없음 (기존 94개 flutter test 활용)
- `flutter analyze character_avatar.dart`, `accessory_renderer.dart` → 이슈 0건

## QA Verdict

complete — `flutter analyze` 0 issues(변경 파일), `flutter test` 94 pass / 2 pre-existing fail(slice-07 연관 mock 오류, 본 슬라이스 무관), `flutter build ios --simulator` 성공, iPhone 17 Pro 시뮬레이터 정상 기동.

## Deploy Verification

- Backend health: 200 OK (`curl http://localhost:8000/health`)
- Simulator: running — iPhone 17 Pro (UDID `463EC4CF-2080-47FE-8F26-530FFB713C06`), terminate → uninstall → clean → build → install → launch 순서, 빌드 ~38s
- Screenshots: `docs/reports/screenshots/2026-04-20-feature-character-cyworld-style-01.png`

## Rollback Hints

- Files to revert: `app/lib/core/widgets/character_avatar.dart`, `app/lib/core/widgets/accessory_renderer.dart`
- Migrations to reverse: none
- 이 슬라이스는 단일 커밋으로 구성. `git revert <commit-hash>` 한 번으로 전체 복원 가능.
- 롤백 후 `flutter build ios --simulator` 재실행으로 16×16 상태 확인 권장.

## Follow-ups (P1+)

- 악세서리 네이티브 32×32 좌표 재작성: 별도 디자인 문서 필요 (스펙 §14 임시 리맵 대체)
- 시뮬레이터 visual review: 사용자가 직접 로그인 후 내 방 화면에서 캐릭터 스케일 확인 대기
- Golden 테스트 추가 고려: 각 outfit 조합의 렌더 스냅샷을 regression 방지용으로 캡처
- `hairColor` 필드 지원: 모델 변경 필요 (현재 hairStyle만 지원)
- 포즈 변형, 자동 표정 상태, 아웃핏 프리셋 — 스펙 Future P1+로 유예

# Character Avatar 32×32 Cyworld Style Rewrite

- Date: 2026-04-20
- Worktree (수행): feature
- Worktree (영향): feature
- Role: feature

## Request

사용자가 `docs/design/specs/character-cyworld-style.md` 구현을 요청. `/implement-design` 스킬이 해당 스펙(status: ready)을 atomic lock으로 전환(status: in-progress) 후 feature-flow 9-step 파이프라인 실행. product-planner → spec-keeper → flutter-builder → code-reviewer → qa-reviewer → deployer → doc-writer 순서로 진행.

## Root cause / Context

방 배경(miniroom-cyworld) 슬라이스에서 32×24 타일 그리드를 구현했으나 캐릭터 아바타는 여전히 16×16 픽셀 해상도로 렌더링되고 있었다. 같은 dp 크기에서 방 배경은 정밀한 32×32 픽셀 아트 품질을 보여주는데 캐릭터는 거친 16×16 그리드라 시각적 스케일 불일치가 발생. Cyworld 감성의 완성도 있는 미니룸을 위해 캐릭터를 32×32로 올려 동일한 해상도로 통합하는 것이 이 슬라이스의 핵심 목적.

## Actions

feature-flow 12단계 마이그레이션 플랜 실행:

1. `docs/design/specs/character-cyworld-style.md` status `ready` → `in-progress` atomic flip + PR 머지 (lock 획득)
2. `app/lib/core/widgets/character_avatar.dart` 전면 재작성
   - `CharacterPalette` 클래스 신규: 3×3 피부톤, 헤어 4톤, 기본 의상 3-tone 세트
   - `_paintLayer` 3-tone 헬퍼(shadow/base/highlight) 추가
   - `isDark` 파라미터 추가, `Theme.of(context).brightness` wiring
   - 픽셀 divisor `size.width / 16.0` → `/ 32.0` 전환
   - 모든 `_draw*` 메서드 재작성: 기본 캐릭터(얼굴/피부/헤어/눈/입/볼터치), 기본 바디/레그/슈즈, 모자 7종, 상의 7종, 하의 6종, 신발 6종, `_drawSparkles` 8방향
   - 827 → 1456 LOC
3. `app/lib/core/widgets/accessory_renderer.dart` 부분 수정
   - `_drawPxRemapped` 헬퍼 추가: 스펙 §14 xNew=xOld×2−1, yNew=yOld×2+4, 2×2 블록
   - `drawAccessoryOnCharacter` 내 8종 악세서리 모든 `_drawPx` 호출 → `_drawPxRemapped` 교체
   - `drawAccessoryIcon` 함수 변경 없음 (상점/인벤토리 아이콘은 16 그리드 유지)
   - 210 → 234 LOC
4. 코드 리뷰 Pass: 단일 divisor, isDark wiring, 악세서리 리맵 범위, API 보존, 스펙 좌표 spot-check 통과
5. QA: flutter analyze 0 issues(변경 파일), flutter test 94 pass / 2 pre-existing fail
6. `flutter build ios --simulator` 성공 (~38s)
7. iPhone 17 Pro 시뮬레이터 terminate → uninstall → clean → build → install → launch 완료
8. 백엔드 헬스체크 200 OK
9. 보고서 3종 작성 후 커밋 예정

커밋 해시: (PR 머지 후 확인 예정)

## Verification

| 항목 | 결과 | 비고 |
|------|------|------|
| `flutter analyze` (변경 파일) | PASS — 0 issues | character_avatar.dart, accessory_renderer.dart |
| `flutter analyze` (전체 프로젝트) | PASS — 0 errors/warnings | 204 info는 test/** pre-existing |
| `flutter test` | 94 pass / 2 fail | 2 failures는 slice-07 mock 오류, 본 슬라이스 무관 |
| `flutter build ios --simulator` | PASS | "✓ Built build/ios/iphonesimulator/Runner.app" (~38s) |
| 시뮬레이터 기동 | PASS | iPhone 17 Pro, 로그인 화면 로드 정상 |
| 백엔드 헬스체크 | 200 OK | `curl http://localhost:8000/health` |
| 코드 리뷰 | Pass | 공개 API 보존, divisor 단일화, isDark wiring 정확 |

사용자 확인 필요:
- 로그인 후 내 방 화면에서 캐릭터와 배경 스케일 시각 검수 (수용 기준 1–9, 11번)

## Follow-ups

- **악세서리 네이티브 32×32 재작성**: 현재 2×2 리맵은 스펙 §14의 1차 출시 임시 해결책. 별도 디자인 문서 작성 후 후속 슬라이스에서 처리.
- **시뮬레이터 visual review**: 사용자가 직접 iPhone 17 Pro 시뮬레이터에서 로그인 → 내 방 화면으로 이동하여 캐릭터 스케일, 얼굴 식별성, 아이템 렌더링 확인 필요.
- **Golden 테스트**: 각 outfit 조합의 렌더 스냅샷을 regression 방지용으로 추가하는 것 고려.
- **`hairColor` 필드**: 현재 hairStyle만 지원. 컬러 선택 기능 추가 시 CharacterData 모델 변경 필요.
- **포즈/표정/프리셋**: 스펙 Future P1+로 유예된 항목, 별도 요청 시 진행.
- `docs/design/specs/character-cyworld-style.md` status: `in-progress` → `implemented` 전환은 `/implement-design` 스킬이 doc-writer 완료 후 수행.
- 다른 워크트리에서 기존 세션을 실행 중이라면 재시작해야 최신 rule이 적용됩니다.

## Related

- Design spec: `docs/design/specs/character-cyworld-style.md`
- Impl-log: `impl-log/feat-character-cyworld-style-feature.md`
- Test report: `test-reports/character-cyworld-style-feature-test-report.md`
- Screenshot: `docs/reports/screenshots/2026-04-20-feature-character-cyworld-style-01.png`

## Screenshots

![App Launch](screenshots/2026-04-20-feature-character-cyworld-style-01.png)

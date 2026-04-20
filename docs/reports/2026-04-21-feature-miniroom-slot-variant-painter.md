---
Date: 2026-04-21
Worktree (수행): feature
Worktree (영향): feature
Role: feature
---

# Miniroom Slot Variant Painter

## Request

`MiniroomScene` 의 wall/floor painter 에 `mr/` 접두사 prefix 버그를 수정하고, design spec `docs/design/specs/miniroom-cyworld.md` §Future 에 명시된 6개 슬롯(ceiling/window/shelf/plant/desk/rug) variant painter 를 구현. 8개 슬롯 전체가 assetKey 분기를 갖도록 확장.

## Root cause / Context

이전 슬라이스(`2026-04-20-feature-miniroom-cyworld-wiring`)에서 `MiniroomScene.equip` 연결이 완료되었으나, painter 분기 자체에 두 가지 문제가 잠재하고 있었다.

1. **assetKey prefix 불일치**: 기존 `_wallColorFor`/`_floorColorsFor` 는 `wall/pink`, `floor/wood` 처럼 슬래시 구분자 패턴으로 매칭하도록 작성되어 있었다. 그러나 migration 017(`2026-04-19`) 에서 실제로 삽입된 시드 assetKey 는 `mr/wall_lavender`, `mr/floor_wood` 형식 — `mr/` 접두사 + 언더스코어 구분자다. 따라서 사용자가 방 꾸미기에서 저장을 해도 painter 분기가 매치되지 않아 항상 default 색으로 렌더링됐다.

2. **6개 슬롯 미구현**: design spec §Future 는 ceiling/window/shelf/plant/desk/rug 에도 variant painter 가 필요하다고 명시했으나, 해당 슬롯에는 단일 default 코드만 존재했다.

`docs/design/specs/miniroom-cyworld.md` 의 `/implement-design` lock 을 유지한 채 본 slice 에서 두 문제를 동시에 해결했다.

## Actions

**Production 변경 (`app/lib/core/widgets/miniroom_scene.dart`, 360 → 583줄):**

1. `_wallColorFor` — prefix 패턴을 `mr/wall_lavender` / `mr/wall_mint` 로 수정, legacy seed(`wall/blue`, `wall/pink` 등) case 보존.
2. `_floorColorsFor` — `mr/floor_wood` / `mr/floor_tile` 로 수정, legacy 보존.
3. 6개 신규 슬롯 helper 추가 (각 `@visibleForTesting` public):
   - `miniroomSceneCeilingVariantFor` — `mr/ceiling_cloud` / `mr/ceiling_star`
   - `miniroomSceneWindowVariantFor` — `mr/window_arch` / `mr/window_round`
   - `miniroomSceneShelfVariantFor` — `mr/shelf_pine` / `mr/shelf_oak`
   - `miniroomScenePlantVariantFor` — `mr/plant_cactus` / `mr/plant_fern`
   - `miniroomSceneDeskVariantFor` — `mr/desk_white` / `mr/desk_brown`
   - `miniroomSceneRugVariantFor` — `mr/rug_stripe` / `mr/rug_solid`
4. painter `switch` 에 6개 슬롯 case 추가, equip==null → 기존 default 유지.
5. helper visibility 결정: private `_xxxFor` → public `miniroomSceneXxxFor` + `@visibleForTesting`. 테스트가 내부 로직을 직접 검증해야 하는 구조여서 visibility 를 올리되 production 노출을 의미하지 않음을 annotation 으로 명시.

**테스트 신규 (`app/test/core/widgets/miniroom_scene_test.dart`, 186줄, 36 tests):**

- 8개 슬롯 × 4케이스(null / variant1 / variant2 / unknown seed) = 32케이스 + legacy regression 4케이스
- RED → GREEN 사이클: wall prefix 버그를 먼저 실패 로그로 확인 후 production 변경

## Verification

| 항목 | 결과 | 근거 |
|------|------|------|
| TDD RED (wall prefix bug) | CONFIRMED | `Expected: Color(0xffede5f5) Actual: <null>` |
| TDD GREEN (36 tests) | PASS | `00:00 +36: All tests passed!` |
| Full suite | 134 passed / 2 pre-existing failures | `profile_setup_screen_test` 포함 — 이번 변경과 무관 |
| `flutter analyze` 신규 이슈 | 0개 | `No issues found` |
| `flutter build ios --simulator` | PASS | `✓ Built build/ios/iphonesimulator/Runner.app (25.4s)` |
| iOS simulator launch | PASS | device `463EC4CF-2080-47FE-8F26-530FFB713C06`, PID 89770 |
| 파일 크기 | 583줄 (600 이내) | PASS |

## Follow-ups

- `profile_setup_screen_test` mock out-of-sync — 별도 fix slice 에서 해결 필요.
- `MiniroomVariants` data class 리팩터 — 슬롯 추가가 반복될 경우 painter 생성자 인자가 과다해지므로 struct 로 묶는 리팩터링 권장.
- arch window corner 가 `wallBase` 하드코딩 → `wallTint` 주입으로 tint 반응성 개선 필요.
- design spec §Slot Catalog 의 "기본값=작은 화분" 표현이 시드 default(`mr/plant_cactus`) 와 엇갈림 — 디자인 워크트리에서 스펙 revise 권장.
- Interactive tap-through smoke(`idb`/`applesimutils` 설치 후 수동 확인 권장).

## Retrospective

### What worked

TDD RED→GREEN 사이클이 helper 함수 단위 테스트와 잘 맞았다. 각 슬롯의 `_xxxFor(String? assetKey)` 는 순수 함수여서 외부 의존 없이 단위 테스트 36개를 빠르게 작성할 수 있었고, RED 단계에서 prefix 버그를 명확한 색상값 불일치로 확인할 수 있었다. 기존 `_wallColorFor` 패턴을 6개 슬롯에 일관되게 복제해 구조적 일관성을 유지했다. 시드 assetKey 가 단일 출처(migration 017)여서 매핑 실수가 발생하지 않았다.

### What could improve

product-planner spec reference 에 엔티티명 오기(`RoomItem`→`Item`, `MiniroomSlot`→`RoomEquipMr`) 가 있어 초기 컨텍스트 파악에 시간이 소요됐다. 디자인 스펙의 "기본값=작은 화분" 표현과 시드의 `mr/plant_cactus` default 가 서로 다른 방식으로 표현돼 있어 문서-데이터 드리프트가 누적되고 있다. Painter 생성자 인자가 6 variant 추가로 길어지면서 `MiniroomVariants` struct 리팩터가 자연스럽게 필요해졌는데, 이런 리팩터 시점을 미리 slice 계획에 포함해 두면 기술 부채 누적을 방지할 수 있다.

### Process signal

`spec-compliance-reviewer` 에이전트가 available agents 에 없어 `code-reviewer` 로 결합 수행했다. 실제 결과에는 문제가 없었으나 workflow 정의(`agents.md` §Dispatch Rules)와 가용 에이전트 간 mismatch 는 이번이 처음이 아니다 — `agents.md` 의 `spec-compliance-reviewer` 를 실제 `.claude/agents/` 에 추가하거나, 통합 역할을 공식화하는 방향으로 정리가 필요하다.

## Referenced Reports

- `docs/reports/2026-04-19-feature-room-decoration.md` — 부모 slice (migration 017, `mr/` 시드 출처). `MiniroomScene.equip` 파라미터 최초 추가.
- `docs/reports/2026-04-20-feature-miniroom-cyworld-wiring.md` — equip wiring slice. `wall/blue` 등 legacy prefix 보존 근거.
- `docs/reports/2026-04-20-feature-miniroom-equip-wiring-tdd.md` — TDD 패턴(helper visibility `@visibleForTesting` 방식) 참고.
- `docs/reports/2026-04-20-design-miniroom-cyworld-revise.md` — 디자인 스펙 개정 context. 6개 슬롯 §Future 항목 위치 확인.

## Related

- `impl-log/feat-miniroom-slot-variant-painter-feature.md`
- `test-reports/miniroom-slot-variant-painter-feature-test-report.md`
- Design spec: `docs/design/specs/miniroom-cyworld.md`

## Screenshots

![App launch](screenshots/2026-04-21-feature-miniroom-variant-painter-01.png)
![App settled](screenshots/2026-04-21-feature-miniroom-variant-painter-02.png)

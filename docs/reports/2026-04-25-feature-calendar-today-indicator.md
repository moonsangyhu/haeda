# 챌린지 캘린더 오늘 날짜 표시

- **Date**: 2026-04-25
- **Worktree (수행)**: feature
- **Worktree (영향)**: feature
- **Role**: feature

## Request

사용자: "챌린지 달력에 오늘 날짜를 표시해줘"

브레인스토밍 한 번의 질의로 시각 방식 결정 — A (숫자에 동그라미 채우기, iOS/Material 캘린더 표준).

## Root cause / Context

챌린지 스페이스 월 캘린더(`CalendarGrid` / `CalendarDayCell`) 의 셀에는 day 숫자, 시즌 아이콘, 멤버 썸네일만 있고 오늘 날짜를 시각적으로 구분하는 표시가 없어 사용자가 캘린더에서 현재 위치를 즉각 파악할 수 없었음.

부모 화면 (`challenge_space_screen.dart`) 은 이미 `DateTime.now()` 를 여러 번 계산해 "오늘 인증 여부", "미래 날짜 탭 차단" 등에 사용 중이라 백엔드/모델 변경은 불필요했음.

## Actions

1. **설계** (commit `a28b469`): `docs/superpowers/specs/2026-04-25-calendar-today-indicator-design.md` 작성. 인증 콘텐츠 영역 보존, primary 색 20×20 원형 배지로 day 숫자 강조.
2. **플랜** (uncommitted at this time, included in final commit): `docs/superpowers/plans/2026-04-25-calendar-today-indicator.md` 4-task TDD 플랜 작성.
3. **Task 1** (commit `8f4cf0d` + 리뷰 후속 `2e4b575`): `CalendarDayCell` 에 `bool isToday` 파라미터(기본값 `false`) 추가. true 일 때 day 숫자를 width=20 / height=20 / `BoxShape.circle` + `colorScheme.primary` 컨테이너에 감싸고 텍스트는 `onPrimary` + bold. 위젯 테스트 3 케이스 추가 (positive / 시즌 아이콘 동시 / 음성 케이스), 색 검증을 `isNotNull` → 실제 `colorScheme.primary` 비교로 강화. 합산 7 PASS.
4. **Task 2** (commit `f44fed8` + 리뷰 후속 `bf45249`): `CalendarGrid.build()` 에서 `DateTime.now()` 1회 계산해 `isCurrentMonth && today.day == day` 인 셀에만 `isToday: true` 전달. `calendar_grid_test.dart` 신규 + 3 케이스 (현재 월 / 다음 월 year boundary / 이전 월 year boundary). 3 PASS.
5. **Task 3 검증**:
   - `flutter analyze`: 본 변경 관련 error/warning 0. info 레벨 `prefer_const_constructors` 2건은 기존 동일 패턴 따름.
   - `flutter clean && flutter pub get && flutter build ios --simulator`: PASS (`Built build/ios/iphonesimulator/Runner.app` `13.3s`).
   - `xcrun simctl install + launch`: PASS (`com.example.haeda: 40487`).
   - 캡처: `docs/reports/screenshots/2026-04-25-feature-calendar-today-indicator-01.png` (앱 실행 직후 홈 화면).
   - 챌린지 공간 캘린더 시각 확인: 사용자가 시뮬레이터에서 직접 챌린지 카드를 탭해 캘린더 화면을 확인. 4월 25일 셀의 primary 원형 배지 적용 OK 응답 받음.

관련 spec: `docs/superpowers/specs/2026-04-25-calendar-today-indicator-design.md`
관련 plan: `docs/superpowers/plans/2026-04-25-calendar-today-indicator.md`

## Verification

| 항목 | 상태 | 증거 |
|------|------|------|
| `flutter test test/features/challenge_space/widgets/calendar_day_cell_test.dart` | OK | `00:00 +7: All tests passed!` |
| `flutter test test/features/challenge_space/widgets/calendar_grid_test.dart` | OK | `00:00 +3: All tests passed!` |
| `flutter analyze` (본 변경 범위) | OK | 신규 error/warning 0 (사전 1 error 무관) |
| `flutter build ios --simulator` | OK | `Built build/ios/iphonesimulator/Runner.app` |
| iOS simulator install + launch | OK | `com.example.haeda: 40487` |
| 챌린지 캘린더 today 배지 시각 확인 | OK | 사용자 직접 확인 |
| Spec compliance review (Task 1, Task 2) | OK | 두 번 모두 ✅ Spec compliant |
| Code quality review (Task 1, Task 2) | OK | 두 번 모두 Approved (Important 1건 follow-up 으로 이관) |

## Follow-ups

1. **midnight rollover (Important — 코드 리뷰 후속)**: `CalendarGrid` 의 `DateTime.now()` 가 `build()` 안에서 호출되므로 자정에 부모가 setState/invalidate 하지 않으면 셀의 isToday 가 갱신되지 않음. MVP 범위에서 의도적으로 단순성 선택. 향후 자정에 부모 상태 갱신하는 `Timer.periodic` 또는 `CalendarGrid` 를 `StatefulWidget` 으로 전환해 자정 타이머 내장 검토.
2. **iOS 자동 탭 도구 부재 (사용자 명시 피드백)**: 시뮬레이터 깊은 화면 시각 검증을 위해 `idb` (`brew tap facebook/fb && brew install idb-companion && pip install fb-idb`) 또는 GoRouter deep-link + `xcrun simctl openurl` 활용. 메모리 `feedback_ios_auto_tap_tooling.md` 에 기록.
3. **사전 미커밋 WIP 보존**: 작업 중 `app/lib/core/widgets/main_shell.dart`, `app/lib/features/friends/screens/contact_search_screen.dart` 의 미해결 stash conflict marker 가 빌드를 막아 stash 로 임시 격리. 작업 종료 시 `git stash pop` 으로 복원 예정. main_shell.dart 의 conflict marker 는 사용자 또는 이전 세션의 미해결 merge 잔재이므로 수동 해결 필요.

## Related

- Spec: `docs/superpowers/specs/2026-04-25-calendar-today-indicator-design.md`
- Plan: `docs/superpowers/plans/2026-04-25-calendar-today-indicator.md`
- 참조 보고서:
  - `docs/reports/2026-04-19-front-challenge-room-scene.md` — 챌린지 스페이스 화면 전체 구조 (영향 없음 확인)
  - `docs/reports/2026-04-05-emoji-to-material-icons.md` — 아이콘 정책 (신규 아이콘 추가 없음)
- 메모리: `feedback_ios_auto_tap_tooling.md` (iOS 자동 탭 도구 필요)
- 커밋:
  - `a28b469` docs(spec): 챌린지 캘린더 오늘 날짜 표시 설계
  - `8f4cf0d` feat(front): CalendarDayCell 에 isToday 원형 배지 추가
  - `2e4b575` test(front): CalendarDayCell isToday=false 음성 케이스 + primary 색 강화
  - `f44fed8` feat(front): CalendarGrid 가 오늘 셀에 isToday 전달
  - `bf45249` test(front): CalendarGrid 이전 달 경계 테스트 추가

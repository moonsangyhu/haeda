# 챌린지 캘린더 오늘 날짜 표시

- **작성일**: 2026-04-25
- **영역**: front (Flutter)
- **상태**: ready

## 배경

챌린지 스페이스 화면(`challenge_space_screen.dart`)의 월 캘린더는 각 날짜 셀에 day 숫자, 전원 인증 시 계절 아이콘, 일부 인증 시 멤버 썸네일을 표시한다. 그러나 **오늘 날짜를 시각적으로 구분하는 표시가 없어** 사용자가 캘린더에서 현재 위치를 즉각 파악하지 못한다.

부모 화면은 이미 `DateTime.now()` 를 여러 곳에서 계산해 "오늘 인증 여부", "미래 날짜 탭 차단" 등에 사용하고 있어 백엔드/모델 변경은 필요 없다.

## 목표

챌린지 캘린더에서 오늘 날짜 셀의 day 숫자에 **primary 색 원형 배경 + onPrimary 색 글자** 강조를 적용한다 (iOS / Material 캘린더 표준 패턴).

## 비목표

- 인증 아이콘 / 멤버 썸네일 영역의 시각 변경 (오늘이라도 인증 콘텐츠 영역은 그대로)
- 미래 / 과거 날짜에 대한 별도 표시
- 다른 화면 (피드 / 마이페이지 등) 의 캘린더성 위젯 — 본 작업은 `CalendarGrid` / `CalendarDayCell` 만 다룸
- API / 모델 / 라우팅 변경

## 설계

### 영향 파일

| 파일 | 변경 |
|------|------|
| `app/lib/features/challenge_space/widgets/calendar_grid.dart` | 빌드 시 `DateTime.now()` 1회 계산, 셀 생성 시 `isToday` flag 전달 |
| `app/lib/features/challenge_space/widgets/calendar_day_cell.dart` | `bool isToday` 파라미터 추가, day 숫자 영역을 조건부로 원형 배지 형태로 렌더 |
| `app/test/features/challenge_space/widgets/calendar_day_cell_test.dart` | 신규 — `isToday` 분기 검증 |
| `app/test/features/challenge_space/widgets/calendar_grid_test.dart` | 신규 — 오늘 날짜 셀에만 `isToday: true` 전달 검증 |

### CalendarGrid 변경

`build()` 시작 부분에 다음 추가:

```dart
final today = DateTime.now();
final isCurrentMonth = today.year == year && today.month == month;
```

`itemBuilder` 의 `CalendarDayCell` 생성 시:

```dart
return CalendarDayCell(
  day: day,
  entry: entry,
  members: members,
  isToday: isCurrentMonth && today.day == day,
  onTap: onDayTap != null ? () => onDayTap!(dateStr) : null,
);
```

### CalendarDayCell 변경

생성자에 `final bool isToday;` 추가 (기본값 `false`).

기존 day 숫자 `Text` 위젯을 다음 조건부 렌더로 교체:

```dart
isToday
  ? Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$day',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
      ),
    )
  : Text(
      '$day',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    )
```

> 주: `BoxShape.circle` 은 가로=세로 강제. 고정 크기 20x20 으로 한 자리(`5`) / 두 자리(`25`) 숫자 모두 동일 원형 배지에 들어가도록 한다. 두 자리 숫자가 좁아 보이면 시뮬레이터 확인 후 22x22 까지 조정 가능.

### 인증 콘텐츠와의 관계

기존 `Column` 구조 (`day 숫자 → SizedBox(2) → _buildContent`) 는 그대로 유지. 오늘이고 동시에 전원 인증된 날에는 원형 배지 아래에 계절 아이콘이 정상 표시된다. 셀 폭/높이는 변경하지 않으므로 전체 그리드 레이아웃이 흔들리지 않는다.

## 테스트 (TDD)

### `calendar_day_cell_test.dart`

1. `isToday: false` (기본) 일 때 day 숫자 위젯 트리에 `BoxDecoration` 컨테이너가 없는지.
2. `isToday: true` 일 때 day 숫자가 `BoxDecoration(color: primary, shape: circle)` 컨테이너에 감싸져 있고 텍스트 스타일에 bold + onPrimary 색이 적용되는지.
3. `isToday: true` + 전원 인증 entry 가 함께 들어왔을 때 계절 아이콘이 여전히 렌더되는지 (회귀 방지).

### `calendar_grid_test.dart`

1. 현재 월/년으로 그리드를 빌드했을 때 `today.day` 에 해당하는 `CalendarDayCell` 만 `isToday: true` 이고 나머지는 `false` 인지.
2. 다른 월 (예: 다음 달) 로 그리드를 빌드했을 때 모든 셀의 `isToday` 가 `false` 인지.

`DateTime.now()` 는 직접 mock 하지 않고 위젯 트리에서 isToday=true 인 셀 개수가 정확히 1 (현재 월) 또는 0 (타 월) 인지로 검증한다.

## 검증

1. `cd app && flutter test` 전체 통과 (신규 테스트 포함).
2. `cd app && flutter analyze` clean.
3. `haeda-ios-deploy` 스킬로 iOS 시뮬레이터 clean install. 챌린지 스페이스 진입 → 4월 25일 셀에 원형 primary 색 배지 시각 확인. 시즌 아이콘이 4월 25일에 있다면 배지 + 아이콘 동시 표시 정상.

## 회귀 방지 — 참조 보고서

- `docs/reports/2026-04-19-front-challenge-room-scene.md` — 챌린지 스페이스 화면 전체 구조. 본 작업은 캘린더 위젯만 건드리며 룸/씬 영역에 영향 없음.
- `docs/reports/2026-04-05-emoji-to-material-icons.md` — 아이콘 정책. 본 작업에서 새 아이콘은 추가하지 않음.

검색 키워드: `calendar`, `CalendarDayCell`, `CalendarGrid`, `app/lib/features/challenge_space/widgets`.

## 작업 보고서

종료 후 `docs/reports/2026-04-25-feature-calendar-today-indicator.md` 작성.

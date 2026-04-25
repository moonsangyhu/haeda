# 챌린지 캘린더 오늘 날짜 표시 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 챌린지 스페이스 월 캘린더에서 오늘 날짜 셀의 day 숫자를 primary 색 원형 배지(20×20)로 강조한다.

**Architecture:** `CalendarGrid` 가 `DateTime.now()` 를 한 번 계산해 각 `CalendarDayCell` 에 `bool isToday` flag 를 전달한다. 셀은 `isToday: true` 일 때만 day 숫자 `Text` 를 원형 컨테이너에 감싼다. 인증 콘텐츠 영역(시즌 아이콘 / 멤버 썸네일) 과 다른 화면은 변경하지 않는다.

**Tech Stack:** Flutter (Material 3), `flutter_test` widget tests.

**Spec:** `docs/superpowers/specs/2026-04-25-calendar-today-indicator-design.md`

---

## File Structure

| 파일 | 책임 | 변경 유형 |
|------|------|----------|
| `app/lib/features/challenge_space/widgets/calendar_day_cell.dart` | 단일 날짜 셀 렌더. `isToday` 분기로 원형 배지 적용 | Modify |
| `app/lib/features/challenge_space/widgets/calendar_grid.dart` | 월 그리드 빌드. `DateTime.now()` 1회 계산해 셀에 `isToday` 전달 | Modify |
| `app/test/features/challenge_space/widgets/calendar_day_cell_test.dart` | 셀의 `isToday` 분기 위젯 테스트 | Modify (case 추가) |
| `app/test/features/challenge_space/widgets/calendar_grid_test.dart` | 그리드가 오늘 셀에만 flag 전달하는지 검증 | Create |
| `docs/reports/2026-04-25-feature-calendar-today-indicator.md` | 작업 결과 보고서 | Create |

---

## Task 1: CalendarDayCell `isToday` 파라미터와 원형 배지 (TDD)

**Files:**
- Modify: `app/lib/features/challenge_space/widgets/calendar_day_cell.dart`
- Modify: `app/test/features/challenge_space/widgets/calendar_day_cell_test.dart`

- [ ] **Step 1: 실패 테스트 추가**

`app/test/features/challenge_space/widgets/calendar_day_cell_test.dart` 의 `buildCell` helper 에 `bool isToday = false` 파라미터를 추가하고 `CalendarDayCell` 생성자에 전달하도록 수정. 그리고 group 안에 다음 테스트 케이스 두 개 추가:

```dart
testWidgets('renders today indicator when isToday is true', (tester) async {
  await tester.pumpWidget(buildCell(day: 25, isToday: true));

  expect(find.text('25'), findsOneWidget);

  // day 숫자 Text 의 가장 가까운 Container 에 primary 색 원형 decoration 이 있어야 함
  final textWidget = tester.widget<Text>(find.text('25'));
  expect(textWidget.style?.fontWeight, FontWeight.bold);

  // 원형 배지 컨테이너 검증
  final badge = tester.widget<Container>(
    find.ancestor(of: find.text('25'), matching: find.byType(Container)).first,
  );
  final decoration = badge.decoration as BoxDecoration;
  expect(decoration.shape, BoxShape.circle);
  expect(decoration.color, isNotNull);
});

testWidgets('renders today indicator above season icon when both apply', (tester) async {
  final entry = DayEntry(
    date: '2026-04-25',
    verifiedMembers: ['u1', 'u2', 'u3'],
    allCompleted: true,
    seasonIconType: 'spring',
  );

  await tester.pumpWidget(buildCell(day: 25, entry: entry, isToday: true));

  expect(find.text('25'), findsOneWidget);
  expect(find.text('🌸'), findsOneWidget);
});
```

`buildCell` 시그니처도 수정:

```dart
Widget buildCell({int day = 1, DayEntry? entry, bool isToday = false}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 50,
        height: 60,
        child: CalendarDayCell(
          day: day,
          entry: entry,
          members: testMembers,
          isToday: isToday,
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

```bash
cd app && flutter test test/features/challenge_space/widgets/calendar_day_cell_test.dart
```

Expected: 컴파일 에러 — `CalendarDayCell` 에 `isToday` 파라미터 없음.

- [ ] **Step 3: CalendarDayCell 에 isToday 파라미터 + 원형 배지 구현**

`app/lib/features/challenge_space/widgets/calendar_day_cell.dart` 전체를 다음으로 교체:

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/season_icons.dart';
import '../models/calendar_data.dart';

class CalendarDayCell extends StatelessWidget {
  final int day;
  final DayEntry? entry;
  final List<CalendarMember> members;
  final bool isToday;
  final VoidCallback? onTap;

  const CalendarDayCell({
    super.key,
    required this.day,
    this.entry,
    required this.members,
    this.isToday = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDayLabel(context),
            const SizedBox(height: 2),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLabel(BuildContext context) {
    final theme = Theme.of(context);
    if (isToday) {
      return Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$day',
          style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }
    return Text(
      '$day',
      style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (entry == null) {
      return const SizedBox.shrink();
    }

    // 전원 인증: 계절 아이콘 표시
    if (entry!.allCompleted && entry!.seasonIconType != null) {
      return Text(
        SeasonIcons.getIcon(entry!.seasonIconType),
        style: const TextStyle(fontSize: 20),
      );
    }

    // 일부 인증: 인증한 멤버 프로필 썸네일 표시
    if (entry!.verifiedMembers.isNotEmpty) {
      return _buildMemberThumbnails(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildMemberThumbnails(BuildContext context) {
    final verifiedMemberIds = entry!.verifiedMembers.toSet();
    final verifiedMembersList = members
        .where((m) => verifiedMemberIds.contains(m.id))
        .toList();

    // 최대 3명까지만 표시
    final displayMembers = verifiedMembersList.take(3).toList();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 1,
      runSpacing: 1,
      children: displayMembers.map((member) {
        return _MemberAvatar(member: member);
      }).toList(),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final CalendarMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 8,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: member.profileImageUrl != null
          ? NetworkImage(member.profileImageUrl!)
          : null,
      child: member.profileImageUrl == null
          ? Text(
              member.nickname.isNotEmpty ? member.nickname[0] : '?',
              style: const TextStyle(fontSize: 7),
            )
          : null,
    );
  }
}
```

- [ ] **Step 4: 테스트 실행해 PASS 확인**

```bash
cd app && flutter test test/features/challenge_space/widgets/calendar_day_cell_test.dart
```

Expected: 6 tests passed (기존 4 + 신규 2). 모든 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add app/lib/features/challenge_space/widgets/calendar_day_cell.dart \
        app/test/features/challenge_space/widgets/calendar_day_cell_test.dart
git commit -m "feat(front): CalendarDayCell 에 isToday 원형 배지 추가"
```

---

## Task 2: CalendarGrid 가 오늘 셀에만 isToday 전달 (TDD)

**Files:**
- Create: `app/test/features/challenge_space/widgets/calendar_grid_test.dart`
- Modify: `app/lib/features/challenge_space/widgets/calendar_grid.dart`

- [ ] **Step 1: 실패 테스트 작성**

`app/test/features/challenge_space/widgets/calendar_grid_test.dart` 신규 파일:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/challenge_space/models/calendar_data.dart';
import 'package:haeda/features/challenge_space/widgets/calendar_day_cell.dart';
import 'package:haeda/features/challenge_space/widgets/calendar_grid.dart';

void main() {
  final testMembers = [
    CalendarMember(id: 'u1', nickname: '김철수', profileImageUrl: null),
  ];

  Widget buildGrid({required int year, required int month}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CalendarGrid(
            year: year,
            month: month,
            days: const [],
            members: testMembers,
          ),
        ),
      ),
    );
  }

  group('CalendarGrid', () {
    testWidgets('marks exactly today cell with isToday when current month', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(buildGrid(year: now.year, month: now.month));

      final cells = tester.widgetList<CalendarDayCell>(find.byType(CalendarDayCell));
      final todayCells = cells.where((c) => c.isToday).toList();

      expect(todayCells.length, 1);
      expect(todayCells.first.day, now.day);
    });

    testWidgets('marks no cell with isToday when not current month', (tester) async {
      final now = DateTime.now();
      // 다음 달 (12월이면 다음 해 1월)
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;

      await tester.pumpWidget(buildGrid(year: nextYear, month: nextMonth));

      final cells = tester.widgetList<CalendarDayCell>(find.byType(CalendarDayCell));
      final todayCells = cells.where((c) => c.isToday).toList();

      expect(todayCells.length, 0);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

```bash
cd app && flutter test test/features/challenge_space/widgets/calendar_grid_test.dart
```

Expected: 첫 테스트 FAIL — `todayCells.length` 가 0 (아직 isToday 전달 안 함). 두 번째 테스트는 우연히 PASS 가능.

- [ ] **Step 3: CalendarGrid 에서 isToday 계산해 전달**

`app/lib/features/challenge_space/widgets/calendar_grid.dart` 의 `build` 메서드에서 다음 두 부분만 변경:

`build()` 시작부에 today 계산 추가 (`final theme = Theme.of(context);` 다음 줄):

```dart
final today = DateTime.now();
final isCurrentMonth = today.year == year && today.month == month;
```

`itemBuilder` 의 `CalendarDayCell` 반환 부분에 `isToday` 전달:

```dart
return CalendarDayCell(
  day: day,
  entry: entry,
  members: members,
  isToday: isCurrentMonth && today.day == day,
  onTap: onDayTap != null ? () => onDayTap!(dateStr) : null,
);
```

- [ ] **Step 4: 테스트 실행해 PASS 확인**

```bash
cd app && flutter test test/features/challenge_space/widgets/calendar_grid_test.dart
```

Expected: 2 tests passed.

- [ ] **Step 5: 전체 테스트 회귀 확인**

```bash
cd app && flutter test
```

Expected: 모든 테스트 PASS. 기존 `calendar_day_cell_test.dart` / `speech_bubble_test.dart` / `widget_test.dart` 영향 없음.

- [ ] **Step 6: 커밋**

```bash
git add app/lib/features/challenge_space/widgets/calendar_grid.dart \
        app/test/features/challenge_space/widgets/calendar_grid_test.dart
git commit -m "feat(front): CalendarGrid 가 오늘 셀에 isToday 전달"
```

---

## Task 3: Static analysis + iOS 시뮬레이터 시각 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: flutter analyze**

```bash
cd app && flutter analyze
```

Expected: `No issues found!` 또는 본 PR 과 무관한 기존 경고만. 새 경고가 발생하면 수정 후 재실행.

- [ ] **Step 2: iOS 시뮬레이터 clean install**

`haeda-ios-deploy` 스킬을 호출. 스킬이 다음을 자동 수행:

1. booted simulator 디바이스 ID 확인
2. bundle id 추출
3. 앱 terminate + uninstall
4. `flutter clean && flutter pub get && flutter build ios --simulator`
5. `xcrun simctl install` + `xcrun simctl launch`

Expected: 시뮬레이터에 앱이 새로 설치되고 실행됨.

- [ ] **Step 3: 시각 확인 + 스크린샷**

시뮬레이터에서 챌린지 스페이스 진입 → 월 캘린더에서 오늘 날짜(2026-04-25) 셀 확인:
- day 숫자 `25` 가 primary 색 원형 배경 + 흰 글씨 + bold 로 표시됨
- 다른 날짜는 기존 회색 텍스트 그대로
- 오늘 셀에 시즌 아이콘 또는 멤버 썸네일이 있을 경우 그 아래에 정상 렌더됨

스크린샷 저장:

```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
xcrun simctl io "$DEVICE_ID" screenshot docs/reports/screenshots/2026-04-25-feature-calendar-today-indicator-01.png
```

확인 후 스크린샷을 git 에 추가:

```bash
git add docs/reports/screenshots/2026-04-25-feature-calendar-today-indicator-01.png
```

(커밋은 Task 4 의 보고서와 함께)

---

## Task 4: 작업 보고서 작성 + 최종 커밋·푸시

**Files:**
- Create: `docs/reports/2026-04-25-feature-calendar-today-indicator.md`

- [ ] **Step 1: 보고서 작성**

`docs/reports/2026-04-25-feature-calendar-today-indicator.md`:

```markdown
# 챌린지 캘린더 오늘 날짜 표시

- **Date**: 2026-04-25
- **Worktree (수행)**: feature
- **Worktree (영향)**: feature
- **Role**: feature

## Request

사용자: "챌린지 달력에 오늘 날짜를 표시해줘"

## Root cause / Context

챌린지 스페이스 월 캘린더의 셀에는 day 숫자, 시즌 아이콘, 멤버 썸네일만 있고
오늘 날짜를 시각적으로 구분하는 표시가 없어 사용자가 캘린더에서 현재 위치를
즉각 파악할 수 없었음.

## Actions

1. `CalendarDayCell` 에 `bool isToday` 파라미터 추가 (기본값 `false`).
   `isToday: true` 일 때 day 숫자를 20×20 primary 색 원형 컨테이너에 감싸고
   onPrimary 색 + bold 적용. (`app/lib/features/challenge_space/widgets/calendar_day_cell.dart`)
2. `CalendarGrid` 에서 `DateTime.now()` 를 빌드 시점에 1회 계산해
   `isCurrentMonth && today.day == day` 일 때만 셀에 `isToday: true` 전달.
   (`app/lib/features/challenge_space/widgets/calendar_grid.dart`)
3. 위젯 테스트 추가: `calendar_day_cell_test.dart` 에 isToday 분기 검증 케이스 2개,
   `calendar_grid_test.dart` 신규로 그리드의 isToday 전달 검증 2개.

관련 spec: `docs/superpowers/specs/2026-04-25-calendar-today-indicator-design.md`
관련 plan: `docs/superpowers/plans/2026-04-25-calendar-today-indicator.md`

## Verification

- `flutter test`: <PASS 카운트 인용>
- `flutter analyze`: <결과 인용>
- iOS 시뮬레이터 clean install + 챌린지 스페이스 화면에서 4월 25일 셀의
  primary 원형 배지 시각 확인. 스크린샷:
  `docs/reports/screenshots/2026-04-25-feature-calendar-today-indicator-01.png`

## Follow-ups

없음. 다른 화면에 캘린더성 위젯이 추가되면 동일 패턴 적용 검토.

## Related

- Spec: `docs/superpowers/specs/2026-04-25-calendar-today-indicator-design.md`
- Plan: `docs/superpowers/plans/2026-04-25-calendar-today-indicator.md`
- 참조 보고서:
  - `docs/reports/2026-04-19-front-challenge-room-scene.md`
  - `docs/reports/2026-04-05-emoji-to-material-icons.md`
```

> Verification 섹션의 `<PASS 카운트 인용>` 등은 Task 3 실행 결과를 그대로 인용. 빈 placeholder 로 두지 말 것.

- [ ] **Step 2: 보고서 + 스크린샷 커밋**

```bash
git add docs/reports/2026-04-25-feature-calendar-today-indicator.md \
        docs/reports/screenshots/2026-04-25-feature-calendar-today-indicator-01.png
git commit -m "docs(report): 챌린지 캘린더 오늘 날짜 표시 작업 보고서"
```

- [ ] **Step 3: `/commit` 스킬로 PR 자동 머지**

남아 있는 변경이 없는 상태에서 `/commit` 스킬을 호출. 스킬이 rebase + push + PR 생성 + 자동 머지를 수행.

Expected: PR 자동 머지 완료, `worktree-feature` 브랜치가 main 에 반영됨.

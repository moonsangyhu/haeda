# 연속 기록 페이지 (Streak Page) 디자인

- 작성일: 2026-04-27
- 작성자: feature 워크트리 (auto)
- 상태: ready
- 범위: full-stack (Flutter + FastAPI)

## 1. 배경

상단 `StatusBar` 의 streak pill (`fire/sleep + 일수`) 은 현재 표시만 가능하고 탭 인터랙션이 없다. 사용자는 "내가 며칠 연속으로 챌린지를 인증해 왔는지" 와 "어느 날을 빠뜨렸는지" 를 한 화면에서 확인할 수 없다. 동기부여(streak 유지) 와 회고(어디서 끊겼는지) 양쪽 목적을 동시에 충족하는 전용 페이지가 필요하다.

## 2. 사용자 흐름

```
내 방 / 피드 / 설정 등 (StatusBar 노출 화면)
    │
    │  StatusBar 의 streak pill 을 탭
    ▼
/streak  연속 기록 페이지
    │
    │  (← AppBar 뒤로가기)
    ▼
이전 화면으로 복귀
```

`StatusBar` 가 노출되는 모든 화면(`MainShell` 의 5 개 탭)에서 동일하게 진입 가능. 다른 pill (챌린지/젬) 은 본 작업 범위 밖 — 사용자가 추후 별도 요청 시 같은 패턴으로 확장 예정.

## 3. 화면 구조

```
┌─────────────────────────────────┐
│ ←  연속 기록                     │  AppBar
├─────────────────────────────────┤
│                                  │
│            14                    │  큰 streak 숫자 (display large)
│         일 연속                   │  작은 라벨 (body medium, secondary)
│                                  │
├─────────────────────────────────┤
│   ◀     2026년 4월     ▶         │  월 네비게이션
│                                  │
│  일 월 화 수 목 금 토             │  요일 헤더
│         1  2  3  4  5            │
│  6  7  8  9 10 11 12             │
│ 13 14 15 16 17 18 19             │
│ 20 21 22 23 24 25 26             │
│ 27 28 29 30                      │
│                                  │
└─────────────────────────────────┘
```

- **고정 6 주 × 7 일** 그리드 (안정적 높이), **일요일 시작**.
- 월 첫째 주 이전 / 마지막 주 이후의 빈 셀은 빈 칸으로 렌더 (다른 월 날짜를 채우지 않음).
- 셀 1 칸 안에 날짜 숫자 + 상태 아이콘 (있을 때).

### 3.1 셀 상태별 시각

| status | 표시 |
|---|---|
| `success` | 날짜 숫자 + `assets/icons/fire.svg` (16×16) |
| `failure` | 날짜 숫자 + `assets/icons/ice.svg` (16×16, color `#4FC3F7`) |
| `today_pending` | 날짜 숫자만, `Border.all(color: theme.primary, width: 2)` |
| `future` | 날짜 숫자만, opacity 0.3 |
| `before_join` | 날짜 숫자만, opacity 0.3 |

오늘이 인증 완료 상태라면 `status = success` 가 우선. 오늘 날짜 자체의 시각적 강조(테두리)는 클라이언트가 `date == DateTime.now()` 로 판단해서 추가로 입힘 — 즉 success 셀 + 오늘 = `🔥` 아이콘 + 굵은 테두리.

## 4. 백엔드 API

### `GET /me/streak/calendar?year={year}&month={month}` (신규)

전역 streak 캘린더를 월 단위로 반환한다.

**Query parameters:**
- `year`: int, 2024 ≤ year ≤ 2100
- `month`: int, 1 ≤ month ≤ 12

**Response (200):**
```json
{
  "data": {
    "streak": 14,
    "first_join_date": "2025-12-03",
    "year": 2026,
    "month": 4,
    "days": [
      {"date": "2026-04-01", "status": "success"},
      {"date": "2026-04-02", "status": "failure"},
      {"date": "2026-04-27", "status": "today_pending"},
      {"date": "2026-04-28", "status": "future"}
    ]
  }
}
```

**필드:**
- `streak`: 현재 전역 streak (`user_stats_service.calculate_global_streak` 와 동일 로직 재사용)
- `first_join_date`: `MIN(ChallengeMember.joined_at)::date`. 챌린지 참여 이력 없으면 `null`.
- `year`, `month`: 요청 echo
- `days`: 해당 월의 모든 날짜, `date` 오름차순. 길이는 28~31

**status 결정 로직:**
1. `date > today` → `future`
2. `first_join_date is null` 또는 `date < first_join_date` → `before_join`
3. 그 외 — `verifications` 테이블에 `(user_id, date)` 매칭이 있으면 → `success`
4. `date == today` 이고 매칭 없음 → `today_pending`
5. `date < today` 이고 매칭 없음 → `failure`

**Error:**
- `400 INVALID_MONTH` — year/month 범위 밖 (FastAPI Query validator 가 422 로 반환할 수도 있음 — 명시적으로 400 + INVALID_MONTH 로 통일)
- `401 UNAUTHORIZED` — 토큰 없음 (`get_current_user_id` 의존성)

**서비스 위치:** `server/app/services/streak_calendar_service.py` (신규).

기존 서비스와의 분리 이유:
- `streak_service.py` — 챌린지 단위 streak (verification 작성 시 호출)
- `user_stats_service.py` — `/me/stats` 의 단일 요약값 (streak 전역 + 잔여 통계)
- `calendar_service.py` — 챌린지 단위 멤버별 월 캘린더 (`/challenges/{id}/calendar`)
- `streak_calendar_service.py` (신규) — 유저 단위 전역 월 캘린더

책임이 모두 다르고, 응답 schema 도 다르다. 합치면 한 파일이 4 종 entity 를 다루게 되어 분리한다.

**Schema:** `server/app/schemas/streak_calendar.py` (신규) — `StreakCalendarResponse`, `StreakDay`, `DayStatus` enum.

## 5. 프론트엔드 구조

```
app/lib/features/streak/
├── models/
│   ├── streak_calendar.dart         # freezed: StreakCalendar, StreakDay
│   └── day_status.dart              # enum DayStatus
├── providers/
│   └── streak_calendar_provider.dart
├── screens/
│   └── streak_screen.dart
└── widgets/
    ├── streak_header.dart
    └── streak_calendar_grid.dart

app/assets/icons/ice.svg              # 신규 (파란 얼음 결정)
```

### 5.1 모델

```dart
enum DayStatus { success, failure, todayPending, future, beforeJoin }

@freezed
class StreakCalendar with _$StreakCalendar {
  const factory StreakCalendar({
    required int streak,
    @JsonKey(name: 'first_join_date') DateTime? firstJoinDate,
    required int year,
    required int month,
    required List<StreakDay> days,
  }) = _StreakCalendar;
  factory StreakCalendar.fromJson(Map<String, dynamic> json) =>
      _$StreakCalendarFromJson(json);
}

@freezed
class StreakDay with _$StreakDay {
  const factory StreakDay({
    required DateTime date,
    required DayStatus status,
  }) = _StreakDay;
  factory StreakDay.fromJson(Map<String, dynamic> json) =>
      _$StreakDayFromJson(json);
}
```

JSON enum 매핑은 `@JsonValue('success')` 등으로 snake_case 매칭.

### 5.2 Provider

```dart
final streakCalendarProvider = FutureProvider.family<StreakCalendar, ({int year, int month})>(
  (ref, ym) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get(
      '/me/streak/calendar',
      queryParameters: {'year': ym.year, 'month': ym.month},
    );
    return StreakCalendar.fromJson(response.data as Map<String, dynamic>);
  },
);
```

월 이동 시 새 family key 로 fetch. autoDispose 는 사용하지 않음 (월 토글 시 캐시 유지).

### 5.3 Screen

`StreakScreen` (StatefulWidget):
- state: `_currentMonth: DateTime` (year, month 만 의미 있음)
- 월 nav 좌/우 버튼이 `_currentMonth` 변경 → `streakCalendarProvider` 재구독
- 우 버튼: `_currentMonth.year > today.year || (==year && month > today.month)` 면 disabled (미래 월 차단)
- 본문 = `StreakHeader(streak)` + `StreakCalendarGrid(calendar)`

### 5.4 StatusBar 변경

`app/lib/features/status_bar/widgets/status_bar.dart` — streak pill 만 `InkWell` 로 감쌈:

```dart
Material(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(14),
  child: InkWell(
    onTap: () => context.push('/streak'),
    borderRadius: BorderRadius.circular(14),
    child: Semantics(...기존 streak pill...),
  ),
),
```

다른 pill (챌린지/젬) 은 미변경.

### 5.5 Router

`app/lib/app.dart` 의 detail 화면 그룹 끝에 추가:

```dart
GoRoute(
  path: '/streak',
  builder: (context, state) => const StreakScreen(),
),
```

## 6. 데이터 흐름

```
StatusBar (탭)
    └─ context.push('/streak')
         └─ StreakScreen
              └─ ref.watch(streakCalendarProvider((year: Y, month: M)))
                   └─ dio.get('/me/streak/calendar?year=Y&month=M')
                        └─ FastAPI router
                             └─ streak_calendar_service.get_calendar
                                  ├─ MIN(ChallengeMember.joined_at) → first_join_date
                                  ├─ user_stats_service.calculate_global_streak → streak
                                  └─ SELECT DISTINCT verification.date WHERE user_id=… AND BETWEEN month_start AND month_end
                                       → days 배열 생성
```

## 7. Edge cases

| 케이스 | 처리 |
|---|---|
| 챌린지 한 번도 참여 안 한 유저 | `first_join_date = null`, 모든 날짜 `before_join`. UI 에서는 비활성 회색 캘린더 + streak `0`. |
| 가입일이 미래 월에 있음 (이전 월 조회) | `first_join_date` 는 그대로 미래 날짜로 반환. 모든 날짜 `before_join`. |
| 현재 월보다 미래 월 조회 시도 | UI 에서 차단 (우 화살표 disabled). API 자체는 허용 — 모든 날짜 `future` 반환. |
| 28 일 (2 월), 29 일 (윤달 2 월), 30/31 일 월 | `calendar.monthrange` 로 정확히 마지막 날 계산 — 기존 `calendar_service` 와 동일 패턴. |
| 시간대 차이 | `today = date.today()` (서버 timezone). 클라이언트는 디바이스 로컬 `DateTime.now()` — MVP 기준 KST 단일 사용자 가정으로 mismatch 무시. |
| 같은 날 여러 챌린지 인증 | DISTINCT 로 한 칸 = 1 success. |
| 인증 후 즉시 페이지 진입 | provider 캐시가 stale — 진입 시 `ref.invalidate` 또는 `RefreshIndicator` 로 새로고침. **MVP**: provider family 는 page 진입 시마다 새로 fetch (cache TTL 0). 추후 최적화 여지. |

## 8. 테스트

### 8.1 백엔드 (`server/tests/test_streak_calendar.py`)

| 케이스 | 검증 |
|---|---|
| 챌린지 미참여 유저 | `first_join_date == null`, 모든 day status `before_join` |
| 가입일 == 오늘, 오늘 인증 X | 오늘 = `today_pending`, 이전 = `before_join`, 미래 = `future` |
| 가입일 == 오늘, 오늘 인증 O | 오늘 = `success`, 이전 = `before_join` |
| 가입일이 월 시작 전 | 월의 모든 과거 날짜 = success/failure 분류 |
| 한 챌린지에서 verification 있는 어제 | 어제 = `success` |
| 활성 챌린지 있고 어제 인증 X | 어제 = `failure` |
| 같은 날 두 챌린지 인증 | 한 칸만 success (중복 없음) |
| year=1900 또는 year=2200 또는 month=0/13 | 400 INVALID_MONTH |
| 토큰 없음 | 401 |

### 8.2 프론트엔드 (`app/test/features/streak/`)

| 파일 | 케이스 | 검증 |
|---|---|---|
| `streak_header_test.dart` | streak 14 입력 | "14" 텍스트 + "일 연속" 라벨 finder |
| `streak_calendar_grid_test.dart` | success 셀 | `find.byType(SvgPicture)` 가 fire.svg 경로 |
| `streak_calendar_grid_test.dart` | failure 셀 | `find.byType(SvgPicture)` 가 ice.svg 경로 |
| `streak_calendar_grid_test.dart` | today_pending 셀 | container decoration border 두께 2 |
| `streak_calendar_grid_test.dart` | future 셀 | opacity 0.3 |
| `streak_calendar_grid_test.dart` | 월 nav 우 화살표 — 미래 월 | IconButton.onPressed == null |
| `status_bar_streak_tap_test.dart` | streak pill 탭 → push | mock GoRouter, 호출 검증 |

### 8.3 통합 검증

- `docker compose up --build -d backend && curl -fsS http://localhost:8000/health` → 200
- `cd app && flutter test` → all green
- iOS simulator clean install (terminate→uninstall→flutter clean→pub get→build→install→launch)
- 시뮬레이터 시나리오:
  1. 로그인 → 내 방
  2. StatusBar streak pill 탭 → `/streak` 진입
  3. 큰 숫자 + 캘린더 렌더링 확인 → 스크린샷
  4. 좌 화살표로 이전 월 → 캘린더 갱신 → 스크린샷
  5. 뒤로가기 → 내 방 복귀

## 9. 비범위 (Out of Scope)

- 챌린지 pill / 젬 pill 의 탭 인터랙션 — 사용자 후속 요청 시 별도 슬라이스
- 캐릭터 / 배지 / 마일스톤 표시 (b/c 안에서 의도적으로 a 만 채택)
- 최고 streak 기록 표시
- 캘린더 셀 탭 시 그 날의 verification 목록 모달 (회고 기능)
- 월별 무한 스크롤
- 시간대 multi-region 대응

## 10. 위험 / 결정사항

- **Provider 캐싱 정책**: family 캐시를 유지하면 인증 직후 stale 가능. MVP 는 매 진입 fetch 로 단순화. 사용자가 stale 문제 제기 시 Riverpod `invalidate` + 인증 mutation hook 으로 대응.
- **status enum 5 종**: client/server 가 같은 5 종을 알아야 — schema 변경 시 동기화 필수. 향후 추가(예: `partial`) 시 client default 처리 필요.
- **`first_join_date` 정의**: `ChallengeMember.joined_at` 의 최소값. 유저가 챌린지를 떠난 후 다시 참여한 경우도 가장 이른 날을 사용 (의미: "내가 챌린지 인증 시스템을 처음 쓴 날").

## 11. 참고

- `app/lib/features/status_bar/widgets/status_bar.dart` — 진입 트리거 추가 위치
- `app/lib/app.dart` — 라우트 추가
- `server/app/services/user_stats_service.py` — `calculate_global_streak` 재사용
- `server/app/services/calendar_service.py` — month 처리 패턴 참고
- `docs/api-contract.md` — `/me/stats` 와 동일 envelope 패턴 따름 (`{data: ...}`)

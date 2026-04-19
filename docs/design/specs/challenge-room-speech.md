---
slug: challenge-room-speech
status: ready
created: 2026-04-19
area: full-stack
depends-on: challenge-room-social
---

# Challenge Room — Character Speech Bubble

## Overview

챌린지 방(ChallengeSpaceScreen 상단의 싸이월드 미니룸 공유 공간)에 모인 캐릭터가 **하얀 말풍선**으로 짧은 한마디를 주고받을 수 있게 한다. 한 번에 한 명만 말하고, 여러 명이 있으면 번갈아 말하며, 방에 머무는 동안 계속 순환한다.

- **말 출처**: 사용자 입력 → 서버 저장(TTL). 재접속해도 만료 전까지 유지.
- **반복 규칙**: 각 발언은 **3회 반복** × **3초 표시**. 한 명의 턴이 끝나면 다음 발언자로 넘어간다.
- **MVP 스코프 밖**: 현재 `docs/prd.md` 에 없는 **P2 확장**. 본 문서는 front + backend + qa 워크트리를 위한 사양이며, 실제 구현 전에 `prd.md` / `api-contract.md` / `domain-model.md` 갱신 여부는 사용자 승인을 받아야 한다.

## Design Concept

```
 ┌──────────────────────────────────────┐
 │  천장 몰딩        ✨ 챌린지제목 ✨     │
 │  ┌───────┐  🕐  ┌─────┐ ┌─────────┐│
 │  │ 창문  │      │달력판│ │ 게시판   ││
 │  │ (하늘) │      │04/19│ │ 📌📝   ││
 │  └───────┘      └─────┘ └─────────┘│
 │═════════════════════════════════════│
 │                                     │
 │            ╭───────────╮            │
 │            │ 오늘 화이팅! │            │  ← 하얀 말풍선 (한 명만)
 │            ╰─────┬─────╯            │
 │                  ▽                  │  ← 꼬리
 │   😊    😴    🎉👈    😤            │  ← 발언자 표시 강조(미세)
 │  철수   영희   민수   지은           │
 │  (인증✓) (미인증) (인증✓) (미인증)    │
 │         ╭────────────╮             │
 │         │   소파/러그  │             │
 │         ╰────────────╯             │
 └──────────────────────────────────────┘
        [오늘 3/5명 인증 완료]
 ┌──────────────────────────────────────┐
 │ 💬 내가 한 말: "오늘도 화이팅" · 지우기  │ ← 내가 활성 발언 있을 때만
 ├──────────────────────────────────────┤
 │ [방에 한마디 보내기........]   [전송] │ ← 항상 보이는 한 줄 입력 바
 └──────────────────────────────────────┘
```

한 턴에 한 캐릭터 위에만 말풍선이 뜬다. 나머지 캐릭터는 평소 애니메이션(bounce / 졸기) 유지. 발언 중인 캐릭터는 **미세한 스케일 1.0 → 1.04 → 1.0** 으로 시청각 주의를 끌되, 전체 레이아웃은 흔들리지 않는다.

방 scene 바로 아래에 **카톡식 인라인 입력 바**가 항상 한 줄로 노출된다. 별도 진입 동작(롱-프레스/모달) 없이 즉시 텍스트를 입력해 전송할 수 있다.

## Speech Bubble UI Spec

| 항목 | 값 |
|------|-----|
| 배경색 | `Colors.white` (다크 모드에서도 흰색 유지 — "하얀 말풍선" 요구) |
| 테두리 | 1px `Color(0x26000000)` (onSurface 15% opacity) |
| 모서리 | `BorderRadius.circular(10)` |
| 그림자 | `BoxShadow(color: Color(0x14000000), blur: 6, y: 2)` |
| 꼬리 | 하단 중앙 삼각형 8×6dp, 배경·테두리 연장 |
| 텍스트 스타일 | `fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF212121), height: 1.3` |
| 내부 패딩 | `EdgeInsets.symmetric(horizontal: 10, vertical: 6)` |
| 최대 너비 | `characterSize * 3`, 초과 시 `maxLines: 2, overflow: ellipsis` |
| 최대 글자수 | 40자 (서버 검증 + 클라이언트 카운터) |
| 위치 | 캐릭터 스택 내부 `top: -characterSize * 0.45`, 가로 중앙 정렬 |
| z-order | 왕관(`isCreator`) · Zzz(`unverified`) · 인증 배지보다 **위**. clipBehavior: Clip.none 유지 |
| 다크 모드 | 배경 흰색 유지, 텍스트만 `Color(0xFF212121)` 고정 |

꼬리(tail)는 `CustomPaint` 한 장으로 삼각형 + 테두리를 그려 본체 테두리와 자연스럽게 이어지게 한다.

## Input Flow (말 입력)

### 진입 방식 — 카톡식 인라인 입력 바

방 scene 바로 아래에 **항상 보이는 한 줄 입력 바**(`SpeechInputBar`)를 노출한다. 카카오톡 채팅방 하단의 입력 줄과 동일한 멘탈 모델.

- **롱-프레스·모달·바텀시트 진입 없음.** 사용자는 입력 바를 탭 → 바로 타이핑 → 전송.
- 캐릭터 탭/롱-프레스 인터랙션은 기존 `challenge-room-social.md` 의 정의(탭 = 반응 / 콕찌르기, 롱-프레스 = 미정)를 그대로 유지. 본 디자인은 캐릭터에 어떤 핸들러도 추가하지 않는다.
- 미인증 상태(졸고 있는 본인)에서도 입력 가능 — 졸면서 잠꼬대하는 표현으로 의도된 동작.

### SpeechInputBar 구조

```
방 scene
─────────────────────────────────────────
[옵션] 💬 내가 한 말: "오늘도 화이팅" · 지우기   ← 내 활성 발언이 있을 때만 한 줄
─────────────────────────────────────────
[ 방에 한마디 보내기 .................. ] (▶)
                                  0/40    전송
─────────────────────────────────────────
... 캘린더 / 멤버 리스트 등 기존 컨텐츠 계속 ...
```

- **위치**: `ChallengeRoomScene` 직하부, 같은 ScrollView 안. scene 과 함께 스크롤된다 (sticky bottom 아님). 사용자 표현 "캐릭터 방 밑에 한 줄" 충실.
- **높이**: 본체 56dp + 활성 발언 인디케이터 28dp = 최대 84dp.
- **활성 발언 인디케이터** (`MyActiveSpeechHint`): 내가 등록한 발언이 만료되지 않은 동안만 입력 바 위에 한 줄로 표시. 우측 끝에 `[지우기]` 텍스트 버튼.
- **입력 바 본체**:
  - 좌측: 단일 줄 `TextField` — placeholder `"방에 한마디 보내기"` (12dp, `Color(0xFF9E9E9E)`).
  - `maxLength: 40`, `maxLines: 1`, `keyboardType: TextInputType.text`, `textInputAction: TextInputAction.send`.
  - `inputFormatters`: 줄바꿈 차단 (`FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))`).
  - 우측 하단: `n/40` 카운터 — 입력 중에만 표시(빈 상태 숨김). 30자 초과 시 색을 `Color(0xFFEF5350)`.
  - 우측: 전송 버튼 (`IconButton` 아이콘 `Icons.send_rounded`).
    - 비활성: 회색 (`Color(0xFFBDBDBD)`)
    - 활성: 채워진 입력이 있을 때 primary color
    - 탭 또는 키보드 `send` 액션 → `POST /challenges/{id}/room-speech` → 응답으로 local queue 갱신, 내 턴을 **다음 턴**으로 승격, 입력 필드 비움, 키보드 유지(연속 메시지 가능).
- **시각 스타일**:
  - 배경: `Theme.surface` (다크 모드 대응)
  - 입력 영역: 모서리 18dp, 1px 소프트 테두리, 좌우 패딩 14dp
  - scene 과 입력 바 사이 1px 헤어라인 separator
- **빈 큐 / 첫 발화**: 입력 바는 항상 동일 — 큐 상태와 무관하게 비활성 placeholder 만 다르지 않게 동작.
- **전송 직후**: 토스트 없음(카톡 패턴 — 메시지가 화면에 즉시 반영되는 것이 피드백). 내 캐릭터 위 말풍선이 "다음 턴"에 등장.
- **TTL 안내**: 입력 바 본체에는 표시하지 않음(공간 절약). `MyActiveSpeechHint` 옆에 작은 시계 아이콘 + 툴팁(`오늘 자정까지 보여요`)을 부가 정보로 제공.

### 키보드·스크롤 동작

- 입력 바 탭 → 키보드 올라옴 → `Scrollable.ensureVisible` 로 입력 바가 키보드 바로 위에 보이도록 자동 스크롤.
- 키보드 dismiss: 빈 영역 탭 또는 백 버튼 → `unfocus()`.
- iOS 안전영역(home indicator) 패딩 자동 적용.

### 지우기

- `MyActiveSpeechHint` 의 `[지우기]` 버튼 탭 → 즉시 `DELETE /challenges/{id}/room-speech` → local queue 에서 내 항목 제거.
- 컨펌 모달 없음(되돌리기 쉬움 — 다시 입력하면 됨).

## Round-Robin Queue 로직

```
queue        = members with non-expired speech (server order = created_at asc)
currentIdx   = 0
isRunning    = true while ChallengeSpaceScreen mounted and scene visible

loop {
  if queue.isEmpty: sleep 2s and poll; continue

  speaker = queue[currentIdx % queue.length]
  for i in 1..3 {
    emit(activeSpeakerId = speaker.id, text = speaker.content)
    fade-in 180ms
    hold 3000ms
    fade-out 180ms
    gap 120ms
  }
  emit(activeSpeakerId = null)
  gap 500ms
  currentIdx += 1
}
```

- 빈 큐: 말풍선 없음, 2초마다 poll 또는 다음 이벤트 대기.
- 큐 1명: 혼자 3회 × 3초 = 약 10초 후 500ms gap, 다시 3회 반복 (계속).
- **새 메시지 서버 수신**: polling 또는 내 POST 응답으로 들어오면 **현재 턴 종료 후** queue 뒤에 삽입. 현재 발화 중간에 끼어들지 않는다.
- **내가 방금 POST 한 경우**: 내 speaker를 queue 에 추가하고 `currentIdx = queue.indexOf(me) - 1` 로 설정해 다음 턴이 나로 시작 (즉시 피드백 보장).
- **메시지 만료**: 서버가 expires_at 이 지난 항목은 `GET` 응답에서 제외 → 다음 hydrate 시 자연스럽게 drop. 이미 재생 중인 턴은 끝까지 마친 뒤 제거.

## Controller

```dart
class RoomSpeechController extends ChangeNotifier {
  List<RoomSpeech> queue = [];
  int currentIdx = 0;
  String? activeSpeakerId;
  String? activeText;
  double bubbleOpacity = 0.0;

  Timer? _tick;

  void start()   { /* schedule _runTurn */ }
  void pauseForOffstage() { /* cancel timer, keep state */ }
  void resume()  { /* reschedule */ }
  void onNewSpeech(RoomSpeech s, {bool isMine = false}) { ... }
  void onExpired(String userId) { ... }
  void dispose() { _tick?.cancel(); super.dispose(); }
}
```

- `ChallengeRoomScene` 이 state 로 소유. `RoomCharacter` 에는 `activeSpeaker: bool` + `speechText: String?` + `bubbleOpacity: double` props 로 주입.
- **단일 `Timer.periodic` 하나**로 전체 큐 진행. 캐릭터별 개별 타이머 금지(누수 위험).
- unmount / `didChangeAppLifecycleState -> paused` 에서 `pauseForOffstage` 호출.
- `VisibilityDetector` (이미 프로젝트에 있는 경우) 로 씬이 스크롤되어 화면 밖이면 pause.

## Data Model Proposal (신규)

`RoomSpeech` — backend 워크트리가 구현:

| Field | Type | Note |
|-------|------|------|
| id | uuid | PK |
| challenge_id | uuid | FK → challenges |
| user_id | uuid | FK → users |
| content | varchar(40) | NOT NULL, trim, no newline |
| created_at | timestamptz | default now() |
| expires_at | timestamptz | NOT NULL |

**제약**:
- UNIQUE `(challenge_id, user_id)` — 유저별 챌린지당 활성 1건. 재전송 시 `INSERT ... ON CONFLICT (challenge_id, user_id) DO UPDATE SET content = EXCLUDED.content, created_at = now(), expires_at = EXCLUDED.expires_at`.
- INDEX `(challenge_id, expires_at)` — 만료 필터링 속도 확보.
- `expires_at` 계산: 챌린지의 `day_cutoff_hour` 기준 **다음 cutoff 시각**. cutoff 경계에서 입력한 경우 바로 다음 cutoff 로 계산(즉시 만료 방지).

## API Contract Proposal (신규)

> ⚠️ `docs/api-contract.md` 갱신은 별도 승인 필요. 아래는 구현 워크트리를 위한 제안.

### GET `/challenges/{challenge_id}/room-speech`

- **권한**: 해당 챌린지 멤버만.
- **응답 200**:
  ```json
  {
    "data": [
      {
        "user_id": "u_123",
        "nickname": "철수",
        "content": "오늘 화이팅!",
        "created_at": "2026-04-19T09:00:00Z",
        "expires_at": "2026-04-20T15:00:00Z"
      }
    ]
  }
  ```
- 만료된 항목은 응답에서 제외.

### POST `/challenges/{challenge_id}/room-speech`

- **바디**: `{"content": "오늘 화이팅!"}`
- **검증**: 1 ≤ len(content.strip()) ≤ 40, 줄바꿈 제거.
- **응답 200**:
  ```json
  {
    "data": {
      "content": "오늘 화이팅!",
      "created_at": "2026-04-19T09:00:00Z",
      "expires_at": "2026-04-20T15:00:00Z"
    }
  }
  ```
- **Upsert** (유저당 1건).

### DELETE `/challenges/{challenge_id}/room-speech`

- 내 활성 발언 삭제.
- **응답 200**: `{"data": {"ok": true}}`

### 에러 코드

| 코드 | HTTP | 상황 |
|------|------|------|
| `SPEECH_TOO_LONG` | 422 | content > 40자 |
| `SPEECH_EMPTY` | 422 | trim 후 빈 문자열 |
| `SPEECH_NOT_MEMBER` | 403 | 해당 챌린지 멤버 아님 |
| `SPEECH_RATE_LIMITED` | 429 | 10초 이내 재전송 |

Rate limit: 10초 내 동일 유저 POST 시 429. 서버 메모리 또는 Redis 사용.

## Refresh Strategy

- **최초 진입**: `GET` 1회 → controller.queue hydrate → `start()`.
- **Polling**: 60초 간격 `GET` 재실행. diff 기반으로 queue 업데이트 (기존 재생 중 턴 유지).
- **내 POST 직후**: 응답으로 local queue 갱신 — polling 대기 안 함.
- **실시간(WebSocket)**: 본 디자인 범위 밖. 60초 polling 으로 충분 (느린 소셜 피드백).
- **오프라인**: `GET` 실패 시 last-known queue 로 재생 계속. 토스트·배너 없이 조용히 실패.

## Animation Timing (Flutter)

```dart
// 한 번의 발화 (약 3.36s)
final controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 3360),
);

final opacity = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
    weight: 18,  // 180ms
  ),
  TweenSequenceItem(tween: ConstantTween(1.0), weight: 300),  // 3000ms hold
  TweenSequenceItem(
    tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
    weight: 18,  // 180ms
  ),
]).animate(controller);

final scale = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(begin: 0.92, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack)),
    weight: 18,
  ),
  TweenSequenceItem(tween: ConstantTween(1.0), weight: 318),
]).animate(controller);
```

- 반복 3회, 반복 사이 120ms 검은 gap.
- 발언자 교체 500ms gap.
- 말풍선 내부 텍스트는 반복 내내 동일 — 깜빡임 효과로 주목도 확보.

## Edge Cases

| 상황 | 처리 |
|------|------|
| 방에 혼자 (멤버 1명) | 내가 입력 전까지 말풍선 없음. 입력 바는 평소처럼 사용 가능 — 전송하면 내 버블만 순환. |
| 6명 초과(7~8명) | 큐 로직은 순차라 겹침 없음. 말풍선 위치는 발언자 위로만 렌더. |
| 발언자가 스크롤로 화면 밖 | `VisibilityDetector` 로 `pauseForOffstage()`. 복귀 시 `resume()` (현재 턴 처음부터). |
| 발언 중 앱 백그라운드 | `AppLifecycleState.paused` → pause. foreground 복귀 시 resume + 필요 시 `GET` 리프레시. |
| 빈 content 제출 | 클라이언트 단 즉시 전송 버튼 비활성, 서버도 422(`SPEECH_EMPTY`). |
| 40자 초과 | 클라이언트 단 `maxLength` 로 차단 + 카운터 강조색. 서버 중복 검증. |
| 긴 단어 한 개로 40자 | 말풍선 측에서 `softWrap: true` + 말줄임으로 2줄까지 표시. |
| 욕설·스팸 | MVP 범위 밖. 길이·rate limit 외 필터링 없음. 추후 `차단/신고` 스펙에서 처리. |
| 내 발언 만료 경계 | 자정 직전 발언 시 서버가 **다음 cutoff** 로 계산 (즉시 만료 방지). |
| 발언자 탈퇴·킥 | 멤버에서 빠지면 다음 polling 때 queue 에서 제거. 현재 턴은 마치고 제거. |
| 키보드 올라왔을 때 입력 바 가림 | `Scrollable.ensureVisible` + `MediaQuery.viewInsets.bottom` 패딩으로 입력 바를 키보드 바로 위에 고정. |
| 연속 전송 (rate limit) | 10초 내 재전송 시 서버 429(`SPEECH_RATE_LIMITED`). 입력 바 우측에 작은 인라인 hint "잠시 후 다시" 표시 후 자동 사라짐 (3초). |
| 내 발언 활성 중 새로 전송 | upsert — 기존 발언 덮어쓰기. `MyActiveSpeechHint` 텍스트가 새 내용으로 갱신. |
| 비멤버가 화면 진입 (예: 미래 공개 모드) | 입력 바 비활성 + placeholder "멤버만 한마디 남길 수 있어요". MVP 에서는 멤버만 진입 가능하므로 사실상 미발생. |

## Accessibility

- 말풍선 widget: `Semantics(label: '${nickname}: ${content}', liveRegion: true)`.
- 입력 바: `Semantics(label: '방에 한마디 입력', textField: true)` + 전송 버튼 `Semantics(button: true, label: '전송')`.
- 활성 발언 인디케이터: `Semantics(label: '내 한마디: ${content}, 지우려면 두 번 탭')`.
- `MediaQuery.of(context).disableAnimations == true` 인 경우:
  - fade-in / fade-out 즉시 전환 (opacity 0 ↔ 1).
  - hold 3초 유지.
  - scale 애니메이션 비활성.
- 사운드 없음. 햅틱 없음 (발언 표시는 ambient 피드백이라 개입 최소화).
- 다크 모드에서도 **말풍선은 흰 배경 유지** — 사용자 요구("하얀 색 말풍선"). 텍스트 대비 확보를 위해 본문은 `Color(0xFF212121)` 고정.
- 입력 바는 다크 모드에서 `Theme.surface` 따라감 (말풍선과 다름 — 입력 영역은 시스템 테마 자연스러움 우선).

## Architecture

### New files (front 워크트리)

| Path | 역할 |
|------|------|
| `app/lib/features/challenge_space/widgets/speech_bubble.dart` | `SpeechBubble` widget + 꼬리 `CustomPaint` + 애니메이션 래퍼 (~110 lines) |
| `app/lib/features/challenge_space/widgets/speech_input_bar.dart` | 인라인 한 줄 입력 바 (TextField + 전송 버튼 + `MyActiveSpeechHint`) (~150 lines) |
| `app/lib/features/challenge_space/providers/room_speech_provider.dart` | `RoomSpeechController` + Riverpod `roomSpeechProvider(challengeId)` (~160 lines) |
| `app/lib/features/challenge_space/models/room_speech.dart` | freezed + json_serializable 모델 (~50 lines) |
| `app/lib/features/challenge_space/api/room_speech_api.dart` | dio 기반 GET/POST/DELETE 래퍼 (~60 lines) |

### Modified files (front 워크트리)

| Path | 변경 |
|------|------|
| `app/lib/features/challenge_space/widgets/room_character.dart` | 기존 `_WaveBubble` 은 탭 반응용으로 유지. `speechText: String?`, `bubbleOpacity: double`, `bubbleScale: double` props 추가. **캐릭터 자체에는 입력 진입 핸들러를 추가하지 않는다** — 입력은 별도 위젯(`SpeechInputBar`). `_showBubble`(👋) 과 active speech 말풍선은 **동시 표시 금지** (active speech 우선). |
| `app/lib/core/widgets/challenge_room_scene.dart` | `RoomSpeechController` 생성·dispose, `VisibilityDetector` 연결, 각 `RoomCharacter` 에 active state 분배. |
| `app/lib/features/challenge_space/screens/challenge_space_screen.dart` | scene 직하부에 `SpeechInputBar` 추가. 라우트 진입 시 `ref.read(roomSpeechProvider(id).notifier).hydrate()` 호출. 키보드 inset 처리(`MediaQuery.viewInsets.bottom`). |

### Backend 워크트리 (신규 — 별도 승인)

| Path | 역할 |
|------|------|
| `server/app/models/room_speech.py` | SQLAlchemy 2.0 async 모델 |
| `server/app/routers/room_speech.py` | GET/POST/DELETE 라우터 + rate limit |
| `server/app/schemas/room_speech.py` | Pydantic v2 스키마 |
| `server/alembic/versions/xxxx_add_room_speech.py` | 테이블 + 유니크/인덱스 |

### QA 워크트리

| Path | 역할 |
|------|------|
| `app/test/features/challenge_space/widgets/speech_bubble_test.dart` | golden + interaction (말풍선 3회 반복 + round-robin 큐 전환 검증) |
| `app/test/features/challenge_space/widgets/speech_input_bar_test.dart` | 입력 바 동작 (placeholder, 카운터, 전송 버튼 활성/비활성, 키보드 send 액션, 활성 발언 hint, 지우기) |
| `app/test/features/challenge_space/providers/room_speech_provider_test.dart` | queue 알고리즘·timer·edge case 단위 테스트 |
| `server/tests/routers/test_room_speech.py` | POST/GET/DELETE + upsert + rate limit + 만료 |

## Data Flow

```
ChallengeSpaceScreen (ScrollView)
  ├─ ChallengeRoomScene (owns RoomSpeechController)
  │    ├─ roomSpeechProvider(challengeId).hydrate()
  │    │    └─ GET /challenges/{id}/room-speech → queue
  │    ├─ Timer.periodic → advance queue, emit active speaker
  │    └─ RoomCharacter(member, speechText, bubbleOpacity, bubbleScale)
  │         └─ SpeechBubble (white, tail-down)
  │
  ├─ SpeechInputBar  ← scene 직하부 한 줄
  │    ├─ MyActiveSpeechHint (내 활성 발언 있을 때만)
  │    │    └─ [지우기] → DELETE → controller.onExpired(myId)
  │    ├─ TextField
  │    └─ SendButton
  │         └─ POST /challenges/{id}/room-speech
  │              └─ controller.onNewSpeech(mine: true)
  │                   └─ 내 턴을 다음 턴으로 승격
  │
  └─ ... 기존 캘린더·멤버 리스트 ...
```

## Implementation Priority

1. **Phase 1 — front, 단독 실행 가능**
   - `SpeechBubble` 위젯 + 애니메이션.
   - `RoomSpeechController` + `Timer.periodic` 큐 로직.
   - `SpeechInputBar` 인라인 입력 바 (전송은 mock — controller 에 직접 push).
   - **Mock in-memory 데이터**로 3명이 돌아가면서 말하는 시뮬레이션 + 내 입력으로 큐에 합류.
   - UI·타이밍·레이아웃·키보드 동작을 먼저 확정.
2. **Phase 2 — backend**
   - `RoomSpeech` 모델 · 라우터 · Alembic · 테스트.
   - 이 시점에서 `api-contract.md`·`domain-model.md` 갱신 승인.
3. **Phase 3 — front 연동**
   - Mock → 실제 API 교체, 60초 polling, 오류·오프라인 처리, rate limit 인라인 hint.
4. **Phase 4 — 마무리**
   - `MyActiveSpeechHint` + 지우기 동작.
   - 접근성·다크 모드·키보드 inset 검증.

## Out of Scope

- 실시간 WebSocket / Server-Sent Events — polling 으로 충분.
- 이모지 리액션·스티커 — 후속 디자인 문서.
- 발언 아카이브·검색 — TTL 만료 시 소멸.
- 차단·신고·프로필 멘션 — 별도 스펙.
- 읽음 표시 — ambient feedback 이라 불필요.
- 음성·음향 효과 — 소셜 부담 줄이기 위해 의도적으로 무음.

## Related

- `docs/design/challenge-room-social.md` — 상위 디자인(캐릭터 배치·색상·터치 인터랙션). 본 문서는 캐릭터에 새 핸들러를 추가하지 않으므로 해당 문서의 탭/롱-프레스 인터랙션 테이블과 충돌하지 않는다.
- `docs/design/miniroom-cyworld.md` — 공유 색상/픽셀 그리드.
- `app/lib/features/challenge_space/widgets/room_character.dart` — 기존 `_WaveBubble`(👋) 선행 사례. 본 디자인의 `SpeechBubble` 은 이를 일반화·대체.
- `app/lib/core/widgets/challenge_room_scene.dart` — 컨트롤러 소유 위치.
- `app/lib/features/challenge_space/widgets/nudge_bottom_sheet.dart` — 바텀시트 패턴 참고.

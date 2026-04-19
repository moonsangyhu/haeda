---
Date: 2026-04-19
Worktree (수행): feature (worktree-feature)
Worktree (영향): feature (app/**)
Role: front
---

## Request

챌린지 방(ChallengeSpaceScreen) 상단에 싸이월드 미니룸 스타일의 공유 소셜 방을 추가한다.
멤버 캐릭터들이 한 방에 모여 있고, 인증 상태에 따라 다른 비주얼을 보이며 터치로 상호작용 가능.

## Root cause / Context

기존 challenge_space_screen에는 멤버 목록(MemberNudgeList)만 있어 소셜 감이 부족했다.
싸이월드 미니룸처럼 캐릭터들이 한 공간에 모여 있는 비주얼이 필요하며,
인증 여부에 따른 시각적 차별화(인증=활기/미인증=졸린 상태)로 동기부여를 강화.

## Actions

### 파일 생성/수정

**`app/lib/core/widgets/challenge_room_scene.dart`** (NEW, ~480줄)
- `ChallengeRoomColors` — MiniroomColors 기반 확장 팔레트 (코르크보드, 달력, 나무바닥, 파티 색상 포함)
- `ChallengeRoomScene` — ConsumerStatefulWidget, 32x24 픽셀 그리드 룸
- `_ChallengeRoomBackgroundPainter` — CustomPainter: 창문/시계/미니달력/코르크보드/나무바닥/소파
- `_CharacterSlot` — 위치 비율 데이터 클래스
- `_SummaryBadge` — 우하단 "N/M명 인증" 배지
- 캐릭터 배치: 1~8명 프리셋 (unverified→뒤, verified→앞 정렬)
- 본인 캐릭터: `myCharacterProvider` live watch, 타인: 스냅샷

**`app/lib/features/challenge_space/widgets/room_character.dart`** (NEW, ~380줄)
- `RoomCharacter` — StatefulWidget + TickerProviderStateMixin
- 인증 완료: 풀컬러 + 초록 체크뱃지 + 3초 주기 미세 바운스
- 미인증: 5도 기울기 + ColorFiltered desaturate(0.6) + Zzz 플로팅 애니메이션
- 방장: 왕관 👑 라벨
- 본인: TappableCharacter 래핑, 1.1x scale
- 타인 인증완료 탭: wiggle + 👋 말풍선 1.5초 표시
- 타인 미인증 탭: onTap 콜백 (nudge 처리)
- celebrationJump: 전원 인증 시 600ms 점프 애니메이션

**`app/lib/features/challenge_space/widgets/celebration_overlay.dart`** (NEW, ~230줄)
- `CelebrationOverlay` — StatefulWidget + TickerProviderStateMixin
- 3초 원샷 시퀀스:
  - Phase 1 (0-1s): 20개 confetti 파티클 (중력 기반)
  - Phase 2 (0.5-2.5s): 시즌 아이콘 elasticOut 스케일 팝
  - Phase 3 (0.5-3s): "오늘 전원 인증 완료!" 배너 fade-in
- false→true 전환 시 한 번만 실행

**`app/lib/features/challenge_space/screens/challenge_space_screen.dart`** (MODIFIED)
- `_ChallengeSpaceBody`를 ConsumerStatefulWidget으로 변환
- `_calendarKey` GlobalKey 추가 (캘린더 스크롤 앵커)
- Column 최상단에 `ChallengeRoomScene` 삽입 (calendarData 로드 후 표시)
- `todayEntry`, `currentUserId`, `creatorId` 한 번만 계산 후 공유
- 기존 `_TodaySection`, `_MemberSection`에 calendarData 직접 전달

## Verification

```
flutter analyze: 0 errors, 0 warnings (info만 존재 — withOpacity deprecated, 기존 코드와 동일 패턴)
flutter build ios --simulator: ✓ Built build/ios/iphonesimulator/Runner.app (13.0s)
```

새 파일에 compile-time 에러 없음 확인.
기존 테스트 파일(profile_setup_screen_test.dart)에 pre-existing 에러 1개 존재 — 이번 작업과 무관.

## Follow-ups

- ~~deployer 에이전트로 시뮬레이터 실제 실행 확인 필요~~ 완료
- `_MemberSection`, `_TodaySection`의 중복 `todayEntry` 계산 일부 잔존 — 추후 리팩터링
- 미니룸 씬에 멤버 8명 초과 시 overflow 처리 미구현 (현재 displayCount = min(len, 8))
- 다른 워크트리 세션은 재시작해야 최신 파일이 완전히 반영됩니다.

## Related

- 참조 파일: `app/lib/core/widgets/miniroom_scene.dart`, `tappable_character.dart`, `character_avatar.dart`
- 참조 파일: `app/lib/features/challenge_space/widgets/member_nudge_list.dart` (캐릭터 데이터 소스 패턴)
- 관련 provider: `myCharacterProvider`, `calendarProvider`, `nudge_provider`

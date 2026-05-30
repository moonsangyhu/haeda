# Challenge Icon Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans 으로 task 단위 실행. 체크박스 (`- [ ]`) 로 진행 추적.

**Goal:** 직전 챌린지 pill 작업의 follow-up 3건 (챌린지방 이모지 수정 / ChallengeCard 이모지 노출 / Step1 emoji preset chip) 을 마무리해 챌린지 icon 시스템을 일관성 있게 완성한다.

**Architecture:**
- 백엔드: 기존 `PATCH /challenges/{id}/settings` 를 확장 (alembic 마이그레이션 불필요 — `challenges.icon` 컬럼은 이미 존재). creator 권한 체크 로직은 이미 service 안에 있다 (`NOT_CHALLENGE_CREATOR`).
- 프론트엔드: 챌린지방 헤더 + my-page ChallengeCard + 생성 Step1 화면 세 곳에 emoji 일관 노출. 수정 UX 는 헤더 emoji 탭 → bottom sheet (creator only).

**Tech Stack:** FastAPI + SQLAlchemy 2.0 async + Pydantic v2 (백엔드), Flutter + Riverpod + GoRouter + dio (프론트엔드)

---

## 영향 파일 맵

### 백엔드
- 수정 `server/app/schemas/challenge.py` (line 93-98) — `ChallengeSettingsUpdate.icon` 추가, `ChallengeSettingsResponse.icon` 추가
- 수정 `server/app/services/challenge_service.py` (line 541-563) — `update_challenge_settings` 에 `icon` 인자 + 분기
- 수정 `server/app/routers/challenges.py` (line 168-181) — 라우터에서 `body.icon` 전달
- 수정 `docs/api-contract.md` — `PATCH /challenges/{id}/settings` request/response 에 `icon` 추가
- 신규/수정 `server/tests/test_challenges.py` — settings update icon 테스트 3개 (성공/비-creator 거부/value 그대로 보존)

### 프론트엔드
- 수정 `app/lib/features/challenge_space/screens/challenge_space_screen.dart` — 헤더에 `detail.icon` Row 추가 + creator 일 때 탭 → bottom sheet (preset chip 그리드 재사용)
- 신규 `app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart` — preset chip 그리드 + 직접 입력 + 저장. Step1 과 공유 가능한 형태로 추출
- 수정 `app/lib/features/my_page/widgets/challenge_card.dart` — title 좌측에 `challenge.icon` 노출
- 수정 `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart` — emoji TextField 를 `EmojiPicker` 위젯 (preset chip + 직접 입력 토글) 로 교체
- 신규 `app/lib/features/challenge_create/widgets/emoji_picker.dart` — preset chip 12개 + 직접 입력 토글 위젯 (위 sheet 와 공통)
- 신규/수정 `app/test/features/challenge_space/screens/challenge_space_screen_test.dart` — 헤더 emoji 노출 / creator 탭 시 sheet 노출 / 비-creator 탭 무반응
- 신규 `app/test/features/my_page/widgets/challenge_card_test.dart` — icon 노출 확인
- 수정 `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart` — preset chip 탭 / 직접 입력 토글 / forwarding 테스트

### 공통 상수
- 신규 `app/lib/core/constants/emoji_presets.dart` — `const presets = ['🎯','💪','📚','🏃','🧘','🍎','💧','😴','📝','🎨','🎵','🌱']` (12개 universal)

---

## Task 1: 백엔드 — PATCH settings 에 icon 확장

**Files:**
- Test: `server/tests/test_challenges.py` (테스트 3개 추가)
- Modify: `server/app/schemas/challenge.py:93-98`
- Modify: `server/app/services/challenge_service.py:541-562`
- Modify: `server/app/routers/challenges.py:168-181`
- Modify: `docs/api-contract.md` (PATCH /challenges/{id}/settings 섹션)

- [ ] **Step 1: RED — 3개 테스트 작성**

`server/tests/test_challenges.py` 의 기존 `TestUpdateChallengeSettings` 클래스 끝에 추가 (없으면 신규 클래스). 픽스처는 기존 테스트 패턴 답습 (`async_client`, `auth_header`, `creator_user`, `non_creator_user`, `created_challenge`).

```python
class TestUpdateChallengeIcon:
    async def test_creator_can_update_icon(
        self, async_client, creator_auth_header, created_challenge
    ):
        response = await async_client.patch(
            f"/challenges/{created_challenge.id}/settings",
            json={"icon": "🏃"},
            headers=creator_auth_header,
        )
        assert response.status_code == 200
        body = response.json()["data"]
        assert body["icon"] == "🏃"

    async def test_non_creator_cannot_update_icon(
        self, async_client, non_creator_auth_header, created_challenge
    ):
        response = await async_client.patch(
            f"/challenges/{created_challenge.id}/settings",
            json={"icon": "📚"},
            headers=non_creator_auth_header,
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "NOT_CHALLENGE_CREATOR"

    async def test_icon_persists_across_get(
        self, async_client, creator_auth_header, created_challenge
    ):
        await async_client.patch(
            f"/challenges/{created_challenge.id}/settings",
            json={"icon": "💪"},
            headers=creator_auth_header,
        )
        detail = await async_client.get(
            f"/challenges/{created_challenge.id}",
            headers=creator_auth_header,
        )
        assert detail.json()["data"]["icon"] == "💪"
```

- [ ] **Step 2: RED 확인 — pytest 실행**

```bash
cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest tests/test_challenges.py::TestUpdateChallengeIcon -v
```

Expected: 3 FAIL — `KeyError: 'icon'` 또는 `ChallengeSettingsResponse` 에 icon 필드 없음 / `body` validation reject.

- [ ] **Step 3: schema 확장**

`server/app/schemas/challenge.py:93-98` 을 아래로 교체.

```python
class ChallengeSettingsUpdate(BaseModel):
    day_cutoff_hour: int | None = None
    icon: str | None = Field(default=None, max_length=8)


class ChallengeSettingsResponse(BaseModel):
    day_cutoff_hour: int
    icon: str
```

- [ ] **Step 4: service 확장**

`server/app/services/challenge_service.py:541-562` 를 아래로 교체.

```python
async def update_challenge_settings(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    day_cutoff_hour: int | None = None,
    icon: str | None = None,
) -> ChallengeSettingsResponse:
    result = await db.execute(select(Challenge).where(Challenge.id == challenge_id))
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppException(404, "CHALLENGE_NOT_FOUND", "챌린지를 찾을 수 없습니다.")

    if challenge.creator_id != user_id:
        raise AppException(403, "NOT_CHALLENGE_CREATOR", "챌린지 생성자만 설정을 변경할 수 있습니다.")

    if day_cutoff_hour is not None:
        if day_cutoff_hour not in (0, 1, 2):
            raise AppException(422, "INVALID_DAY_CUTOFF_HOUR", "day_cutoff_hour은 0~2 사이여야 합니다.")
        challenge.day_cutoff_hour = day_cutoff_hour

    if icon is not None:
        stripped = icon.strip()
        if not stripped:
            raise AppException(422, "INVALID_ICON", "icon은 비어 있을 수 없습니다.")
        challenge.icon = stripped

    await db.commit()
    await db.refresh(challenge)
    return ChallengeSettingsResponse(
        day_cutoff_hour=challenge.day_cutoff_hour,
        icon=challenge.icon,
    )
```

- [ ] **Step 5: router 확장**

`server/app/routers/challenges.py:168-181` 의 `update_challenge_settings` 호출에 `icon=body.icon` 인자 추가.

```python
result = await challenge_service.update_challenge_settings(
    db=db,
    challenge_id=challenge_id,
    user_id=user_id,
    day_cutoff_hour=body.day_cutoff_hour,
    icon=body.icon,
)
```

- [ ] **Step 6: GREEN — pytest 통과 확인**

```bash
cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest tests/test_challenges.py::TestUpdateChallengeIcon -v
```

Expected: 3 PASS.

- [ ] **Step 7: 전체 backend 회귀 확인**

```bash
cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest 2>&1 | tail -5
```

Expected: 185 passed (직전 182 + 신규 3).

- [ ] **Step 8: api-contract.md 갱신**

`docs/api-contract.md` 의 `PATCH /challenges/{id}/settings` 섹션을 찾아 request body 와 response 에 `icon: string (optional)` 과 `icon: string` 을 각각 추가.

- [ ] **Step 9: 백엔드 rebuild + health check**

```bash
cd /Users/yumunsang/haeda/haeda && docker compose up --build -d backend
sleep 3
curl -fsS http://localhost:8000/health
```

Expected: `{"status":"ok"}`

- [ ] **Step 10: 커밋**

```bash
cd /Users/yumunsang/haeda/haeda
git add server/app/schemas/challenge.py server/app/services/challenge_service.py server/app/routers/challenges.py server/tests/test_challenges.py docs/api-contract.md
git commit -m "feat(server): PATCH /challenges/:id/settings 에 icon 필드 추가"
```

---

## Task 2: 프론트엔드 — 챌린지방 헤더 이모지 + creator 탭 수정

**Files:**
- Create: `app/lib/core/constants/emoji_presets.dart`
- Create: `app/lib/features/challenge_create/widgets/emoji_picker.dart` (공통 위젯)
- Create: `app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart`
- Modify: `app/lib/features/challenge_space/screens/challenge_space_screen.dart:81-136`
- Test: `app/test/features/challenge_space/screens/challenge_space_screen_test.dart` (신규 또는 기존 확장)

- [ ] **Step 1: 공통 상수 작성**

`app/lib/core/constants/emoji_presets.dart` 신규.

```dart
const List<String> kEmojiPresets = [
  '🎯', '💪', '📚', '🏃', '🧘', '🍎',
  '💧', '😴', '📝', '🎨', '🎵', '🌱',
];
```

- [ ] **Step 2: 공통 EmojiPicker 위젯 작성**

`app/lib/features/challenge_create/widgets/emoji_picker.dart` 신규. preset chip 그리드 + 직접 입력 토글. Step1 과 챌린지방 sheet 양쪽에서 재사용.

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/emoji_presets.dart';

class EmojiPicker extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;

  const EmojiPicker({super.key, this.initialValue, required this.onChanged});

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  late final TextEditingController _customController;
  String? _selected;
  bool _customMode = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _customController = TextEditingController(
      text: kEmojiPresets.contains(widget.initialValue)
          ? ''
          : (widget.initialValue ?? ''),
    );
    if (widget.initialValue != null &&
        !kEmojiPresets.contains(widget.initialValue)) {
      _customMode = true;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(String e) {
    setState(() {
      _selected = e;
      _customMode = false;
      _customController.clear();
    });
    widget.onChanged(e);
  }

  void _toggleCustom() {
    setState(() {
      _customMode = !_customMode;
      if (!_customMode) _customController.clear();
    });
  }

  void _onCustomChanged(String value) {
    final trimmed = value.trim();
    setState(() => _selected = trimmed.isEmpty ? null : trimmed);
    if (trimmed.isNotEmpty) widget.onChanged(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const Key('emoji_preset_wrap'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kEmojiPresets)
              ChoiceChip(
                key: Key('emoji_preset_$e'),
                label: Text(e, style: const TextStyle(fontSize: 20)),
                selected: _selected == e && !_customMode,
                onSelected: (_) => _selectPreset(e),
              ),
            ChoiceChip(
              key: const Key('emoji_custom_toggle'),
              label: const Text('직접 입력'),
              selected: _customMode,
              onSelected: (_) => _toggleCustom(),
            ),
          ],
        ),
        if (_customMode) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('emoji_custom_field'),
            controller: _customController,
            maxLength: 2,
            onChanged: _onCustomChanged,
            decoration: const InputDecoration(
              hintText: '이모지 입력',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 3: 챌린지방 헤더 RED 테스트 작성**

`app/test/features/challenge_space/screens/challenge_space_screen_test.dart` 가 없으면 신규. 기본 ProviderScope override + GoRouter wrapping pattern 은 다른 화면 테스트 답습 (`feed_screen_test.dart` 참고).

```dart
testWidgets('AppBar 에 detail.icon 이 노출된다', (tester) async {
  await tester.pumpWidget(
    _wrap(
      challengeId: 'c1',
      detail: _detail(icon: '🏃', isCreator: true),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('🏃'), findsOneWidget);
});

testWidgets('creator 가 헤더 이모지 탭 시 EmojiEditSheet 가 열린다', (tester) async {
  await tester.pumpWidget(
    _wrap(
      challengeId: 'c1',
      detail: _detail(icon: '🏃', isCreator: true),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('challenge_header_icon')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('emoji_preset_wrap')), findsOneWidget);
});

testWidgets('비-creator 가 헤더 이모지 탭 시 sheet 가 열리지 않는다', (tester) async {
  await tester.pumpWidget(
    _wrap(
      challengeId: 'c1',
      detail: _detail(icon: '🏃', isCreator: false),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('challenge_header_icon')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('emoji_preset_wrap')), findsNothing);
});
```

`_wrap`, `_detail` 헬퍼는 기존 다른 화면 테스트의 패턴을 답습한다 (Riverpod override + GoRouter root). 정확한 헬퍼 코드는 첫 RED 실행 시 컴파일 에러 메시지를 보고 채운다.

- [ ] **Step 4: RED 확인**

```bash
cd /Users/yumunsang/haeda/app && flutter test test/features/challenge_space/screens/challenge_space_screen_test.dart
```

Expected: 3 FAIL — `challenge_header_icon` key 없음 / sheet 미노출.

- [ ] **Step 5: 챌린지방 헤더 emoji 추가 + creator 탭 → sheet**

`challenge_space_screen.dart` 의 AppBar title (line 87-109) 을 Row 로 감싸 leading 으로 `detail.icon` 노출. creator 일 때만 GestureDetector + tap → bottom sheet. sheet 내부에서 `EmojiPicker` 사용 + 저장 시 `dio.patch('/challenges/:id/settings', {'icon': v})` 호출.

```dart
title: detailAsync.when(
  loading: () => const Text('챌린지'),
  error: (_, __) => const Text('챌린지'),
  data: (detail) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        key: const Key('challenge_header_icon'),
        onTap: detail.isCreator
            ? () => _showIconEditSheet(context, detail.icon)
            : null,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(detail.icon, style: const TextStyle(fontSize: 24)),
        ),
      ),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              detail.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '참여자 ${detail.memberCount}명${detail.dayCutoffHour > 0 ? ' · 새벽 ${detail.dayCutoffHour}시까지 인정' : ''}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    ],
  ),
),
```

`_showIconEditSheet` 메서드 신규 — `showModalBottomSheet` 로 `ChallengeIconEditSheet` 띄움.

`app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart` 신규.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../../challenge_create/widgets/emoji_picker.dart';
import '../providers/challenge_detail_provider.dart';

class ChallengeIconEditSheet extends ConsumerStatefulWidget {
  final String challengeId;
  final String currentIcon;

  const ChallengeIconEditSheet({
    super.key,
    required this.challengeId,
    required this.currentIcon,
  });

  @override
  ConsumerState<ChallengeIconEditSheet> createState() =>
      _ChallengeIconEditSheetState();
}

class _ChallengeIconEditSheetState
    extends ConsumerState<ChallengeIconEditSheet> {
  late String _picked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.currentIcon;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/challenges/${widget.challengeId}/settings',
        data: {'icon': _picked},
      );
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이모지 변경에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '챌린지 이모지 변경',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            EmojiPicker(
              initialValue: _picked,
              onChanged: (v) => setState(() => _picked = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('emoji_save_button'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
```

`_showIconEditSheet` in screen:

```dart
void _showIconEditSheet(BuildContext context, String currentIcon) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ChallengeIconEditSheet(
      challengeId: widget.challengeId,
      currentIcon: currentIcon,
    ),
  );
}
```

- [ ] **Step 6: GREEN 확인**

```bash
cd /Users/yumunsang/haeda/app && flutter test test/features/challenge_space/screens/challenge_space_screen_test.dart
```

Expected: 3 PASS.

- [ ] **Step 7: 회귀 확인**

```bash
cd /Users/yumunsang/haeda/app && flutter test 2>&1 | tail -3
```

Expected: 182+ passed (직전 157 + Task 1/2 신규 6). 회귀 0건.

- [ ] **Step 8: 커밋**

```bash
cd /Users/yumunsang/haeda/haeda
git add app/lib/core/constants/emoji_presets.dart \
        app/lib/features/challenge_create/widgets/emoji_picker.dart \
        app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart \
        app/lib/features/challenge_space/screens/challenge_space_screen.dart \
        app/test/features/challenge_space/
git commit -m "feat(app): 챌린지방 헤더에 이모지 + creator 수정 시트"
```

---

## Task 3: 프론트엔드 — ChallengeCard 이모지 노출

**Files:**
- Modify: `app/lib/features/my_page/widgets/challenge_card.dart`
- Test: `app/test/features/my_page/widgets/challenge_card_test.dart` (신규)

- [ ] **Step 1: RED — 위젯 테스트**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/widgets/challenge_card.dart';

void main() {
  testWidgets('ChallengeCard 는 challenge.icon 을 title 좌측에 노출한다',
      (tester) async {
    final c = ChallengeSummary(
      id: 'c1',
      title: '운동 30일',
      category: '운동',
      startDate: '2026-05-01',
      endDate: '2026-05-30',
      status: 'active',
      memberCount: 3,
      achievementRate: 50.0,
      badge: null,
      todayVerified: false,
      icon: '💪',
      lastVerifiedAt: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengeCard(challenge: c, onTap: () {}),
        ),
      ),
    );
    expect(find.text('💪'), findsOneWidget);
    expect(find.text('운동 30일'), findsOneWidget);
  });
}
```

`ChallengeSummary` constructor 의 정확한 named param 시그니처는 기존 모델 파일 (`app/lib/features/my_page/models/challenge_summary.dart`) 을 보고 맞춘다. freezed 생성 모델이라 named params 정확 매칭 필요.

- [ ] **Step 2: RED 확인**

```bash
cd /Users/yumunsang/haeda/app && flutter test test/features/my_page/widgets/challenge_card_test.dart
```

Expected: 1 FAIL — `find.text('💪')` 0 widgets.

- [ ] **Step 3: ChallengeCard 갱신**

`app/lib/features/my_page/widgets/challenge_card.dart:30-39` 의 `Expanded(child: Text(title))` 을 Row 로 감싸 emoji 추가.

```dart
Expanded(
  child: Row(
    children: [
      Text(
        challenge.icon,
        style: const TextStyle(fontSize: 20),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          isCompleted
              ? '${challenge.title} (완료)'
              : challenge.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 4: GREEN 확인 + 회귀**

```bash
cd /Users/yumunsang/haeda/app && flutter test test/features/my_page/ 2>&1 | tail -5
cd /Users/yumunsang/haeda/app && flutter test 2>&1 | tail -3
```

Expected: 신규 1 PASS, 회귀 0건.

- [ ] **Step 5: 커밋**

```bash
cd /Users/yumunsang/haeda/haeda
git add app/lib/features/my_page/widgets/challenge_card.dart \
        app/test/features/my_page/widgets/challenge_card_test.dart
git commit -m "feat(app): ChallengeCard 에 챌린지 이모지 노출"
```

---

## Task 4: 프론트엔드 — Step1 emoji preset chip

**Files:**
- Modify: `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart`
- Modify: `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart`

- [ ] **Step 1: RED — 신규 테스트 3개**

기존 `step1_screen_test.dart` 끝에 추가.

```dart
testWidgets('preset chip 탭 시 해당 이모지가 선택되어 다음 화면으로 전달된다',
    (tester) async {
  await tester.pumpWidget(_wrapStep1());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('emoji_preset_💪')));
  await tester.pump();
  // 카테고리/제목 채우고 next
  await tester.enterText(find.byKey(const Key('category_field')), '운동');
  await tester.enterText(find.byKey(const Key('title_field')), '운동 챌린지');
  await tester.tap(find.byKey(const Key('next_button')));
  await tester.pumpAndSettle();
  expect(_capturedExtra['icon'], '💪');
});

testWidgets('직접 입력 토글을 누르면 TextField 가 노출되고 입력값이 forward 된다',
    (tester) async {
  await tester.pumpWidget(_wrapStep1());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('emoji_custom_toggle')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('emoji_custom_field')), findsOneWidget);
  await tester.enterText(find.byKey(const Key('emoji_custom_field')), '🦄');
  await tester.enterText(find.byKey(const Key('category_field')), '습관');
  await tester.enterText(find.byKey(const Key('title_field')), '유니콘');
  await tester.tap(find.byKey(const Key('next_button')));
  await tester.pumpAndSettle();
  expect(_capturedExtra['icon'], '🦄');
});

testWidgets('아무것도 선택하지 않으면 default 🎯 가 forward 된다',
    (tester) async {
  await tester.pumpWidget(_wrapStep1());
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('category_field')), '독서');
  await tester.enterText(find.byKey(const Key('title_field')), '독서');
  await tester.tap(find.byKey(const Key('next_button')));
  await tester.pumpAndSettle();
  expect(_capturedExtra['icon'], '🎯');
});
```

기존 테스트의 `_wrapStep1`/`_capturedExtra` 헬퍼를 그대로 사용한다. 정확한 헬퍼 구현은 기존 파일 답습.

- [ ] **Step 2: RED 확인**

```bash
cd /Users/yumunsang/haeda/app && flutter test test/features/challenge_create/screens/challenge_create_step1_screen_test.dart
```

Expected: 신규 3 FAIL (`emoji_preset_💪` key 없음 등).

- [ ] **Step 3: Step1 화면 — TextField → EmojiPicker**

`challenge_create_step1_screen.dart:65-77` (이모지 label + TextField) 를 아래로 교체. `_iconController` 제거하고 `_pickedIcon: String?` state 도입.

```dart
String? _pickedIcon;

void _onNext() {
  if (_formKey.currentState!.validate()) {
    context.go(
      '/create/step2',
      extra: {
        'category': _categoryController.text.trim(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icon': (_pickedIcon == null || _pickedIcon!.isEmpty)
            ? '🎯'
            : _pickedIcon!,
      },
    );
  }
}
```

```dart
_FieldLabel('이모지'),
const SizedBox(height: 8),
EmojiPicker(
  initialValue: _pickedIcon,
  onChanged: (v) => setState(() => _pickedIcon = v),
),
```

import 추가:
```dart
import '../widgets/emoji_picker.dart';
```

- [ ] **Step 4: GREEN 확인 + 회귀**

```bash
cd /Users/yumunsang/haeda/app && flutter test test/features/challenge_create/ 2>&1 | tail -5
cd /Users/yumunsang/haeda/app && flutter test 2>&1 | tail -3
```

Expected: step1 신규 3 PASS + 기존 9 유지 = 12. 회귀 0건.

- [ ] **Step 5: 커밋**

```bash
cd /Users/yumunsang/haeda/haeda
git add app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart \
        app/test/features/challenge_create/
git commit -m "feat(app): Step1 emoji 입력을 preset chip + 직접 입력으로 교체"
```

---

## Task 5: 통합 검증 + 보고서

**Files:**
- Create: `docs/reports/2026-05-30-feature-challenge-icon-followups.md`
- Read: 전체 backend pytest + flutter test + iOS simulator

- [ ] **Step 1: 전체 회귀 — backend + frontend**

```bash
cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest 2>&1 | tail -3
cd /Users/yumunsang/haeda/app && flutter test 2>&1 | tail -3
```

Expected: backend 185 passed (직전 182 + 신규 3), frontend 164 passed (직전 157 + Task 1/3/4 신규 7).

- [ ] **Step 2: iOS simulator clean install**

`.claude/rules/ios-simulator.md` 절차 그대로.

```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
cd app && flutter clean && flutter pub get && flutter build ios --simulator && cd ..
xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```

- [ ] **Step 3: 4단계 스크린샷 캡처 (idb)**

| # | 시나리오 | 파일명 |
|---|---------|--------|
| 1 | my-page 진입 → ChallengeCard 의 이모지 노출 | `2026-05-30-feature-challenge-icon-followups-01-card.png` |
| 2 | 챌린지방 진입 → 헤더 이모지 노출 | `02-space-header.png` |
| 3 | creator 가 헤더 이모지 탭 → bottom sheet 의 preset chip + 직접 입력 토글 | `03-edit-sheet.png` |
| 4 | preset chip 선택 후 저장 → 헤더 이모지 갱신 | `04-after-save.png` |

idb 또는 `xcrun simctl io ... screenshot` 사용.

- [ ] **Step 4: 보고서 작성**

`docs/reports/2026-05-30-feature-challenge-icon-followups.md` 작성. 표준 섹션 (Date / Worktree / Role / Request / Root cause / Referenced Reports / Actions / Verification / Follow-ups / Related).

- [ ] **Step 5: 보고서 + 스크린샷 커밋**

```bash
cd /Users/yumunsang/haeda/haeda
git add docs/reports/2026-05-30-feature-challenge-icon-followups.md \
        docs/reports/screenshots/2026-05-30-feature-challenge-icon-followups-*.png
git commit -m "docs(report): challenge icon follow-ups 3건 완료 보고서"
```

- [ ] **Step 6: main push**

```bash
cd /Users/yumunsang/haeda/haeda
git push origin main
```

(직전 세션에서 deny 제거 + 솔로 프로젝트 main 직접 push 방침 확정.)

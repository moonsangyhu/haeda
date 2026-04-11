# feat(app): redesign center challenge button with fiery pulse

- **Date**: 2026-04-11
- **Commit**: 628d1f4
- **Area**: frontend

## What Changed

하단 네비게이션 가운데 "챌린지" 버튼을 보라/핑크 정적 버튼에서 빨강·주황·금색 그라디언트와 fire 아이콘을 가진 맥동(pulse) 버튼으로 재설계. 사용자가 "가슴 뜨거워지는, 경쟁심이 불타오르는" 디자인을 요청했고, 챌린지 앱의 핵심 CTA가 감정적으로 촉발되도록 시각적 존재감을 강화하는 것이 목적.

## Changed Files

| File | Change |
|------|--------|
| `app/lib/core/widgets/main_shell.dart` | `_CenterTabItem`을 StatelessWidget → StatefulWidget(+ SingleTickerProviderStateMixin)으로 전환. 1400ms 맥동 애니메이션, 이중 glow shadow, fire 아이콘, hot 그라디언트 적용. Semantics 래핑 추가. |

## Implementation Details

- **애니메이션**: `AnimationController(duration: 1400ms)` + `Curves.easeInOut` + `repeat(reverse: true)`. `AnimatedBuilder`로 매 프레임 scale(1.0↔1.06), glowMul(0.7↔1.0), innerBlur(14↔20) 갱신.
- **그라디언트**: 미선택 `[#FF6B6B, #FF8A3D, #FFC837]`, 선택 `[#FF1744, #FF6D00, #FFD600]`. topLeft→bottomRight.
- **이중 glow shadow**:
  - 내측: `#FF3D00`, opacity 0.55(선택)/0.35(미선택) × glowMul, animated blur 14~20, offset (0,0)
  - 외측: `#FFC837`, opacity 0.35/0.20 × glowMul, blur 24, spread 2, offset (0,4)
- **아이콘**: `CuteIcon('home', 28)` → `CuteIcon('fire', 30)`. 기존 `app/assets/icons/fire.svg` 재사용(새 에셋 추가 없음). `ColorFiltered(BlendMode.srcIn, Colors.white)` 패턴 유지.
- **지오메트리**: 원 56→60px, Transform offset -14→-18 (더 튀어나옴). 테두리 흰색 2.5(미선택)/3.0(선택)px.
- **라벨 색**: 선택 `#FF1744`, 미선택 `#FF6B6B` — 버튼 컬러 일관성.
- **접근성**: 최상위에 `Semantics(button: true, label: '챌린지')` 래핑.
- **스코프**: `_CenterTabItem` 1 위젯만 수정. 라우팅/탭 인덱스/다른 탭/테마/에셋 건드리지 않음.
- 호출부(`main_shell.dart:112-116`)의 prop 시그니처(`isSelected`, `onTap`, `theme`) 불변.
- 비폐기 API 사용: `.withValues(alpha: ...)` (not `.withOpacity()`).

## Tests & Build

- Analyze: 0 errors in modified code
- Tests: N/A (widget test 범위 아님, 기존 테스트 영향 없음)
- iOS simulator build: PASS (`Xcode build done. 15.7s`)
- iOS simulator 실행 확인: PASS — iPhone 17 Pro에서 `flutter run`으로 앱 실행, Dart VM Service 기동(`http://127.0.0.1:50926`), 사용자 육안 확인 "GOOD"

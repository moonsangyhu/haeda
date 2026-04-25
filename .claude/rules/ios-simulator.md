# iOS Simulator Verification

`app/**` Flutter 코드를 변경한 모든 작업은 **iOS simulator 에서 clean install 로 실행 확인** 으로 마무리한다. `flutter build ios --simulator` 단독 (빌드만) 또는 `flutter build web` 은 검증으로 인정하지 않는다.

## 의무 시점

- `app/lib/**`, `app/pubspec.yaml`, `app/ios/**` 변경 직후
- frontend 관련 변경을 포함한 PR 생성 전

## 절차 — Clean Install (캐시 구버전 방지)

```bash
# 1. simulator 부팅 확인 + 디바이스 ID
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

# 2. bundle id
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')

# 3. 종료 + 제거
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

# 4. clean 빌드
cd app && flutter clean && flutter pub get && flutter build ios --simulator && cd ..

# 5. install + launch
xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```

빌드 실패 시 STOP, 마지막 200 줄 로그 캡처. simulator 부팅이 안 되어 있으면 사용자에게 안내 후 STOP (자동 부팅 시도 금지).

## 면제

- 변경 범위가 `.env.example`, `docs/`, `.claude/` 만인 경우
- 컴파일 영향 없는 한 줄 주석 / 포맷 변경

## 자동 발동

`.claude/skills/haeda-ios-deploy/SKILL.md` 가 description 트리거로 자동 실행한다.

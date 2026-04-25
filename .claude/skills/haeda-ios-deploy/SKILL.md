---
name: haeda-ios-deploy
description: app/** Flutter 변경 후 iOS simulator 에 clean install 자동 실행. terminate→uninstall→clean→pub get→build→install→launch 시퀀스. Flutter 코드 / pubspec / iOS 설정 변경 직후, 사용자 시각 검증 전 반드시 호출.
allowed-tools: "Bash Read"
---

# Haeda iOS Deploy

`app/**` Flutter 변경을 iOS simulator 에서 clean install 로 실행. 캐시 구버전 방지가 목적이므로 `flutter run` 핫리로드만으로는 인정하지 않는다.

## 발동 조건

- `app/lib/**`, `app/pubspec.yaml`, `app/ios/**` 변경 직후
- frontend 변경을 포함한 PR 생성 전

## 발동하지 않을 조건

- 변경이 `docs/` / `.claude/` / `.env.example` 에만 있음
- 한 줄 주석 / 포맷 변경

## 절차

### 1. simulator 디바이스 ID 감지

```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
echo "device: $DEVICE_ID"
```

비어 있으면 시뮬레이터 부팅 안내 후 STOP.

### 2. bundle id 확인

```bash
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')
echo "bundle: $BUNDLE_ID"
```

### 3. 종료 + 제거

```bash
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
```

### 4. clean 빌드

```bash
cd app
flutter clean
flutter pub get
flutter build ios --simulator
cd ..
```

빌드 실패 시 마지막 200 줄 캡처 후 STOP.

### 5. install + launch

```bash
xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```

### 6. 첫 화면 캡처

```bash
sleep 2
mkdir -p docs/reports/screenshots
DATE=$(date +%Y-%m-%d)
xcrun simctl io "$DEVICE_ID" screenshot "docs/reports/screenshots/${DATE}-claude-ios-deploy-01.png"
```

### 7. 보고

성공: 캡처 경로 + 첫 화면 요약 인용.
실패: 실패 단계 + 출력 발췌.

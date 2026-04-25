---
name: haeda-ios-tap
description: iOS simulator 자동 인터랙션 도구 (idb 기반). UI 트리 조회 + 좌표 tap + swipe + 텍스트 입력 + 스크린샷. 시뮬레이터 깊은 화면 자동 검증이 필요할 때 발동. flutter run / launch 후 첫 화면을 넘어 특정 기능 화면을 캡처/검증해야 하는 경우.
---

# Haeda iOS Tap

`idb` (Facebook iOS Development Bridge) 로 iOS simulator 를 자동 조작. 깊은 화면 캡처가 필요한 검증·QA 시 발동.

## 발동 조건

- 첫 launch 화면 이상의 깊은 화면을 자동 캡처/검증해야 할 때
- 특정 화면에 진입해 UI 트리를 검사해 요소 부재 / 존재를 자동 검증해야 할 때
- `haeda-ios-deploy` 다음 단계로 깊은 검증을 이어가야 할 때

## 발동하지 않을 조건

- 시뮬레이터 자체가 부팅 안 된 상태 (먼저 `haeda-ios-deploy` 또는 사용자에게 부팅 요청)
- 단순 첫 화면 캡처면 충분 → `haeda-ios-deploy` 로 끝

## 도구 환경

| 컴포넌트 | 경로 | 비고 |
|---------|------|------|
| `idb_companion` | `/opt/homebrew/bin/idb_companion` | brew 로 설치, gRPC 서버 |
| `idb` (Python client) | `/Users/yumunsang/.local/idb-venv/bin/idb` | 시스템 python3 venv 에 fb-idb 1.1.7 |

PATH 에 venv bin 을 추가하거나 절대 경로 사용:
```bash
export PATH="/Users/yumunsang/.local/idb-venv/bin:$PATH"
```

## 절차

### 1. companion 부팅 (세션당 1회)

```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
[ -z "$DEVICE_ID" ] && { echo "no booted simulator — STOP"; exit 1; }

# 이미 떠 있으면 건너뜀
if ! lsof -iTCP:10882 -sTCP:LISTEN >/dev/null 2>&1; then
  idb_companion --udid "$DEVICE_ID" --grpc-port 10882 > /tmp/idb_companion.log 2>&1 &
  echo $! > /tmp/idb_companion.pid
  sleep 2
fi

export PATH="/Users/yumunsang/.local/idb-venv/bin:$PATH"
idb connect localhost 10882 2>&1 | tail -1
```

### 2. UI 트리 조회 (요소 좌표 찾기)

```bash
idb ui describe-all --udid "$DEVICE_ID" > /tmp/ui-tree.json
```

응답은 JSON 배열. 각 요소의 `frame.x/y/width/height` 와 `AXLabel`, `type`, `role`. 특정 라벨 검색 예:

```bash
python3 - <<'PY'
import json
data = json.load(open('/tmp/ui-tree.json'))
target = '인증하기'
for item in data:
    if item.get('AXLabel') == target:
        f = item['frame']
        print(f"{target}: center ({f['x']+f['width']/2:.0f}, {f['y']+f['height']/2:.0f})")
PY
```

### 3. 인터랙션

```bash
# tap (좌표는 describe-all 의 logical points, simctl screenshot pixel 과 다름)
idb ui tap --udid "$DEVICE_ID" <X> <Y>

# swipe (예: 위로 스크롤)
idb ui swipe --udid "$DEVICE_ID" 200 700 200 200

# 텍스트 입력 (포커스 된 입력창에)
idb ui text --udid "$DEVICE_ID" "안녕하세요"

# 키 (예: home)
idb ui button HOME --udid "$DEVICE_ID"
```

### 4. 캡처

```bash
xcrun simctl io "$DEVICE_ID" screenshot /tmp/after-tap.png
# 또는
idb screenshot --udid "$DEVICE_ID" /tmp/after-tap.png
```

### 5. 자동 어설션 (선택)

UI 트리에서 특정 요소의 부재/존재를 검증:
```bash
idb ui describe-all --udid "$DEVICE_ID" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
hits = [i for i in data if i.get('AXLabel') == '챌린지원']
assert len(hits) == 0, f'unexpected hits: {hits}'
print('OK — 챌린지원 헤더 부재 확인')
"
```

### 6. 정리 (세션 종료 시 또는 idb 가 재시작 필요할 때만)

```bash
[ -f /tmp/idb_companion.pid ] && kill "$(cat /tmp/idb_companion.pid)" 2>/dev/null && rm -f /tmp/idb_companion.pid
```

기본은 켜둔 채 다음 호출에서 재사용. 하루 이상 유휴거나 simulator 를 새로 boot 했으면 재시작.

## 주의

- **좌표는 logical points** (예: iPhone 17 Pro 는 402×874). screenshot pixel 좌표 (예: 1206×2622) 가 아니다. UI tree 의 `frame` 값 그대로 사용.
- 첫 호출이 느리면 (1–3 초) companion bootstrapping 중. 이후는 빠름.
- `idb_companion` 시작 시 objc duplicate symbol 경고는 무해 (Apple private framework 와 idb 의 FBControlCore 충돌 — 기능 영향 없음).
- fb-idb 1.1.7 + iOS 26.4 (Xcode 26) 조합에서 정상 작동 확인 (2026-04-25).

## 보고

성공: 캡처 경로 + UI 트리 어설션 결과 인용.
실패: companion 로그 (`/tmp/idb_companion.log`) 확인 후 재시작 필요할 수 있음.

---
date: 2026-04-25
worktree: feature
role: feature
slug: install-idb-auto-tap
---

# iOS 시뮬레이터 자동 탭 도구 (idb) 설치

## Request

> 자동 탭 도구를 설치해서 화면 캡처 테스트도 가능하게 해 줘

## Root cause / Context

직전 작업 (`2026-04-25-feature-remove-challenge-member-list.md`) 에서 챌린지 방 깊은 화면 캡처가 자동 탭 도구 부재로 사용자 수동 개입에 의존했다. 메모리 `feedback_ios_auto_tap_tooling.md` 에도 동일 문제가 누적 기록되어 있었음. 이를 해소해 launch 화면 너머의 자동 시각/UI 검증을 가능하게 한다.

도구 후보 비교:
- **idb** (Facebook iOS Bridge) — 채택. tap by coordinate / accessibility tree / screenshot 한 도구. 단점: 2024년 GitHub 아카이브, 다만 시뮬레이터 + Xcode 26 호환 동작 확인.
- **maestro** — 활발히 유지되지만 YAML flow 중심이라 ad-hoc 단일 tap 엔 무거움. 추후 E2E 시 재검토.
- AppleScript / cliclick — 시뮬레이터 창 위치 의존, 깨지기 쉬워 제외.

## Actions

### 1. idb_companion 설치 (gRPC server)

```bash
brew tap facebook/fb
brew install idb-companion   # 1.1.8
# → /opt/homebrew/bin/idb_companion
```

### 2. fb-idb (Python client) 설치 — 우회 경로

`brew python@3.12` 의 pyexpat 모듈이 `_XML_SetAllocTrackerActivationThreshold` symbol not found 로 ensurepip 가 실패 (system libexpat vs brew expat dylib mismatch). pipx / brew python venv 모두 같은 이유로 실패. **시스템 python 3.9.6 (`/usr/bin/python3`) 으로 venv 생성 후 설치 성공**:

```bash
/usr/bin/python3 -m venv /Users/yumunsang/.local/idb-venv
/Users/yumunsang/.local/idb-venv/bin/pip install --upgrade pip   # 21 → 26
/Users/yumunsang/.local/idb-venv/bin/pip install fb-idb          # 1.1.7
# → /Users/yumunsang/.local/idb-venv/bin/idb
```

### 3. 동작 검증 (현재 시뮬레이터: iPhone 17 Pro, iOS 26.4)

```
$ idb_companion --udid 463EC4CF-... --grpc-port 10882 &
{"grpc_port":10882,"grpc_swift_port":10882}

$ idb connect localhost 10882
udid: 463EC4CF-... is_local: True

$ idb list-targets | grep Booted
iPhone 17 Pro | 463EC4CF-... | Booted | simulator | iOS 26.4 | x86_64 | localhost:10882
```

UI tree 조회 → tap → 결과 확인 사이클을 직전 작업 검증 케이스 (챌린지 방 멤버 리스트 제거) 에 적용:

```
$ idb ui describe-all → 챌린지 방 화면. "오늘 (4월 25일) / 인증하기" 다음 요소 없음
$ idb ui tap 135 438                 # 이전 달 버튼 (logical points)
$ idb ui describe-all | grep month   → "2026년 3월" (변경 확인)
$ idb ui tap 267 438                 # 다음 달 복귀
$ idb ui swipe 200 700 200 200       # 스크롤 down
$ python ... 'AXLabel == "챌린지원"' → hits: 0  ✓
```

세 단계의 캡처를 보존:
- `docs/reports/screenshots/2026-04-25-feature-idb-install-01-room-no-member-list.png` — 챌린지 방 (멤버 리스트 부재 자동 검증 증거)
- `2026-04-25-feature-idb-install-02-tap-prev-month.png` — tap 후 3월 화면
- `2026-04-25-feature-idb-install-03-scrolled-bottom.png` — 스크롤 하단

### 4. 스킬 + 메모리 등록

- `.claude/skills/haeda-ios-tap/SKILL.md` — companion 부팅 / UI tree 조회 / tap·swipe·text·screenshot / 정리 절차 + 좌표계 주의 (logical points vs screenshot pixel) 명시
- `~/.claude/.../memory/feedback_ios_auto_tap_tooling.md` — "미설치, 사용자 수동 개입" → "설치 완료, 호출 패턴 + 함정 기록" 으로 갱신
- `MEMORY.md` 인덱스 한 줄 갱신

## Verification

```
$ which idb_companion
/opt/homebrew/bin/idb_companion

$ /Users/yumunsang/.local/idb-venv/bin/idb --version 2>&1 | head -1
(version output OK)

$ idb ui tap 135 438 + 월 라벨 확인
month label: 2026년 3월 (4월에서 변경됨, tap 동작 검증)

$ idb ui describe-all → "챌린지원" 검색
챌린지원 헤더 hits: 0  ← 이전 작업의 멤버 리스트 제거가 자동 검증됨
```

세 캡처 파일 size 확인 (208KB / 218KB / 200KB) — 모두 정상 PNG.

## Follow-ups

- `haeda-ios-deploy` 스킬 마지막 단계에서 옵션으로 `haeda-ios-tap` 호출하도록 확장 가능 (e.g. "deploy 후 챌린지 진입까지 자동화"). 다음 시나리오에서 실제 필요해질 때 추가.
- companion 프로세스 관리: 현재 세션엔 백그라운드로 살아있음 (`/tmp/idb_companion.pid`). 시뮬레이터 재부팅 시 재시작 필요. 스킬에 명시됨.
- pipx 기반 설치는 brew python expat 문제로 실패 → 추후 brew python 이 fix 되면 pipx 로 마이그레이션 가능.

## Related

- 직전 작업 `2026-04-25-feature-remove-challenge-member-list.md` — 본 도구로 자동 검증 가능했어야 했던 케이스
- 신설 스킬 `.claude/skills/haeda-ios-tap/SKILL.md`
- 메모리 `feedback_ios_auto_tap_tooling.md` (갱신)
- 기존 스킬 `.claude/skills/haeda-ios-deploy/SKILL.md` (변경 없음, 다음 작업에서 통합 검토)

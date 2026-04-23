# Haeda Flutter iOS Simulator Extension (ALWAYS-ENFORCED)

## Overview

Every AIDLC-driven code change that touches `app/**` MUST be verified on an iOS simulator with a real build + install + launch cycle. `flutter build ios --simulator` alone is NOT sufficient — the app MUST actually boot to a visible screen.

**Enforcement**: Applies at AIDLC's **Construction → Build and Test** stage. Non-compliance is a **blocking finding**.

## Scope

Triggered when the current AIDLC unit touches any of:
- `app/lib/**`
- `app/ios/**`, `app/pubspec.yaml`, `app/pubspec.lock`
- `app/assets/**`
- `app/test/**` (still requires simulator run to confirm widget tests don't imply runtime regression)

N/A when the unit is server/ only or docs-only.

## Rule FLUT-01: Simulator build

**Rule**: Before install/launch, produce a fresh simulator build.

**Required command** (from repo root):
```bash
cd app && flutter build ios --simulator
```

**Verification**:
- Exit code 0
- Output excerpt showing `Built build/ios/iphonesimulator/Runner.app (...)`
- No `Error:` lines

Web builds (`flutter build web`) and physical-device builds are NOT substitutes.

## Rule FLUT-02: Clean install cycle (prevents cached stale UI)

**Rule**: To guarantee users see the freshly-built binary, perform a terminate → uninstall → install → launch cycle. The simulator aggressively caches earlier builds; skipping this step has historically led to "it looks broken" reports that were actually old bytes running.

**Required sequence** (device `booted` selector works for the active simulator):
```bash
xcrun simctl terminate booted com.haeda.app 2>/dev/null || true
xcrun simctl uninstall booted com.haeda.app 2>/dev/null || true
xcrun simctl install booted app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.haeda.app
```

Replace `com.haeda.app` with the actual bundle id if it differs (check `app/ios/Runner/Info.plist` — `CFBundleIdentifier`).

**Verification**:
- Each of the 4 commands executed
- `install` and `launch` exited 0
- `launch` output shows the PID of the launched process

## Rule FLUT-03: Visual confirmation

**Rule**: After launch, confirm the UI actually rendered by capturing and inspecting a simulator screenshot or by citing a specific widget tree probe.

**Acceptable evidence (any one)**:
- Screenshot saved under `docs/reports/screenshots/YYYY-MM-DD-<slug>-NN.png` and referenced in the stage summary. Command pattern:
  ```bash
  xcrun simctl io booted screenshot docs/reports/screenshots/2026-04-23-aidlc-smoke-01.png
  ```
- `xcrun simctl listapps booted | grep -i haeda` output showing the app appears as installed and running
- Flutter integration test (`flutter test integration_test/`) executing against the simulator with the affected screen

Simply citing the launch PID without a visual or integration check is **not** acceptable for screens changed in this unit.

## Rule FLUT-04: Evidence in Build and Test stage

The stage completion message MUST include a `### iOS Simulator Verification` block with all four rules' outputs:

```markdown
### iOS Simulator Verification — haeda-flutter-ios-sim

- **Build**:
  - Command: `cd app && flutter build ios --simulator`
  - Output (excerpt): `Built build/ios/iphonesimulator/Runner.app (38.2MB)`
- **Install cycle**:
  - terminate / uninstall / install / launch — all exit 0
  - Launch PID: `75432`
- **Visual confirmation**:
  - Screenshot: `docs/reports/screenshots/2026-04-23-<slug>-01.png`
  - Observed: calendar renders April 2026 with season icon "봄"
```

## Rule FLUT-05: Flutter test suite

**Rule**: For any change under `app/lib/**`, the relevant test suite MUST pass.

**Required command**:
```bash
cd app && flutter test
```

**Verification**:
- Cite pass count (e.g., `All tests passed! (37)`)
- Any skipped tests must be explained in the stage summary

## Failure handling

If any of FLUT-01..05 fails, the stage is blocked. Return to Code Generation to fix. Do NOT paper over failures with mocks.

## N/A Cases

- Server-only or docs-only units: record `FLUT-01..05 — N/A (no app/ changes in this unit)`.
- Unit-test-only change (e.g., adding a missing test with no production code): FLUT-01..04 may be N/A, but FLUT-05 still applies.

## Compliance Summary Format

```
## Extension Compliance — haeda-flutter-ios-sim
- FLUT-01 Simulator build: compliant — Built Runner.app
- FLUT-02 Clean install cycle: compliant — 4 xcrun simctl commands exit 0
- FLUT-03 Visual confirmation: compliant — screenshot 2026-04-23-<slug>-01.png
- FLUT-04 Evidence format: compliant
- FLUT-05 Flutter test suite: compliant — 37 tests passed
```

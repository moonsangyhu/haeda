# chore: fix browser cache for main.dart.js and add local dev mode

- **Date**: 2026-04-10
- **PR**: #4 — https://github.com/moonsangyhu/haeda/pull/4
- **Branch**: chore/fix-cache-and-local-dev
- **Area**: config

## What Changed

Flutter 웹앱을 Docker로 리빌드해도 브라우저 캐시 때문에 변경사항이 반영되지 않는 문제를 해결. 근본 원인은 nginx.conf에서 `main.dart.js`(파일명 고정, 해시 없음)에 1년 immutable 캐시가 적용되던 것. 추가로 `/local dev` 서브커맨드를 추가하여 Flutter를 로컬에서 hot reload로 실행할 수 있도록 함.

## Changed Files

| File | Change |
|------|--------|
| `app/nginx.conf` | `main.dart.js`, `flutter.js`를 no-cache 그룹에 추가 |
| `.claude/skills/local/SKILL.md` | `dev`/`dev stop` 서브커맨드 추가, 하드코딩 경로 수정 |

## Implementation Details

**nginx.conf 캐시 수정**: `location ~ ^/(index\.html|flutter_bootstrap\.js)$` 패턴에 `main\.dart\.js|flutter\.js`를 추가. 이 파일들은 Flutter 빌드 시 파일명이 변하지 않아 fingerprinted asset이 아님에도 1년 캐시가 적용되고 있었음.

**`/local dev` 모드**: DB + Backend만 Docker로 띄우고 Flutter는 호스트에서 `flutter run -d chrome --web-port=3000`으로 실행. Hot reload 지원, 캐시 문제 없음, 빠른 개발 사이클.

**경로 수정**: SKILL.md 내 `/Users/moonsang.yhu/Documents/haeda` → `/Users/yumunsang/haeda`로 일괄 수정.

## Tests & Build

- Analyze: skip (config only)
- Tests: skip (config only)
- Build: skip (config only)

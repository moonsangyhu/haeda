#!/usr/bin/env bash
# 부팅된 iOS 시뮬레이터의 사진 라이브러리에 app/assets/sample-photos/*.jpg 시드.
# 챌린지 인증 화면에서 갤러리 선택 흐름을 테스트할 수 있도록 한다.
set -euo pipefail

DEVICE_ID="$(xcrun simctl list devices booted | grep -E 'Booted' | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')"
if [ -z "$DEVICE_ID" ]; then
  echo "부팅된 iOS 시뮬레이터가 없습니다. /sim 으로 먼저 부팅하세요." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE_DIR="$REPO_ROOT/app/assets/sample-photos"
shopt -s nullglob
PHOTOS=("$SAMPLE_DIR"/*.jpg "$SAMPLE_DIR"/*.jpeg "$SAMPLE_DIR"/*.png)
if [ ${#PHOTOS[@]} -eq 0 ]; then
  echo "$SAMPLE_DIR 에 샘플 사진이 없습니다." >&2
  exit 1
fi

xcrun simctl addmedia "$DEVICE_ID" "${PHOTOS[@]}"
echo "${#PHOTOS[@]}장 시드 완료 → device $DEVICE_ID"

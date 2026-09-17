#!/usr/bin/env bash
# CI entrypoint for reactivecircus/android-emulator-runner.
# That action runs each line of `script:` as a separate `sh -c`, so control
# flow must live in a single command (this file), not inline YAML.
set -eu

serial="${1:-emulator-5554}"

i=0
while [ "$i" -lt 90 ]; do
  if adb -s "$serial" shell 'pm path android' >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 2
done
adb -s "$serial" shell 'pm path android' >/dev/null

attempt=0
while [ "$attempt" -lt 8 ]; do
  if adb -s "$serial" shell settings put global window_animation_scale 0.0 \
    && adb -s "$serial" shell settings put global transition_animation_scale 0.0 \
    && adb -s "$serial" shell settings put global animator_duration_scale 0.0; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 3
done
if [ "$attempt" -ge 8 ]; then
  echo "adb settings still unavailable after retries" >&2
  exit 1
fi

go run ./tool/bootstrap.go android-smoke -d "$serial"

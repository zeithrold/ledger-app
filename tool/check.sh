#!/usr/bin/env bash
set -euo pipefail

check_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$check_root"

python3 tool/check_currencies.py

if [[ ! -f .env.local ]]; then
  cp .env.example .env.local
fi

flutter pub get --enforce-lockfile
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
dart analyze --fatal-infos
flutter test --no-pub --coverage

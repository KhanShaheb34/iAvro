#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build/tests

xcrun clang \
  -fmodules \
  -fblocks \
  -fno-objc-arc \
  -framework Foundation \
  -I. \
  tests/regression_runner.m \
  Suggestion.m \
  AvroParser.m \
  AutoCorrect.m \
  Database.m \
  RegexParser.m \
  CacheManager.m \
  NSString+Levenshtein.m \
  -lsqlite3 \
  -o build/tests/regression_runner

build/tests/regression_runner tests/fixtures/regression_cases.json "$ROOT_DIR"
